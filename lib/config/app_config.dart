class AppConfig {
  // API key is now handled by the secure server
  // Direct access is disabled for security
  static String get googleMapsApiKey {
    throw Exception(
      'Direct API key access is disabled for security. All Google Maps API calls now go through the secure server via ApiClient.',
    );
  }

  // For debugging purposes - shows API key source
  static String get apiKeySource {
    return 'Secure Server';
  }

  // Server configuration. Override at build time to move the same hardened API
  // between Railway, Oracle Cloud, or staging without changing application code.
  static const String serverBaseUrl = String.fromEnvironment(
    'GEOWAKE_API_BASE_URL',
    defaultValue: 'https://geowake-production.up.railway.app/api',
  );

  // Unified bundle ID - must match:
  // - android/app/build.gradle
  // - android/app/build.gradle.kts
  // - geowake-server/src/config/config.js (APP_BUNDLE_ID env)
  static const String appBundleId = 'com.geowake.app';

  /// Explicit opt-in for field-validation builds. When enabled, the tracking
  /// isolate writes raw IMU samples, GPS fixes and EKF state to device-local
  /// logs for post-journey replay. Normal production builds cannot collect
  /// these raw traces accidentally.
  static const bool fieldDiagnosticsEnabled = bool.fromEnvironment(
    'GEOWAKE_FIELD_DIAGNOSTICS',
    defaultValue: false,
  );
}
