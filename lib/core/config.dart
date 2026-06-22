class AppConfig {
  static const String fxRatesApiKey = String.fromEnvironment(
    'FXRATES_API_KEY',
    defaultValue: 'GJ1ZHSTNDD9T2CEH',
  );
  static const String supabaseProjectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
    defaultValue: 'ubjvlwnzcyogxcwzdypd',
  );
  static const String supabaseServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVianZsd256Y3lvZ3hjd3pkeXBkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTQ4MDQzMywiZXhwIjoyMDk3MDU2NDMzfQ.LU9J_aw4yo0zmqktjrMx8qVlJTEntgqRR1zuob1Sns4',
  );
  static const String alphaVantageApiKey = String.fromEnvironment(
    'ALPHAVANTAGE_API_KEY',
    defaultValue: 'RYN05MCEKCR4F107',
  );
}
