import 'package:logging/logging.dart';

/// The logger used throughout this package.
///
/// Hierarchical logging is off by default in `package:logging`, so raising
/// [Logger.root]'s level is what turns these records on:
///
/// ```dart
/// Logger.root.level = Level.ALL;
/// Logger.root.onRecord.listen((r) => print('${r.level.name}: ${r.message}'));
/// ```
final Logger genUiLogger = Logger('genui');
