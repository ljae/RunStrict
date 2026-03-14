class SupabaseConfig {
  // Production: set via --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  // Development: falls back to dev project credentials below.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vhooaslzkmbnzmzwiium.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZob29hc2x6a21ibnptendpaXVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyMjU0NDUsImV4cCI6MjA4NDgwMTQ0NX0.rS8RiafXT81GJEuWXU-bNT_DQOAlLGh8uLTzyW_oJqI',
  );
}
