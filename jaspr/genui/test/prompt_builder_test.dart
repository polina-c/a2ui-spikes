import 'package:genui/genui.dart';
import 'package:test/test.dart';

void main() {
  group('PromptBuilder', () {
    test('names the catalog the model must build from', () {
      final String prompt = PromptBuilder.chat(
        catalog: basicCatalog(),
      ).systemPromptJoined();

      expect(prompt, contains(basicCatalogId));
      expect(prompt, contains('createSurface'));
      expect(prompt, contains('updateComponents'));
      expect(prompt, contains('"root"'));
    });

    test('describes every component the catalog offers', () {
      final WebCatalog catalog = basicCatalog();
      final String prompt = PromptBuilder.chat(
        catalog: catalog,
      ).systemPromptJoined();

      for (final String name in catalog.components.keys) {
        expect(prompt, contains('"$name"'), reason: '$name is missing');
      }
    });

    test('does not offer a component the catalog dropped', () {
      final String prompt = PromptBuilder.chat(
        catalog: basicCatalogWithoutAssets(),
      ).systemPromptJoined();

      expect(prompt, isNot(contains('"Image"')));
    });

    test('a chat prompt forbids editing an earlier surface', () {
      // A chat transcript scrolls, so editing a surface would rewrite a
      // message the user has already read.
      expect(
        PromptBuilder.chat(catalog: basicCatalog()).systemPromptJoined(),
        contains('Never modify a surface you sent earlier'),
      );
    });

    test('a custom prompt can allow edits and deletes', () {
      final String prompt = PromptBuilder.custom(
        catalog: basicCatalog(),
        allowUpdates: true,
        allowDeletes: true,
      ).systemPromptJoined();

      expect(prompt, contains('To change a surface you already sent'));
      expect(prompt, contains('deleteSurface'));
      expect(prompt, isNot(contains('Never modify a surface')));
    });

    test('compact leaves out the protocol schemas, full includes them', () {
      final WebCatalog catalog = basicCatalog();
      final String compact = PromptBuilder.chat(
        catalog: catalog,
      ).systemPromptJoined();
      final String full = PromptBuilder.chat(
        catalog: catalog,
        detail: PromptDetail.full,
      ).systemPromptJoined();

      expect(compact, isNot(contains('MESSAGE_SCHEMA_START')));
      expect(compact, contains('VALUE_TYPES_START'));
      expect(full, contains('MESSAGE_SCHEMA_START'));
      expect(full, contains('COMMON_TYPES_START'));
      // The knob has to be worth having: a browser-sized model has a
      // context window the full schemas would take most of.
      expect(full.length, greaterThan(compact.length * 4));
    });

    test('compact names the shared value types and explains them once', () {
      final String prompt = PromptBuilder.chat(
        catalog: basicCatalog(),
      ).systemPromptJoined();

      // Spelled out per property, these are most of what made the prompt
      // too long for a model that runs in a browser tab.
      expect(prompt, contains('DynamicString'));
      expect(prompt, contains('ComponentId'));
      expect(prompt, contains('ChildList'));
      expect('DynamicString'.allMatches(prompt).length, greaterThan(5));
      expect(prompt, isNot(contains('REF:')));
      // A list whose entries are this component's own still shows them.
      expect(prompt, contains('The value recorded when this option is chosen'));
    });

    test('carries the fragments an app adds', () {
      final String prompt = PromptBuilder.chat(
        catalog: basicCatalog(),
        systemPromptFragments: const ['You are a travel agent.'],
      ).systemPromptJoined();

      expect(prompt, contains('You are a travel agent.'));
    });

    test('carries the rules a custom catalog adds', () {
      final WebCatalog catalog = basicCatalog().withItems(
        const [],
        newSystemPromptFragments: const ['Prefer the Booking component.'],
      );

      expect(
        PromptBuilder.chat(catalog: catalog).systemPromptJoined(),
        contains('Prefer the Booking component.'),
      );
    });
  });
}
