class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const sosEndpoint = String.fromEnvironment('SOS_ENDPOINT');
  static const businessName = String.fromEnvironment('BUSINESS_NAME');
  static const businessAddress = String.fromEnvironment('BUSINESS_ADDRESS');
  static const privacyEmail = String.fromEnvironment('PRIVACY_EMAIL');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

    static bool get hasBusinessDetails =>
      businessName.isNotEmpty || businessAddress.isNotEmpty || privacyEmail.isNotEmpty;
}
