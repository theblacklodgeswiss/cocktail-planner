/// Environment configuration for API keys and secrets.
/// 
/// Values are injected at build time via --dart-define flags.
/// 
/// Local development: Use run_local.sh or pass --dart-define manually
/// CI/CD: Secrets are passed automatically in GitHub Actions
class EnvConfig {
  /// Current environment flavor (dev or prod)
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  /// Check if running in development environment
  static bool get isDev => flavor == 'dev';

  /// Check if running in production environment
  static bool get isProd => flavor == 'prod';

  /// Gemini AI API key for AI features
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Check if Gemini API is configured
  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;

  /// Check if OneDrive uploads should be enabled (only in production)
  static bool get isOneDriveEnabled => isProd;
}
