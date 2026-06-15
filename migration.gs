// ==========================================
// Budget App Google Sheets Sync Engine
// ==========================================

// --- CONFIGURATION ---
const FIREBASE_PROJECT_ID = "budget-app-81120";
const FIREBASE_API_KEY = "YOUR_FIREBASE_WEB_API_KEY"; // Replace with your Web API Key from Firebase Console Settings
const SUPABASE_PROJECT_REF = "ubjvlwnzcyogxcwzdypd";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_SERVICE_ROLE_KEY";   // MUST BE THE Supabase SERVICE_ROLE KEY (secret key) to bypass Row-Level Security

// Valid database schema columns manifest to filter out extra sheet columns
const VALID_COLUMNS = {
  accounts: ['id', 'name', 'type', 'institution', 'currency', 'current_balance', 'status', 'account_group', 'created_at', 'updated_at', 'limit'],
  account_snapshots: ['id', 'account_id', 'snapshot_date', 'balance', 'currency', 'created_at'],
  categories: ['id', 'name', 'type', 'parent_id', 'icon', 'color_hex', 'created_at'],
  transactions: ['id', 'account_id', 'category_id', 'amount', 'currency', 'exchange_rate', 'date', 'description', 'status', 'is_recurring', 'recurring_id', 'tags', 'sheets_row_id', 'created_at'],
  assets: ['id', 'symbol', 'name', 'type'],
  asset_transactions: ['id', 'transaction_id', 'account_id', 'asset_id', 'type', 'quantity', 'unit_price', 'executed_at'],
  holdings: ['id', 'account_id', 'asset_id', 'quantity', 'avg_buy_price', 'updated_at'],
  recurring_transactions: ['id', 'account_id', 'category_id', 'amount', 'frequency', 'interval', 'start_date', 'end_date', 'next_due_date', 'status', 'description'],
  budget_targets: ['id', 'category_id', 'target_amount', 'period', 'start_date', 'end_date', 'created_at']
};

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
  
  if (FIREBASE_API_KEY === "YOUR_FIREBASE_WEB_API_KEY" || SUPABASE_ANON_KEY === "YOUR_SUPABASE_ANON_KEY" || SUPABASE_ANON_KEY === "YOUR_SUPABASE_SERVICE_ROLE_KEY") {
    ui.alert("Configuration Error", "Please configure your Firebase API Key and Supabase Service Role Key at the top of the script first.", ui.ButtonSet.OK);
    return;
  }

  const sheetsToSync = [
    { name: 'accounts', collection: 'accounts', type: 'accounts' },
    { name: 'account_snapshots', collection: 'account_snapshots', type: 'account_snapshots' },
    { name: 'categories', collection: 'categories', type: 'categories' },
    { name: 'transactions', collection: 'transactions', type: 'transactions' },
    { name: 'assets', collection: 'assets', type: 'assets' },
    { name: 'asset_transactions', collection: 'asset_transactions', type: 'asset_transactions' },
    { name: 'holdings', collection: 'holdings', type: 'holdings' },
    { name: 'recurring_transactions', collection: 'recurring_transactions', type: 'recurring_transactions' },
    { name: 'budget_targets', collection: 'budget_targets', type: 'budget_targets' }
  ];

  let summaryMsg = "Sync Results:\n\n";
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  for (const target of sheetsToSync) {
    try {
      const sheet = ss.getSheetByName(target.name);
      if (!sheet) {
        summaryMsg += `• ${target.name}: SKIPPED (Sheet not found in spreadsheet).\n`;
        continue;
      }
      const result = syncSheet(sheet, target.name, target.collection);
      summaryMsg += `• ${target.name}: Synced ${result.count} records successfully.\n`;
    } catch (e) {
      summaryMsg += `• ${target.name}: FAILED - ${e.message}\n`;
    }
  }

  ui.alert("Sync Status", summaryMsg, ui.ButtonSet.OK);
}

