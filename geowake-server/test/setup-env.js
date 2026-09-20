// Every suite imports the production config, which deliberately exits when
// secrets are absent. Supply inert, deterministic values before any test file
// is evaluated; individual suites remain free to override them before import.
process.env.NODE_ENV = 'test';
process.env.GOOGLE_MAPS_API_KEY =
  process.env.GOOGLE_MAPS_API_KEY || 'test-maps-key';
process.env.JWT_SECRET =
  process.env.JWT_SECRET || 'test-jwt-secret-at-least-32-characters-long';
process.env.APP_BUNDLE_ID = process.env.APP_BUNDLE_ID || 'com.geowake.app';
