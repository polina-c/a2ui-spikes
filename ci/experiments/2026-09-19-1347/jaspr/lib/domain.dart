// The sales knowledge, fetched over HTTP.
//
// The blueprint allows embedding or fetching. This arm fetches: `web/domain` is
// a symlink to the repo's domain folder, so the files are served next to the
// app and read at startup. It keeps the knowledge out of the compiled bundle,
// which means it can be changed without rebuilding.

import 'package:http/http.dart' as http;

const List<String> _pages = [
  'classic',
  'eco',
  'family',
  'mini',
  'silent',
  'slim',
];

Future<String> loadDomainCorpus() async {
  Future<String> fetch(String path) async {
    final res = await http.get(Uri.parse(path));
    if (res.statusCode != 200) {
      throw Exception('could not read $path (HTTP ${res.statusCode})');
    }
    return res.body;
  }

  final knowledge = await fetch('domain/knowledge.md');
  final pages = <String>[];
  for (final name in _pages) {
    pages.add(
      '--- landing page: $name ---\n'
      '${await fetch('domain/landing_pages/$name.md')}',
    );
  }
  return '$knowledge\n\n${pages.join('\n\n')}';
}
