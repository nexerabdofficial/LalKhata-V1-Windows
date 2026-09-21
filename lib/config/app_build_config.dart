class AppBuildConfig {
  AppBuildConfig._();

  /// Normal build:
  /// flutter build linux
  ///
  /// White-label build:
  /// flutter build linux --dart-define=WHITE_LABEL=true
  static const bool whiteLabel = bool.fromEnvironment(
    'WHITE_LABEL',
    defaultValue: false,
  );

  static bool get showDeveloperBranding => !whiteLabel;
}
