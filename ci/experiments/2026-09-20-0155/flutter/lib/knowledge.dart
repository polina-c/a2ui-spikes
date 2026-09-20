import 'package:flutter/services.dart';

/// The sales knowledge, loaded from the bundled assets.
///
/// Flutter only bundles assets from inside the package, so this arm embeds a
/// copy of `ci/domain` rather than reading it in place; `tools/sync-domain.sh`
/// keeps the copy current.
class Knowledge {
  Knowledge._(this.corpus, this.landingUrls);

  /// The knowledge base and every landing page, as one block for the prompt.
  final String corpus;

  /// The landing page address of each machine, read out of the knowledge base.
  ///
  /// The app resolves the link itself instead of trusting a URL the model
  /// repeats back, because a repeated URL can come back a path segment short.
  final Map<String, String> landingUrls;

  static const _models = ['mini', 'slim', 'classic', 'family', 'silent', 'eco'];

  static Future<Knowledge> load() async {
    final base = await rootBundle.loadString('assets/domain/knowledge.md');
    final buffer = StringBuffer(base);
    for (final name in _models) {
      final page = await rootBundle.loadString(
        'assets/domain/landing_pages/$name.md',
      );
      buffer.writeln('\n\n--- landing page: $name ---\n$page');
    }

    final urls = <String, String>{};
    final pattern = RegExp(r'\((https://[^)\s]*landing_pages/([a-z]+)\.md)\)');
    for (final match in pattern.allMatches(base)) {
      urls[match.group(2)!] = match.group(1)!;
    }

    return Knowledge._(buffer.toString(), urls);
  }

  /// The ids the model may name when it asks for a landing page.
  List<String> get modelIds => _models;
}
