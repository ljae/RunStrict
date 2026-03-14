// Mapbox configuration
//
// To use Mapbox in this app:
// 1. Get a free access token from https://account.mapbox.com/access-tokens/
// 2. Replace the placeholder below with your actual token
// 3. For production, use environment variables or secure storage

class MapboxConfig {
  // Production: set via --dart-define=MAPBOX_ACCESS_TOKEN=...
  // Development: falls back to dev token below.
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );
}
