class AppConstants {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: '');
  
  static const String billifyUrl = String.fromEnvironment('BILLIFY_URL', defaultValue: '');
  static const String billifyKey = String.fromEnvironment('BILLIFY_KEY', defaultValue: '');
  
  static const String billifySyncUrl = 'https://www.ezbillify.com/api/integrations/ez-launch/';
  static const String billifySyncToken = String.fromEnvironment('EZBILLIFY_SYNC_TOKEN', defaultValue: '');
  
  // App Branding
  static const String appName = 'EzLaunch';
  static const String appTagline = 'Smart Onboarding Engine';
  
  // Design Tokens
  static const double borderRadius = 16.0;
  static const double padding = 20.0;
}
