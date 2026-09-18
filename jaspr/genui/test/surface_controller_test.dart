import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:test/test.dart';

core.A2uiMessage message(Map<String, Object?> json) =>
    core.A2uiMessage.fromJson(json);

Map<String, Object?> createSurface(String id, {bool sendDataModel = true}) => {
  'version': 'v0.9',
  'createSurface': {
    'surfaceId': id,
    'catalogId': basicCatalogId,
    'sendDataModel': sendDataModel,
  },
};

void main() {
  late SurfaceController controller;

  setUp(() => controller = SurfaceController(catalogs: [basicCatalog()]));
  tearDown(() => controller.dispose());

  test('createSurface opens an empty surface', () async {
    final Future<SurfaceUpdate> update = controller.surfaceUpdates.first;
    controller.handleMessage(message(createSurface('s1')));

    expect(await update, isA<SurfaceAdded>());
    expect(controller.surface('s1'), isNotNull);
    expect(controller.surface('s1')!.componentsModel.all, isEmpty);
  });

  test('updateComponents fills the surface', () {
    controller.handleMessage(message(createSurface('s1')));
    controller.handleMessage(
      message({
        'version': 'v0.9',
        'updateComponents': {
          'surfaceId': 's1',
          'components': [
            {'id': 'root', 'component': 'Text', 'text': 'hello'},
          ],
        },
      }),
    );

    final core.ComponentModel? root =
        controller.surface('s1')!.componentsModel.get('root');
    expect(root, isNotNull);
    expect(root!.type, 'Text');
    expect(root.properties['text'], 'hello');
  });

  test('updateDataModel sets a value components can bind to', () {
    controller.handleMessage(message(createSurface('s1')));
    controller.handleMessage(
      message({
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': 's1',
          'path': '/form/email',
          'value': 'a@b.co',
        },
      }),
    );

    expect(controller.surface('s1')!.dataModel.get('/form/email'), 'a@b.co');
  });

  test('deleteSurface removes it', () async {
    controller.handleMessage(message(createSurface('s1')));
    final Future<SurfaceUpdate> removal =
        controller.surfaceUpdates.firstWhere((u) => u is SurfaceRemoved);

    controller.handleMessage(
      message({
        'version': 'v0.9',
        'deleteSurface': {'surfaceId': 's1'},
      }),
    );

    expect(await removal, isA<SurfaceRemoved>());
    expect(controller.surface('s1'), isNull);
  });

  test('a message for a surface that does not exist is reported, not thrown',
      () async {
    // Messages arrive mid-stream from a model, so one bad message must not
    // take down the session.
    final Future<Object> error = controller.errors.first;
    controller.handleMessage(
      message({
        'version': 'v0.9',
        'updateComponents': {'surfaceId': 'missing', 'components': []},
      }),
    );

    expect(await error, isA<core.A2uiStateError>());
  });

  test('an action carries the data model back', () async {
    controller.handleMessage(message(createSurface('s1')));
    controller.handleMessage(
      message({
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': 's1',
          'path': '/name',
          'value': 'Ada',
        },
      }),
    );

    final Future<UiActionEvent> action = controller.actions.first;
    await controller.surface('s1')!.dispatchAction({
      'event': {
        'name': 'submit',
        'context': {'from': 'test'},
      },
    }, 'go');

    final UiActionEvent event = await action;
    expect(event.action.name, 'submit');
    expect(event.action.sourceComponentId, 'go');
    expect(event.action.context, {'from': 'test'});
    expect(event.dataModel, {'name': 'Ada'});
  });

  test('a surface that did not ask for its data model does not send it',
      () async {
    controller.handleMessage(
      message(createSurface('s1', sendDataModel: false)),
    );
    controller.handleMessage(
      message({
        'version': 'v0.9',
        'updateDataModel': {'surfaceId': 's1', 'path': '/secret', 'value': 1},
      }),
    );

    final Future<UiActionEvent> action = controller.actions.first;
    await controller.surface('s1')!.dispatchAction({
      'event': {'name': 'submit'},
    }, 'go');

    expect((await action).dataModel, isNull);
  });

  test('capabilities name the catalogs this client can render', () {
    final Map<String, dynamic> capabilities = controller.clientCapabilities();
    expect(
      (capabilities['v0.9'] as Map<String, dynamic>)['supportedCatalogIds'],
      [basicCatalogId],
    );
  });
}
