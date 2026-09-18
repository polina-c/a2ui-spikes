/// The entry point for the browser.
///
/// The whole site is this: a page, a model that arrives from a CDN and stays
/// in the browser's cache, and the facts in `knowledge.dart`. There is no
/// server beyond whatever serves these files, which on a Wix site is Wix.
library;

import 'package:jaspr/client.dart';
import 'package:logging/logging.dart';

import 'app.dart';

void main() {
  // package:genui logs through package:logging, which is silent unless a
  // level is set. Turn it up to WARNING or lower while debugging.
  Logger.root.level = Level.SEVERE;
  Logger.root.onRecord.listen((LogRecord record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.loggerName}: ${record.message}');
  });

  runApp(const App());
}
