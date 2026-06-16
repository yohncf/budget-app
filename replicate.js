const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// 1. Load configuration
function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    const content = fs.readFileSync(envPath, 'utf8');
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#')) {
        const match = trimmed.match(/^\s*([\w.-]+)\s*=\s*(.*)?\s*$/);
        if (match) {
          const key = match[1];
          let val = match[2] ? match[2].trim() : '';
          if (val.startsWith('"') && val.endsWith('"')) {
            val = val.substring(1, val.length - 1).replace(/\\n/g, '\n');
          } else if (val.startsWith("'") && val.endsWith("'")) {
            val = val.substring(1, val.length - 1);
          } else {
            const commentIndex = val.indexOf('#');
            if (commentIndex !== -1) {
              val = val.substring(0, commentIndex).trim();
            }
          }
          process.env[key] = val;
        }
      }
    }
  }
}

loadEnv();

const firebaseCredsPath = path.join(__dirname, 'firebase-credentials.json');
const SUPABASE_PROJECT_REF = process.env.SUPABASE_PROJECT_REF || 'ubjvlwnzcyogxcwzdypd';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!fs.existsSync(firebaseCredsPath)) {
  console.error('\x1b[31mError: firebase-credentials.json not found in the root directory.\x1b[0m');
  console.log('Please make sure you have the file in place.');
  process.exit(1);
}

if (!SUPABASE_SERVICE_ROLE_KEY || SUPABASE_SERVICE_ROLE_KEY.startsWith('YOUR_')) {
  console.error('\x1b[31mError: SUPABASE_SERVICE_ROLE_KEY is not configured or is using placeholder.\x1b[0m');
  console.log('Please copy .env.example to .env and configure your secret service_role key.');
  process.exit(1);
}

const firebaseCreds = JSON.parse(fs.readFileSync(firebaseCredsPath, 'utf8'));
const FIREBASE_PROJECT_ID = firebaseCreds.project_id;

// 2. Google OAuth helper for Firestore authentication
async function getFirestoreAccessToken(creds) {
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const nowSecs = Math.floor(Date.now() / 1000);
  const claim = Buffer.from(JSON.stringify({
    iss: creds.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: creds.token_uri || 'https://oauth2.googleapis.com/token',
    exp: nowSecs + 3600,
    iat: nowSecs
  })).toString('base64url');

  const signatureInput = `${header}.${claim}`;
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(signatureInput);
  const signature = sign.sign(creds.private_key, 'base64url');
  const jwt = `${signatureInput}.${signature}`;

  const response = await fetch(creds.token_uri || 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Google OAuth failed: ${response.status} - ${errText}`);
  }

  const data = await response.json();
  return data.access_token;
}

// 3. Supabase pagination fetcher
async function fetchAllFromSupabase(table, projectRef, serviceRoleKey) {
  let allRecords = [];
  let offset = 0;
  const limit = 1000;

  while (true) {
    const url = `https://${projectRef}.supabase.co/rest/v1/${table}?select=*`;
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Range': `${offset}-${offset + limit - 1}`
      }
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Failed to fetch ${table} from Supabase: ${response.status} - ${errText}`);
    }

    const data = await response.json();
    if (!Array.isArray(data) || data.length === 0) {
      break;
    }

    allRecords = allRecords.concat(data);
    if (data.length < limit) {
      break;
    }
    offset += limit;
  }
  return allRecords;
}

// 4. DataType conversion for Firestore
function toFirestoreValue(val, key) {
  const dateFields = [
    'created_at',
    'updated_at',
    'snapshot_date',
    'date',
    'executed_at',
    'start_date',
    'end_date',
    'next_due_date'
  ];

  if (key && dateFields.includes(key) && val) {
    let dateStr = '';
    if (val instanceof Date) {
      dateStr = val.toISOString();
    } else {
      const parsedDate = new Date(val);
      if (!isNaN(parsedDate.getTime())) {
        dateStr = parsedDate.toISOString();
      }
    }

    if (dateStr) {
      const dateOnlyFields = ['snapshot_date', 'start_date', 'end_date', 'next_due_date'];
      if (dateOnlyFields.includes(key)) {
        if (dateStr.includes('T')) {
          dateStr = dateStr.split('T')[0] + 'T00:00:00Z';
        }
      }
      return { timestampValue: dateStr };
    }
  }

  if (val instanceof Date) {
    return { timestampValue: val.toISOString() };
  }
  if (typeof val === 'string') {
    return { stringValue: val };
  }
  if (typeof val === 'number') {
    return { doubleValue: val };
  }
  if (typeof val === 'boolean') {
    return { booleanValue: val };
  }
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(v => toFirestoreValue(v)) } };
  }
  if (val === null || val === undefined) {
    return { nullValue: null };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const k in val) {
      fields[k] = toFirestoreValue(val[k], k);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

// 5. Firestore batch writer
async function writeToFirestore(collectionId, records, projectId, accessToken) {
  if (records.length === 0) return;

  const batchSize = 500;
  for (let i = 0; i < records.length; i += batchSize) {
    const chunk = records.slice(i, i + batchSize);

    const writes = chunk.map(record => {
      const docId = record.id;
      const docPath = `projects/${projectId}/databases/(default)/documents/${collectionId}/${docId}`;

      const firestoreFields = {};
      for (const key in record) {
        if (key !== 'id') {
          firestoreFields[key] = toFirestoreValue(record[key], key);
        }
      }

      return {
        update: {
          name: docPath,
          fields: firestoreFields
        }
      };
    });

    const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ writes: writes })
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Failed to commit batch to Firestore for ${collectionId}: ${response.status} - ${errText}`);
    }
  }
}

// 6. Main Orchestrator
async function sync() {
  console.log('Starting Supabase-to-Firebase database replication...\n');

  try {
    console.log('1. Authenticating to Firebase Firestore...');
    const accessToken = await getFirestoreAccessToken(firebaseCreds);
    console.log('   Authenticated successfully.\n');

    const tablesToSync = [
      'accounts',
      'account_snapshots',
      'categories',
      'transactions',
      'assets',
      'asset_transactions',
      'holdings',
      'recurring_transactions',
      'budget_targets'
    ];

    console.log('2. Syncing tables from Supabase...');
    for (const table of tablesToSync) {
      process.stdout.write(`   • Syncing table "${table}"... `);
      try {
        const records = await fetchAllFromSupabase(table, SUPABASE_PROJECT_REF, SUPABASE_SERVICE_ROLE_KEY);
        
        if (records.length === 0) {
          console.log('\x1b[33m0 records found.\x1b[0m');
          continue;
        }

        await writeToFirestore(table, records, FIREBASE_PROJECT_ID, accessToken);
        console.log(`\x1b[32mCompleted (${records.length} records).\x1b[0m`);
      } catch (err) {
        console.log(`\x1b[31mFailed\x1b[0m`);
        console.error(`     Error: ${err.message}`);
      }
    }

    console.log('\n\x1b[32m✔ Replication completed successfully.\x1b[0m');
  } catch (err) {
    console.error(`\n\x1b[31m✘ Critical Error: ${err.message}\x1b[0m`);
    process.exit(1);
  }
}

sync();
