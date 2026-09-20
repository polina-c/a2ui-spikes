// Loads the app with CanvasKit served from this app rather than from
// gstatic.com, which the default loader fetches. `flutter build web` already
// copies CanvasKit into build/web/canvaskit/, so this only points at it, and
// the app then starts with no third-party request at all.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {canvasKitBaseUrl: 'canvaskit/'},
});
