/// OAuth configuration for social sign-in providers.
///
/// Replace placeholder values with your actual OAuth client IDs
/// from Apple Developer Console and Google Cloud Console.
class AuthConfig {
  AuthConfig._();

  // ============================================================
  // Apple Sign-In
  // ============================================================
  // Configured in Apple Developer Console > Certificates,
  // Identifiers & Profiles > Identifiers > Sign In with Apple
  //
  // No client ID needed for native iOS — uses entitlement.
  // For Android/web, configure Apple Services ID.

  // ============================================================
  // Google Sign-In
  // ============================================================
  // Configured in Google Cloud Console > APIs & Services > Credentials
  //
  // iOS: Create OAuth 2.0 Client ID (iOS type) with your bundle ID
  // Web: Create OAuth 2.0 Client ID (Web type) for Supabase callback

  /// Google OAuth client ID for iOS (from Google Cloud Console)
  static const String googleIosClientId =
      'YOUR_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com';

  /// Google OAuth web client ID (used as serverClientId for Supabase)
  static const String googleWebClientId =
      'YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com';
}