// Synchronize an individual sheet
// Synchronize an individual sheet
function syncSheet(sheet, sheetName, collectionId) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const range = sheet.getDataRange();
  const values = range.getValues();
  
  if (values.length < 2) {
    return { count: 0 }; // Only headers or empty
  }

  const rawHeaders = values[0];
  const headers = rawHeaders.map(h => String(h).trim().toLowerCase());
  const idColIndex = headers.indexOf('id');
  
  if (idColIndex === -1) {
    throw new Error(`Sheet "${sheetName}" is missing the mandatory "id" column.`);
  }

  const records = [];
  const validCols = VALID_COLUMNS[sheetName] || [];
  let sheetModified = false;
  
  for (let r = 1; r < values.length; r++) {
    const row = values[r];
    let recordId = row[idColIndex];
    
    // Generate a unique 20-char alphanumeric string if the ID is missing
    if (!recordId || String(recordId).trim() === "") {
      recordId = generateId();
      row[idColIndex] = recordId; // Update in memory
      sheetModified = true;
    }

    const record = {};
    for (let c = 0; c < rawHeaders.length; c++) {
      const colName = headers[c];
      
      // Filter out any columns that are not in the valid schema column list
      if (!colName || !validCols.includes(colName)) {
        continue;
      }

      let val = row[c];
      
      // Convert dates to ISO strings / date strings
      if (val instanceof Date) {
        const dateOnlyFields = ['snapshot_date', 'start_date', 'end_date', 'next_due_date'];
        const timezone = ss.getSpreadsheetTimeZone();
        if (dateOnlyFields.includes(colName)) {
          val = Utilities.formatDate(val, timezone, "yyyy-MM-dd");
        } else {
          val = val.toISOString();
        }
      }
      
      // Parse JSON string arrays/objects if field is tags or config_value
      if ((colName === 'tags' || colName === 'config_value') && typeof val === 'string' && val.startsWith('[')) {
        try {
          val = JSON.parse(val);
        } catch (e) {
          // If parse fails, treat as normal string
        }
      }

      record[colName] = val;
    }

    // Traceability row identifier for transaction logging
    if (sheetName === 'transactions' && validCols.includes('sheets_row_id')) {
      record['sheets_row_id'] = r + 1; // row number in Sheets (1-indexed)
    }

    // Force set the correct ID
    record['id'] = recordId;

    records.push(record);
  }

  // Write all generated IDs back to the sheet in a single batch call if modified
  if (sheetModified) {
    range.setValues(values);
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

// Sync to Firestore REST API (using commit batch writes, max 500 writes per batch)
function syncToFirestore(collectionId, records) {
  if (records.length === 0) return;

  const batchSize = 500;
  for (let i = 0; i < records.length; i += batchSize) {
    const chunk = records.slice(i, i + batchSize);
    
    const writes = chunk.map(record => {
      const docId = record.id;
      const docPath = `projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/${collectionId}/${docId}`;
      
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

    const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents:commit?key=${FIREBASE_API_KEY}`;
    const options = {
      method: 'post',
      contentType: 'application/json',
      payload: JSON.stringify({ writes: writes }),
      muteHttpExceptions: false
    };

    UrlFetchApp.fetch(url, options);
  }
}

// Helper to convert JS values to Firestore typed values
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
      // Try to parse string or number robustly
      const parsedDate = new Date(val);
      if (!isNaN(parsedDate.getTime())) {
        dateStr = parsedDate.toISOString();
      }
    }

    if (dateStr) {
      // Ensure date-only fields are padded to T00:00:00Z for Firestore compatibility
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

// Sync to Supabase REST API (Upsert)
function syncToSupabase(tableName, records) {
  const url = `https://${SUPABASE_PROJECT_REF}.supabase.co/rest/v1/${tableName}`;
  
  // Format payload for PostgreSQL compatibility
  const supabaseRecords = records.map(record => {
    const formatted = { ...record };
    
    // Convert tags to PG array format robustly
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
