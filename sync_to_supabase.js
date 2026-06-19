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
  process.exit(1);
}

if (!SUPABASE_SERVICE_ROLE_KEY || SUPABASE_SERVICE_ROLE_KEY.startsWith('YOUR_')) {
  console.error('\x1b[31mError: SUPABASE_SERVICE_ROLE_KEY is not configured.\x1b[0m');
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

// 3. Convert Firestore value types back to clean JS types
function fromFirestoreValue(field) {
  if (!field) return null;
  if ('stringValue' in field) return field.stringValue;
  if ('doubleValue' in field) return Number(field.doubleValue);
  if ('integerValue' in field) return Number(field.integerValue);
  if ('booleanValue' in field) return field.booleanValue;
  if ('timestampValue' in field) return field.timestampValue;
  if ('arrayValue' in field) {
    const values = field.arrayValue.values || [];
    return values.map(v => fromFirestoreValue(v));
  }
  if ('mapValue' in field) {
    const fields = field.mapValue.fields || {};
    const obj = {};
    for (const key in fields) {
      obj[key] = fromFirestoreValue(fields[key]);
    }
    return obj;
  }
  if ('nullValue' in field) return null;
  return null;
}

// 4. Fetch all documents paginated from Firestore
async function fetchAllFromFirestore(collectionId, projectId, accessToken) {
  let allRecords = [];
  let pageToken = '';

  while (true) {
    let url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collectionId}?pageSize=100`;
    if (pageToken) {
      url += `&pageToken=${pageToken}`;
    }

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });

    if (!response.ok) {
      if (response.status === 404) {
        return [];
      }
      const errText = await response.text();
      throw new Error(`Failed to fetch ${collectionId} from Firestore: ${response.status} - ${errText}`);
    }

    const data = await response.json();
    const documents = data.documents || [];

    for (const doc of documents) {
      const docId = doc.name.split('/').pop();
      const record = { id: docId };
      for (const key in doc.fields) {
        record[key] = fromFirestoreValue(doc.fields[key]);
      }
      allRecords.push(record);
    }

    if (data.nextPageToken) {
      pageToken = data.nextPageToken;
    } else {
      break;
    }
  }

  return allRecords;
}

// 5. Sync records to Supabase REST API (Upsert)
async function writeToSupabase(tableName, records, projectRef, serviceRoleKey) {
  if (records.length === 0) return;

  const url = `https://${projectRef}.supabase.co/rest/v1/${tableName}`;

  const floatFields = ['current_balance', 'limit', 'balance', 'amount', 'exchange_rate', 'quantity', 'unit_price', 'avg_buy_price', 'target_amount'];
  const supabaseRecords = records.map(record => {
    const formatted = { ...record };

    for (const key in formatted) {
      if (floatFields.includes(key) && formatted[key] !== null && formatted[key] !== undefined) {
        formatted[key] = parseFloat(formatted[key]);
      }
    }

    if (formatted.hasOwnProperty('tags')) {
      let tagsArray = [];
      if (Array.isArray(formatted.tags)) {
        tagsArray = formatted.tags;
      } else if (typeof formatted.tags === 'string' && formatted.tags.trim() !== '') {
        tagsArray = formatted.tags.split(',').map(t => t.trim()).filter(t => t.length > 0);
      }
      formatted.tags = `{${tagsArray.map(t => `"${t.replace(/"/g, '\\"')}"`).join(',')}}`;
    }

    return formatted;
  });

  const options = {
    method: 'POST',
    headers: {
      'apikey': serviceRoleKey,
      'Authorization': `Bearer ${serviceRoleKey}`,
      'Prefer': 'resolution=merge-duplicates',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(supabaseRecords)
  };

  const response = await fetch(url, options);
  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Failed to write to Supabase for ${tableName}: ${response.status} - ${errText}`);
  }
}

// 6. Main Sync Orchestrator
async function sync() {
  console.log('Starting Firestore-to-Supabase database replication...\n');

  try {
    console.log('1. Authenticating to Firebase Firestore...');
    const accessToken = await getFirestoreAccessToken(firebaseCreds);
    console.log('   Authenticated successfully.\n');

    let tablesToSync = [
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

    const args = process.argv.slice(2);
    if (args.length > 0) {
      tablesToSync = tablesToSync.filter(t => args.includes(t));
      if (tablesToSync.length === 0) {
        console.log('\x1b[31mError: No valid tables specified.\x1b[0m');
        process.exit(1);
      }
    }

    console.log('2. Syncing tables from Firestore...');
    for (const table of tablesToSync) {
      process.stdout.write(`   • Syncing table "${table}"... `);
      try {
        const records = await fetchAllFromFirestore(table, FIREBASE_PROJECT_ID, accessToken);

        if (records.length === 0) {
          console.log('\x1b[33m0 records found.\x1b[0m');
          continue;
        }

        await writeToSupabase(table, records, SUPABASE_PROJECT_REF, SUPABASE_SERVICE_ROLE_KEY);
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
