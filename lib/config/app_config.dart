class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const sosEndpoint = String.fromEnvironment('SOS_ENDPOINT');

  /// Registered business / operator identity. Required before a production
  /// release so that the legal screens name a real, contactable entity.
  static const businessName = String.fromEnvironment('BUSINESS_NAME');
  static const businessAddress = String.fromEnvironment('BUSINESS_ADDRESS');
  static const privacyEmail = String.fromEnvironment('PRIVACY_EMAIL');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  /// The version stamp recorded against a user's Terms / Privacy consent.
  /// Bump this whenever the wording of the legal screens changes materially
  /// so that existing users can be asked to re-consent.
  static const legalConsentVersion = '2026-09-07';

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Every business-identity field a production build must carry. Used by the
  /// release-readiness checklist and the in-app configuration warning.
  static bool get hasBusinessDetails =>
      businessName.isNotEmpty &&
      businessAddress.isNotEmpty &&
      privacyEmail.isNotEmpty &&
      supportEmail.isNotEmpty;
}
