class AppRuntimeController {
  AppRuntimeController({required this.resetApp});

  final Future<void> Function() resetApp;
}
