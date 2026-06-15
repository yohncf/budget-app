// ==========================================
// Budget App Google Sheets Sync Engine
// ==========================================

// --- CONFIGURATION ---
const FIREBASE_PROJECT_ID = "budget-app-81120";
const FIREBASE_API_KEY = "YOUR_FIREBASE_WEB_API_KEY"; // Replace with your Web API Key from Firebase Console Settings
const SUPABASE_PROJECT_REF = "ubjvlwnzcyogxcwzdypd";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";   // Replace with your Supabase Anon/Service Role Key

// Add a custom menu to the spreadsheet on open
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('Budget App Sync')
    .addItem('Sync All Sheets to Firestore & Supabase', 'syncAll')
    .addToUi();
}

// Main execution function
function syncAll() {
  const ui = SpreadsheetApp.getUi();
  
  if (FIREBASE_API_KEY === "YOUR_FIREBASE_WEB_API_KEY" || SUPABASE_ANON_KEY === "YOUR_SUPABASE_ANON_KEY") {
    ui.alert("Configuration Error", "Please configure your Firebase API Key and Supabase Anon Key at the top of the script first.", ui.ButtonSet.OK);
    return;
  }

  const sheetsToSync = [
    { name: 'accounts', collection: 'accounts', type: 'accounts' },
    { name: 'categories', collection: 'categories', type: 'categories' },
    { name: 'transactions', collection: 'transactions', type: 'transactions' },
    { name: 'assets', collection: 'assets', type: 'assets' },
    { name: 'asset_transactions', collection: 'asset_transactions', type: 'asset_transactions' },
    { name: 'holdings', collection: 'holdings', type: 'holdings' },
    { name: 'recurring_transactions', collection: 'recurring_transactions', type: 'recurring_transactions' },
    { name: 'budget_targets', collection: 'budget_targets', type: 'budget_targets' },
    { name: 'system_settings', collection: 'system_settings', type: 'system_settings' }
  ];

  let summaryMsg = "Sync Results:\n\n";

  for (const target of sheetsToSync) {
    try {
      const result = syncSheet(target.name, target.collection);
      summaryMsg += `• ${target.name}: Synced ${result.count} records successfully.\n`;
    } catch (e) {
      summaryMsg += `• ${target.name}: FAILED - ${e.message}\n`;
    }
  }

  ui.alert("Sync Status", summaryMsg, ui.ButtonSet.OK);
}

// Synchronize an individual sheet
function syncSheet(sheetName, collectionId) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(sheetName);
  
  if (!sheet) {
    throw new Error(`Sheet "${sheetName}" not found in the spreadsheet.`);
  }

  const range = sheet.getDataRange();
  const values = range.getValues();
  
  if (values.length < 2) {
    return { count: 0 }; // Only headers or empty
  }

  const headers = values[0];
  const idColIndex = headers.indexOf('id');
  
  if (idColIndex === -1) {
    throw new Error(`Sheet "${sheetName}" is missing the mandatory "id" column.`);
  }

  const records = [];
  
  for (let r = 1; r < values.length; r++) {
    const row = values[r];
    let recordId = row[idColIndex];
    
    // Rule 1.1: Generate a unique 20-char alphanumeric string if the ID is missing
    if (!recordId || String(recordId).trim() === "") {
      recordId = generateId();
      sheet.getRange(r + 1, idColIndex + 1).setValue(recordId); // Write ID back to spreadsheet row
      row[idColIndex] = recordId;
    }

    const record = {};
    for (let c = 0; c < headers.length; c++) {
      let val = row[c];
      
      // Convert dates to ISO strings
      if (val instanceof Date) {
        val = val.toISOString();
      }
      
      // Parse JSON string arrays/objects if field is tags or config_value
      if ((headers[c] === 'tags' || headers[c] === 'config_value') && typeof val === 'string' && val.startsWith('[')) {
        try {
          val = JSON.parse(val);
        } catch (e) {
          // If parse fails, treat as normal string
        }
      }

      record[headers[c]] = val;
    }

    // Rule 1.1: Traceability row identifier for transaction logging
    if (sheetName === 'transactions') {
      record['sheets_row_id'] = r + 1; // row number in Sheets (1-indexed)
    }

    records.push(record);
  }

  // Push to Firestore & Supabase
  syncToFirestore(collectionId, records);
  syncToSupabase(sheetName, records);

  return { count: records.length };
}

// 20-character alphanumeric generator
function generateId() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < 20; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// Sync to Firestore REST API (using document PATCH for upsert)
function syncToFirestore(collectionId, records) {
  for (const record of records) {
    const docId = record.id;
    const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/${collectionId}/${docId}?key=${FIREBASE_API_KEY}`;
    
    // Format JSON to Firestore REST values format
    const firestoreFields = {};
    for (const key in record) {
      if (key !== 'id') {
        firestoreFields[key] = toFirestoreValue(record[key]);
      }
    }

    const payload = {
      fields: firestoreFields
    };

    const options = {
      method: 'patch',
      contentType: 'application/json',
      payload: JSON.stringify(payload),
      muteHttpExceptions: false
    };

    UrlFetchApp.fetch(url, options);
  }
}

// Helper to convert JS values to Firestore typed values
function toFirestoreValue(val) {
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
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (val === null || val === undefined) {
    return { nullValue: null };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const k in val) {
      fields[k] = toFirestoreValue(val[k]);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

// Sync to Supabase REST API (Upsert)
function syncToSupabase(tableName, records) {
  const url = `https://${SUPABASE_PROJECT_REF}.supabase.co/rest/v1/${tableName}`;
  
  // Format payload for PostgreSQL compatibility
  const supabaseRecords = records.map(record => {
    const formatted = { ...record };
    
    // Convert tags array into PG array format e.g. ["a", "b"] -> {a,b}
    if (Array.isArray(formatted.tags)) {
      formatted.tags = `{${formatted.tags.join(',')}}`;
    }
    
    return formatted;
  });

  const options = {
    method: 'post',
    contentType: 'application/json',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Prefer': 'resolution=merge-duplicates' // Upsert merge duplicates
    },
    payload: JSON.stringify(supabaseRecords),
    muteHttpExceptions: false
  };

  UrlFetchApp.fetch(url, options);
}
