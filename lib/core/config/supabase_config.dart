/// Supabase Environment and Configuration
class SupabaseConfig {
  SupabaseConfig._();

  // Project URL and Public Anon Key provided by user
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hracsznusepxhcpznita.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhyYWNzem51c2VweGhjcHpuaXRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM4NzA1NzEsImV4cCI6MjEwOTQ0NjU3MX0.Y6pBsBJNoWvJmpr0a7esPtASBWtysUIVLRyWxt9iVQg',
  );

  /// Checks if valid Supabase credentials have been configured
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT_ID') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');
}
