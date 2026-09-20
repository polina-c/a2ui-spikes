// The sales knowledge, loaded from assets.
//
// The blueprint allows embedding or fetching over HTTP. Flutter assets are the
// embedding path here: assets/domain is a symlink to the repo's domain folder,
// so the app ships the same text the other arms use without a second copy of
// it in the tree.

import 'package:flutter/services.dart';

const List<String> _pages = [
  'classic',
  'eco',
  'family',
  'mini',
  'silent',
  'slim',
];

Future<String> loadDomainCorpus() async {
  final knowledge = await rootBundle.loadString('assets/domain/knowledge.md');
  final pages = <String>[];
  for (final name in _pages) {
    final body = await rootBundle.loadString(
      'assets/domain/landing_pages/$name.md',
    );
    pages.add('--- landing page: $name ---\n$body');
  }
  return '$knowledge\n\n${pages.join('\n\n')}';
}
