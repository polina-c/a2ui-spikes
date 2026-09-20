import 'package:a2ui_core/a2ui_core.dart';
import 'package:simple_chat_jaspr/a2ui/catalog.dart';
import 'package:test/test.dart';

/// The renderer itself needs a browser, but the protocol layer under it does
/// not: these check that the messages this app's catalog accepts arrive as the
/// tree the renderer walks.
void main() {
  late MessageProcessor<ComponentApi> processor;
  late Catalog<ComponentApi> catalog;

  setUp(() {
    catalog = appCatalog();
    processor = MessageProcessor<ComponentApi>(catalogs: [catalog]);
  });

  List<A2uiMessage> messagesFor(List<Map<String, dynamic>> components) => [
    A2uiMessage.fromJson({
      'version': 'v0.9',
      'createSurface': {'surfaceId': 's1', 'catalogId': catalog.id},
    }),
    A2uiMessage.fromJson({
      'version': 'v0.9',
      'updateComponents': {'surfaceId': 's1', 'components': components},
    }),
  ];

  test('a card holding a question and its answers arrives whole', () {
    processor.processMessages([
      ...messagesFor([
        {'id': 'root', 'component': 'Card', 'child': 'body'},
        {
          'id': 'body',
          'component': 'Column',
          'children': ['question', 'answer'],
        },
        {
          'id': 'question',
          'component': 'Text',
          'text': {'path': '/question'},
        },
        {
          'id': 'answer',
          'component': 'Button',
          'child': 'answerLabel',
          'action': {
            'event': {
              'name': 'answer',
              'context': {'value': '60 cm'},
            },
          },
        },
        {'id': 'answerLabel', 'component': 'Text', 'text': '60 cm gap'},
      ]),
      A2uiMessage.fromJson({
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': 's1',
          'path': '/',
          'value': {'question': 'How wide is the gap?'},
        },
      }),
    ]);

    final surface = processor.groupModel.getSurface('s1')!;
    expect(surface.componentsModel.get('root')!.type, 'Card');
    // The renderer resolves this binding; here it is the data behind it.
    expect(surface.dataModel.get('/question'), 'How wide is the gap?');
    expect(surface.componentsModel.get('answer')!.properties['action'], isMap);
  });

  test('the catalog offers Card, which a2ui_core does not', () {
    expect(catalog.components.keys, contains('Card'));
    expect(MinimalCatalog().components.keys, isNot(contains('Card')));
  });

  test('a press on a generated button is dispatched as an action', () async {
    A2uiClientAction? seen;
    final actionProcessor = MessageProcessor<ComponentApi>(
      catalogs: [catalog],
      onAction: (action) => seen = action,
    );
    actionProcessor.processMessages(
      messagesFor([
        {
          'id': 'root',
          'component': 'Button',
          'child': 'label',
          'action': {
            'event': {
              'name': 'openLandingPage',
              'context': {'model': 'eco'},
            },
          },
        },
        {'id': 'label', 'component': 'Text', 'text': 'See the Eco'},
      ]),
    );

    final surface = actionProcessor.groupModel.getSurface('s1')!;
    final root = surface.componentsModel.get('root')!;
    await surface.dispatchAction(
      root.properties['action'] as Map<String, dynamic>,
      root.id,
    );

    expect(seen, isNotNull);
    expect(seen!.name, 'openLandingPage');
    expect(seen!.context['model'], 'eco');
  });
}
