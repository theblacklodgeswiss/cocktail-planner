/// Environment configuration for API keys and secrets.
/// 
/// Values are injected at build time via --dart-define flags.
/// 
/// Local development: Use run_local.sh or pass --dart-define manually
/// CI/CD: Secrets are passed automatically in GitHub Actions
class EnvConfig {
  /// Gemini AI API key for AI features
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Check if Gemini API is configured
  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;
}
