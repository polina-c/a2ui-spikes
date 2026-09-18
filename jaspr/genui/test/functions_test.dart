import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:test/test.dart';

Object? call(String name, Map<String, dynamic> args) {
  final WebCatalog catalog = basicCatalog();
  final core.FunctionImplementation fn = catalog.functions[name]!;
  return fn.execute(
    args,
    core.DataContext(core.DataModel(), catalog.invoke, '/'),
  );
}

void main() {
  group('validation functions', () {
    test('required rejects empty values', () {
      expect(call('required', {'value': 'abc'}), isTrue);
      expect(call('required', {'value': ''}), isFalse);
      expect(call('required', {'value': null}), isFalse);
      expect(call('required', {'value': <Object?>[]}), isFalse);
      expect(call('required', {'value': false}), isTrue);
    });

    test('regex matches a pattern', () {
      expect(call('regex', {'value': 'a1', 'pattern': r'^[a-z]\d$'}), isTrue);
      expect(call('regex', {'value': 'ab', 'pattern': r'^[a-z]\d$'}), isFalse);
    });

    test('regex treats a pattern it cannot compile as satisfied', () {
      // The pattern comes from the model. Failing closed would block a form
      // the user filled in correctly.
      expect(call('regex', {'value': 'x', 'pattern': '([unclosed'}), isTrue);
    });

    test('length reports a length, or checks bounds', () {
      expect(call('length', {'value': 'abcd'}), 4);
      expect(call('length', {'value': 'abcd', 'min': 2}), isTrue);
      expect(call('length', {'value': 'abcd', 'max': 3}), isFalse);
    });

    test('numeric accepts a number that came back as a string', () {
      expect(call('numeric', {'value': 5}), isTrue);
      expect(call('numeric', {'value': '5'}), isTrue);
      expect(call('numeric', {'value': 'five'}), isFalse);
      expect(call('numeric', {'value': 5, 'min': 6}), isFalse);
      expect(call('numeric', {'value': 5, 'max': 6}), isTrue);
    });

    test('email checks the shape of an address', () {
      expect(call('email', {'value': 'a@b.co'}), isTrue);
      expect(call('email', {'value': 'a@b'}), isFalse);
      expect(call('email', {'value': 'a b@c.co'}), isFalse);
    });

    test('and, or and not combine conditions', () {
      expect(call('and', {'values': [true, true]}), isTrue);
      expect(call('and', {'values': [true, false]}), isFalse);
      expect(call('or', {'values': [false, true]}), isTrue);
      expect(call('or', {'values': [false, false]}), isFalse);
      expect(call('not', {'value': false}), isTrue);
      expect(call('not', {'value': null}), isTrue);
    });
  });

  group('formatting functions', () {
    test('formatNumber honours decimal places and grouping', () {
      expect(call('formatNumber', {'value': 1234.5, 'decimalPlaces': 1}),
          '1,234.5');
      expect(
        call('formatNumber', {'value': 1234, 'useGrouping': false}),
        '1234',
      );
    });

    test('formatCurrency renders an amount', () {
      expect(
        call('formatCurrency', {'value': 12.5, 'currencyCode': 'USD'}),
        contains('12.50'),
      );
    });

    test('formatDate applies an ICU pattern', () {
      expect(
        call('formatDate', {'value': '2026-03-04', 'pattern': 'yyyy-MM-dd'}),
        '2026-03-04',
      );
    });

    test('formatDate falls back when the pattern is not one', () {
      expect(
        call('formatDate', {'value': '2026-03-04', 'pattern': '@@@@@@'}),
        isNotEmpty,
      );
    });

    test('pluralize picks a wording for the count', () {
      const Map<String, dynamic> args = {'one': 'item', 'other': 'items'};
      expect(call('pluralize', {...args, 'value': 1}), 'item');
      expect(call('pluralize', {...args, 'value': 3}), 'items');
    });

    test('formatString interpolates from the data model', () {
      final WebCatalog catalog = basicCatalog();
      final model = core.DataModel({'name': 'Ada'});
      final Object? result = catalog.functions['formatString']!.execute(
        {'value': r'Hi ${/name}'},
        core.DataContext(model, catalog.invoke, '/'),
      );
      final Object? value =
          result is core.ReadonlySignal ? result.value : result;
      expect(value, 'Hi Ada');
    });
  });
}
