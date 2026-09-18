import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:intl/intl.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:universal_web/web.dart' as web;

import '../primitives/logging.dart';

/// The functions a surface built from [basicCatalog] may call.
///
/// Functions are how a generated UI computes without the model in the loop:
/// a `checks` condition calls `required` or `regex` to decide whether a
/// button is live, and a `Text` binds to `formatCurrency` so a price shown
/// next to a slider tracks it as it moves. `formatString` comes from
/// `a2ui_core`, which is also what evaluates the `${...}` expressions in it.
List<core.FunctionImplementation> basicFunctions() => [
  core.FormatStringFunction(),
  AndFunction(),
  OrFunction(),
  NotFunction(),
  RequiredFunction(),
  RegexFunction(),
  LengthFunction(),
  NumericFunction(),
  EmailFunction(),
  FormatNumberFunction(),
  FormatCurrencyFunction(),
  FormatDateFunction(),
  PluralizeFunction(),
  OpenUrlFunction(),
];

/// A function whose result depends only on its arguments.
abstract class _SyncFunction extends core.FunctionImplementation {
  _SyncFunction();

  /// Computes the result.
  Object? call(Map<String, dynamic> args);

  @override
  Object? execute(
    Map<String, dynamic> args,
    core.DataContext context, [
    core.CancellationSignal? cancellationSignal,
  ]) => call(args);
}

/// Everything other than `false` and `null` counts as true, so that a check
/// written against a field the user has not reached yet does not read as a
/// deliberate `false`.
bool _isTruthy(Object? value) {
  if (value is bool) return value;
  return value != null;
}

/// True when every value is truthy.
class AndFunction extends _SyncFunction {
  /// Creates an [AndFunction].
  AndFunction();

  @override
  String get name => 'and';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.boolean;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'True when every value is true.',
    properties: {'values': Schema.list(items: Schema.any())},
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? values = args['values'];
    if (values is! List) return false;
    return values.every(_isTruthy);
  }
}

/// True when any value is truthy.
class OrFunction extends _SyncFunction {
  /// Creates an [OrFunction].
  OrFunction();

  @override
  String get name => 'or';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.boolean;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'True when at least one value is true.',
    properties: {'values': Schema.list(items: Schema.any())},
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? values = args['values'];
    if (values is! List) return false;
    return values.any(_isTruthy);
  }
}

/// Negates a value.
class NotFunction extends _SyncFunction {
  /// Creates a [NotFunction].
  NotFunction();

  @override
  String get name => 'not';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.boolean;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'Inverts a value.',
    properties: {'value': Schema.any()},
  );

  @override
  Object? call(Map<String, dynamic> args) => !_isTruthy(args['value']);
}

/// True when a value is present and not empty.
class RequiredFunction extends _SyncFunction {
  /// Creates a [RequiredFunction].
  RequiredFunction();

  @override
  String get name => 'required';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.boolean;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'True when the value is present and not empty.',
    properties: {'value': Schema.any()},
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? value = args['value'];
    return switch (value) {
      null => false,
      final String text => text.isNotEmpty,
      final List<Object?> list => list.isNotEmpty,
      final Map<Object?, Object?> map => map.isNotEmpty,
      _ => true,
    };
  }
}

/// True when a string matches a pattern.
class RegexFunction extends _SyncFunction {
  /// Creates a [RegexFunction].
  RegexFunction();

  @override
  String get name => 'regex';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.boolean;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'True when the value matches the regular expression.',
    properties: {'value': Schema.string(), 'pattern': Schema.string()},
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? value = args['value'];
    final Object? pattern = args['pattern'];
    if (value is! String || pattern is! String) return false;
    try {
      return RegExp(pattern).hasMatch(value);
    } on FormatException catch (error) {
      // The pattern came from the model. Treating a malformed one as a
      // failed match would block a form the user has filled in correctly.
      genUiLogger.warning('Invalid regex from model: $pattern', error);
      return true;
    }
  }
}

/// The length of a value, or whether it falls within bounds.
class LengthFunction extends _SyncFunction {
  /// Creates a [LengthFunction].
  LengthFunction();

  @override
  String get name => 'length';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.any;

  @override
  Schema get argumentSchema => Schema.object(
    description:
        'With min or max, whether the length is within them; otherwise the '
        'length itself.',
    properties: {
      'value': Schema.any(),
      'min': Schema.integer(),
      'max': Schema.integer(),
    },
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? value = args['value'];
    final int length = switch (value) {
      final String text => text.length,
      final List<Object?> list => list.length,
      final Map<Object?, Object?> map => map.length,
      _ => 0,
    };

    final Object? min = args['min'];
    final Object? max = args['max'];
    if (min == null && max == null) return length;
    if (min is num && length < min) return false;
    if (max is num && length > max) return false;
    return true;
  }
}

/// True when a value is a number, optionally within bounds.
class NumericFunction extends _SyncFunction {
  /// Creates a [NumericFunction].
  NumericFunction();

