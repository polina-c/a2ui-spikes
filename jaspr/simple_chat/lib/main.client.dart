/// The entry point for the browser.
///
/// The whole app runs here: the model, the conversation and the surfaces it
/// generates. There is no server beyond whatever serves these files.
library;

import 'package:jaspr/client.dart';
import 'package:logging/logging.dart';

import 'app.dart';

void main() {
  // The genui package logs through package:logging, which is silent unless
  // a level is set. Turn it up to watch A2UI messages arrive.
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.loggerName}: ${record.message}');
  });

  runApp(const App());
}
