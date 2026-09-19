// The renderer walks the tree that a2ui_core builds from the model's messages.
// These tests pin the shape the prompt promises the model, so a change in
// a2ui_core that breaks that shape shows up here rather than as a blank surface.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:test/test.dart';

/// The three messages the prompt tells the model to send, for one question.
List<A2uiMessage> questionMessages(String surfaceId, String catalogId) => [
  A2uiMessage.fromJson({
    'version': 'v0.9',
    'createSurface': {'surfaceId': surfaceId, 'catalogId': catalogId},
  }),
  A2uiMessage.fromJson({
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': surfaceId,
      'components': [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['title', 'pick_eco'],
        },
        {
          'id': 'title',
          'component': 'Text',
          'text': {'path': '/title'},
          'variant': 'h2',
        },
        {
          'id': 'pick_eco',
          'component': 'Button',
          'variant': 'primary',
          'child': 'pick_eco_label',
          'action': {
            'event': {
              'name': 'openLandingPage',
              'context': {'url': 'https://example.com/eco'},
            },
          },
        },
        {'id': 'pick_eco_label', 'component': 'Text', 'text': 'View the Eco'},
      ],
    },
  }),
  A2uiMessage.fromJson({
    'version': 'v0.9',
    'updateDataModel': {
      'surfaceId': surfaceId,
      'path': '/',
      'value': {'title': 'Where will it go?'},
    },
  }),
];

void main() {
  late MessageProcessor<ComponentApi> processor;
  late Catalog<ComponentApi> catalog;

  setUp(() {
    catalog = MinimalCatalog();
    processor = MessageProcessor(catalogs: [catalog]);
  });

  test('the three messages produce a surface with a root component', () {
    processor.processMessages(questionMessages('turn-0', catalog.id));

    final surface = processor.groupModel.getSurface('turn-0');
    expect(surface, isNotNull);
    expect(surface!.componentsModel.get('root')?.type, 'Column');
    expect(surface.componentsModel.get('pick_eco')?.type, 'Button');
  });

  test('a bound property reads through to the data model', () {
    processor.processMessages(questionMessages('turn-0', catalog.id));
    final surface = processor.groupModel.getSurface('turn-0')!;

    final binding = surface.componentsModel.get('title')!.properties['text'];
    expect(binding, isA<Map>());
    expect(surface.dataModel.get((binding as Map)['path'] as String),
        'Where will it go?');
  });

  test('pressing a button reports the action with its context', () async {
    final actions = <A2uiClientAction>[];
    processor = MessageProcessor(catalogs: [catalog], onAction: actions.add);
    processor.processMessages(questionMessages('turn-0', catalog.id));

    final surface = processor.groupModel.getSurface('turn-0')!;
    final model = surface.componentsModel.get('pick_eco')!;
    await surface.dispatchAction(
      model.properties['action'] as Map<String, dynamic>,
      model.id,
    );

    expect(actions, hasLength(1));
    expect(actions.single.name, 'openLandingPage');
    expect(actions.single.sourceComponentId, 'pick_eco');
    expect(actions.single.context['url'], 'https://example.com/eco');
  });
}
