import 'dart:convert';

import 'package:http/http.dart' as http;

/// The sales knowledge, fetched over HTTP when the app starts.
///
/// The blueprint allows embedding or fetching. This arm fetches: Jaspr builds
/// to static files in `web/`, so the knowledge base is copied there by
/// `tools/sync-domain.sh` and read from the app's own origin. That keeps the
/// knowledge out of the compiled JavaScript and lets it change without a
/// rebuild.
class Knowledge {
  Knowledge._(this.corpus, this.landingUrls);

  final String corpus;

  /// The landing page address of each machine, read out of the knowledge base.
  ///
  /// The app looks the address up rather than taking one the model repeats
  /// back, because a URL that has been through a language model can come back
  /// a path segment short.
  final Map<String, String> landingUrls;

  static const models = ['mini', 'slim', 'classic', 'family', 'silent', 'eco'];

  static Future<Knowledge> load() async {
    final base = await _get('domain/knowledge.md');
    final buffer = StringBuffer(base);
    for (final name in models) {
      buffer.writeln(
        '\n\n--- landing page: $name ---\n'
        '${await _get('domain/landing_pages/$name.md')}',
      );
    }

    final urls = <String, String>{};
    final pattern = RegExp(r'\((https://[^)\s]*landing_pages/([a-z]+)\.md)\)');
    for (final match in pattern.allMatches(base)) {
      urls[match.group(2)!] = match.group(1)!;
    }

    return Knowledge._(buffer.toString(), urls);
  }

  static Future<String> _get(String path) async {
    final response = await http.get(Uri.base.resolve(path));
    if (response.statusCode != 200) {
      throw StateError('Could not read $path (${response.statusCode}).');
    }
    return utf8.decode(response.bodyBytes);
  }
}
