import 'package:flutter/services.dart';

/// Paths of the bundled documents that make up the system prompt.
class _Assets {
  static const String chatBlueprint =
      'assets/doc/blueprints/0-chat-specifications.md';
  static const String domain = 'assets/doc/domain/just_shining';
  static const String knowledge = '$domain/knowledge.md';
  static const String landingPages = '$domain/landing_pages/';
}

/// Reads the system prompt: how to guide the user, then the domain knowledge,
/// then every landing page.
Future<String> loadSystemPrompt() async {
  final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
    rootBundle,
  );
  final List<String> landingPages =
      manifest
          .listAssets()
          .where((path) => path.startsWith(_Assets.landingPages))
          // The folder's README describes the folder, not a product.
          .where((path) => !path.endsWith('README.md'))
          .toList()
        ..sort();

  final List<String> documents = [];
  for (final path in [
    _Assets.chatBlueprint,
    _Assets.knowledge,
    ...landingPages,
  ]) {
    documents.add(await rootBundle.loadString(path));
  }
  return documents.join('\n\n---\n\n');
}