  @override
  String get name => 'numeric';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.boolean;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'True when the value is a number within min and max.',
    properties: {
      'value': Schema.any(),
      'min': Schema.number(),
      'max': Schema.number(),
    },
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? raw = args['value'];
    // A number that made a round trip through a text field arrives as a
    // string, and it is still a number as far as this check is concerned.
    final num? value = raw is num ? raw : num.tryParse('$raw');
    if (value == null) return false;

    final Object? min = args['min'];
    final Object? max = args['max'];
    if (min is num && value < min) return false;
    if (max is num && value > max) return false;
    return true;
  }
}

/// True when a value looks like an email address.
class EmailFunction extends _SyncFunction {
  /// Creates an [EmailFunction].
  EmailFunction();

  @override
  String get name => 'email';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.boolean;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'True when the value is a valid email address.',
    properties: {'value': Schema.string()},
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? value = args['value'];
    if (value is! String) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }
}

/// Formats a number for display.
class FormatNumberFunction extends _SyncFunction {
  /// Creates a [FormatNumberFunction].
  FormatNumberFunction();

  @override
  String get name => 'formatNumber';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.string;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'Formats a number with grouping and a decimal precision.',
    properties: {
      'value': Schema.number(),
      'decimalPlaces': Schema.integer(),
      'useGrouping': Schema.boolean(),
    },
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? value = args['value'];
    if (value is! num) return value?.toString() ?? '';

    final formatter = NumberFormat.decimalPattern();
    if (args['useGrouping'] == false) formatter.turnOffGrouping();
    final Object? places = args['decimalPlaces'];
    if (places is num) {
      formatter.minimumFractionDigits = places.toInt();
      formatter.maximumFractionDigits = places.toInt();
    }
    return formatter.format(value);
  }
}

/// Formats a number as an amount of money.
class FormatCurrencyFunction extends _SyncFunction {
  /// Creates a [FormatCurrencyFunction].
  FormatCurrencyFunction();

  @override
  String get name => 'formatCurrency';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.string;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'Formats a number as a currency amount.',
    properties: {'value': Schema.number(), 'currencyCode': Schema.string()},
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? value = args['value'];
    final Object? code = args['currencyCode'];
    if (value is! num) return value?.toString() ?? '';
    return NumberFormat.simpleCurrency(
      name: code is String ? code : null,
    ).format(value);
  }
}

/// Formats a date for display.
class FormatDateFunction extends _SyncFunction {
  /// Creates a [FormatDateFunction].
  FormatDateFunction();

  @override
  String get name => 'formatDate';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.string;

  @override
  Schema get argumentSchema => Schema.object(
    description:
        'Formats an ISO 8601 string or a millisecond timestamp using an '
        'ICU date pattern such as yMMMd.',
    properties: {'value': Schema.any(), 'pattern': Schema.string()},
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? value = args['value'];
    final DateTime? date = switch (value) {
      final String text => DateTime.tryParse(text),
      final int millis => DateTime.fromMillisecondsSinceEpoch(millis),
      _ => null,
    };
    final Object? pattern = args['pattern'];
    if (date == null || pattern is! String) return value?.toString() ?? '';

    try {
      return DateFormat(pattern).format(date);
    } catch (error) {
      genUiLogger.warning('Invalid date pattern from model: $pattern', error);
      return date.toIso8601String();
    }
  }
}

/// Chooses a wording based on a count.
class PluralizeFunction extends _SyncFunction {
  /// Creates a [PluralizeFunction].
  PluralizeFunction();

  @override
  String get name => 'pluralize';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.string;

  @override
  Schema get argumentSchema => Schema.object(
    description:
        'Picks the wording matching the plural category of the count. '
        'Provide at least "other".',
    properties: {
      'value': Schema.number(),
      'zero': Schema.string(),
      'one': Schema.string(),
      'two': Schema.string(),
      'few': Schema.string(),
      'many': Schema.string(),
      'other': Schema.string(),
    },
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? count = args['value'] ?? args['count'];
    if (count is! num) return '';
    return Intl.pluralLogic(
      count,
      zero: args['zero'] as String?,
      one: args['one'] as String?,
      two: args['two'] as String?,
      few: args['few'] as String?,
      many: args['many'] as String?,
      other: args['other'] as String? ?? '',
    );
  }
}

/// Opens a URL in a new tab.
class OpenUrlFunction extends _SyncFunction {
  /// Creates an [OpenUrlFunction].
  OpenUrlFunction();

  @override
  String get name => 'openUrl';

  @override
  core.A2uiReturnType get returnType => core.A2uiReturnType.void_;

  @override
  Schema get argumentSchema => Schema.object(
    description: 'Opens an http or https URL in a new tab.',
    properties: {'url': Schema.string()},
  );

  @override
  Object? call(Map<String, dynamic> args) {
    final Object? raw = args['url'];
    if (raw is! String) return null;
    final Uri? uri = Uri.tryParse(raw);
    // The URL comes from the model, so the scheme is checked here rather
    // than handed to the browser, which would honour `javascript:`.
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      genUiLogger.warning('Refusing to open URL: $raw');
      return null;
    }
    web.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
    return null;
  }
}
