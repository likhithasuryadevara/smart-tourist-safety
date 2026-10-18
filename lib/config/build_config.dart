// Build-time configuration for feature flags and environment-specific behavior.
// Values are set at compile time via --dart-define and cannot be changed at runtime.
// Default values ensure secure production behavior; development overrides require explicit flags.

/// Whether email verification is required for Tourist dashboard access.
/// Default: true (secure production behavior).
/// Override with: --dart-define=REQUIRE_EMAIL_VERIFICATION=false
const bool kRequireEmailVerification = bool.fromEnvironment(
  'REQUIRE_EMAIL_VERIFICATION',
  defaultValue: true,
);