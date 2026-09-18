import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

/// Builds a surface from A2UI messages, exactly as a model would send them.
({SurfaceController controller, core.SurfaceModel<CatalogItem> surface})
setUpSurface(
  List<Map<String, Object?>> components, {
  Map<String, Object?> data = const {},
}) {
  final controller = SurfaceController(catalogs: [basicCatalog()]);
  controller.handleMessage(
    core.A2uiMessage.fromJson({
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': 's1',
        'catalogId': basicCatalogId,
        'sendDataModel': true,
      },
    }),
  );
  data.forEach((String path, Object? value) {
    controller.handleMessage(
      core.A2uiMessage.fromJson({
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': 's1',
          'path': path,
          'value': value,
        },
      }),
    );
  });
  controller.handleMessage(
    core.A2uiMessage.fromJson({
      'version': 'v0.9',
      'updateComponents': {'surfaceId': 's1', 'components': components},
    }),
  );
  return (controller: controller, surface: controller.surface('s1')!);
}

void main() {
  group('SurfaceView', () {
    testComponents('renders nothing until a root component arrives', (
      tester,
    ) async {
      final controller = SurfaceController(catalogs: [basicCatalog()]);
      addTearDown(controller.dispose);
      controller.handleMessage(
        core.A2uiMessage.fromJson({
          'version': 'v0.9',
          'createSurface': {'surfaceId': 's1', 'catalogId': basicCatalogId},
        }),
      );

      tester.pumpComponent(
        SurfaceView(
          surface: controller.surface('s1')!,
          placeholder: Component.element(
            tag: 'p',
            children: [Component.text('waiting')],
          ),
        ),
      );

      expect(find.text('waiting'), findsOneComponent);
    });

    testComponents('renders a text component', (tester) async {
      final surface = setUpSurface([
        {'id': 'root', 'component': 'Text', 'text': 'Hello', 'variant': 'h2'},
      ]);
      addTearDown(surface.controller.dispose);

      tester.pumpComponent(SurfaceView(surface: surface.surface));

      expect(find.text('Hello'), findsOneComponent);
      expect(find.tag('h2'), findsOneComponent);
    });

    testComponents('renders a tree of children', (tester) async {
      final surface = setUpSurface([
        {'id': 'root', 'component': 'Column', 'children': ['a', 'b']},
        {'id': 'a', 'component': 'Text', 'text': 'first'},
        {'id': 'b', 'component': 'Text', 'text': 'second'},
      ]);
      addTearDown(surface.controller.dispose);

      tester.pumpComponent(SurfaceView(surface: surface.surface));

      expect(find.text('first'), findsOneComponent);
      expect(find.text('second'), findsOneComponent);
    });

    testComponents('renders a bound value from the data model', (tester) async {
      final surface = setUpSurface(
        [
          {
            'id': 'root',
            'component': 'Text',
            'text': {'path': '/user/name'},
          },
        ],
        data: {
          '/user': {'name': 'Ada'},
        },
      );
      addTearDown(surface.controller.dispose);

      tester.pumpComponent(SurfaceView(surface: surface.surface));

      expect(find.text('Ada'), findsOneComponent);
    });

    testComponents('renders one child per item of a templated list', (
      tester,
    ) async {
      final surface = setUpSurface(
        [
          {
            'id': 'root',
            'component': 'Column',
            'children': {'componentId': 'item', 'path': '/cities'},
          },
          {
            'id': 'item',
            'component': 'Text',
            'text': {'path': 'name'},
          },
        ],
        data: {
          '/cities': [
            {'name': 'Lisbon'},
            {'name': 'Porto'},
          ],
        },
      );
      addTearDown(surface.controller.dispose);

      tester.pumpComponent(SurfaceView(surface: surface.surface));

      expect(find.text('Lisbon'), findsOneComponent);
      expect(find.text('Porto'), findsOneComponent);
    });

    testComponents('renders a component that is not in the catalog as an '
        'error, leaving its siblings alone', (tester) async {
      // A model will occasionally invent a component. That should cost the
      // component, not the surface it is in.
      final surface = setUpSurface([
        {'id': 'root', 'component': 'Column', 'children': ['good', 'bad']},
        {'id': 'good', 'component': 'Text', 'text': 'still here'},
        {'id': 'bad', 'component': 'Carousel', 'items': <Object?>[]},
      ]);
      addTearDown(surface.controller.dispose);

      tester.pumpComponent(SurfaceView(surface: surface.surface));

      expect(find.text('still here'), findsOneComponent);
      expect(find.byType(FallbackView), findsOneComponent);
    });

    testComponents('renders a child reference that points nowhere as an error',
        (tester) async {
      final surface = setUpSurface([
        {'id': 'root', 'component': 'Column', 'children': ['missing']},
      ]);
      addTearDown(surface.controller.dispose);

      tester.pumpComponent(SurfaceView(surface: surface.surface));

      expect(find.byType(FallbackView), findsOneComponent);
    });
  });

  group('interaction', () {
    testComponents('pressing a button dispatches its action', (tester) async {
      final surface = setUpSurface([
        {
          'id': 'root',
          'component': 'Button',
          'child': 'label',
          'action': {
            'event': {
              'name': 'book',
              'context': {'city': 'Lisbon'},
            },
          },
        },
        {'id': 'label', 'component': 'Text', 'text': 'Book it'},
      ]);
      addTearDown(surface.controller.dispose);

      final Future<UiActionEvent> action = surface.controller.actions.first;
      tester.pumpComponent(SurfaceView(surface: surface.surface));
      await tester.click(find.tag('button'));

      final UiActionEvent event = await action;
      expect(event.action.name, 'book');
      expect(event.action.context, {'city': 'Lisbon'});
    });

    testComponents('a button whose checks fail is disabled', (tester) async {
      final surface = setUpSurface(
        [
          {
            'id': 'root',
            'component': 'Button',
            'child': 'label',
            'action': {
              'event': {'name': 'submit'},
            },
            'checks': [
              {
                'condition': {
                  'call': 'required',
                  'args': {
                    'value': {'path': '/form/email'},
                  },
                },
                'message': 'Email is required.',
              },
            ],
          },
          {'id': 'label', 'component': 'Text', 'text': 'Submit'},
        ],
        data: {
          '/form': {'email': ''},
        },
      );
      addTearDown(surface.controller.dispose);

      var fired = false;
      final sub = surface.controller.actions.listen((_) => fired = true);
      addTearDown(sub.cancel);

      tester.pumpComponent(SurfaceView(surface: surface.surface));
      expect(find.text('Email is required.'), findsOneComponent);

      // The point of disabling it is that pressing it sends nothing: an
      // incomplete form should not reach the model.
      await tester.click(find.tag('button'));
      expect(fired, isFalse);
    });

    testComponents('a bound value reaching the data model re-renders what '
        'reads it', (tester) async {
      // This is the loop the whole renderer exists for: a component writes
      // to the data model, and everything bound to that path follows.
      final surface = setUpSurface(
        [
          {'id': 'root', 'component': 'Column', 'children': ['field', 'echo']},
          {
            'id': 'field',
            'component': 'TextField',
            'label': 'Name',
            'value': {'path': '/name'},
          },
          {
            'id': 'echo',
            'component': 'Text',
            'text': {'path': '/name'},
          },
        ],
        data: {'/name': 'Ada'},
      );
      addTearDown(surface.controller.dispose);

      tester.pumpComponent(SurfaceView(surface: surface.surface));
      expect(find.text('Ada'), findsOneComponent);

      surface.surface.dataModel.set('/name', 'Grace');
      await tester.pump();

      expect(find.text('Grace'), findsOneComponent);
      expect(find.text('Ada'), findsNothing);
    });
  });
}
