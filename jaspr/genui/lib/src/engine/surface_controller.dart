import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;

import '../catalog/catalog_item.dart';
import '../primitives/logging.dart';

/// Something that happened to the set of surfaces.
sealed class SurfaceUpdate {
  const SurfaceUpdate(this.surfaceId);

  /// The surface this is about.
  final String surfaceId;
}

/// A surface was created. It has no components yet.
final class SurfaceAdded extends SurfaceUpdate {
  /// Creates a [SurfaceAdded].
  const SurfaceAdded(super.surfaceId);
}

/// A surface was deleted.
final class SurfaceRemoved extends SurfaceUpdate {
  /// Creates a [SurfaceRemoved].
  const SurfaceRemoved(super.surfaceId);
}

/// Something a user did to a generated UI, on its way back to the model.
final class UiActionEvent {
  /// Creates a [UiActionEvent].
  const UiActionEvent({required this.action, required this.dataModel});

  /// The action the component dispatched.
  final core.A2uiClientAction action;

  /// The data model of the surface the action came from, when that surface
  /// asked for it to be sent.
  ///
  /// This is what carries the user's answers back: the action says which
  /// button was pressed, and this says what was in the form when it was.
  final Map<String, Object?>? dataModel;

  /// A description of this action for the model, as JSON.
  Map<String, Object?> toJson() => {
    'uiAction': action.toJson(),
    'dataModel': ?dataModel,
  };
}

/// Owns the surfaces of a session.
///
/// A2UI messages go in through [handleMessage] and surfaces come out: the
/// controller creates, fills and deletes them, and reports what the user
/// does with them on [actions]. It is the piece an app holds onto; the
/// components it renders are [core.SurfaceModel]s fetched with [surface].
class SurfaceController {
  /// Creates a [SurfaceController] that can build surfaces from [catalogs].
  SurfaceController({required List<WebCatalog> catalogs})
    : assert(catalogs.isNotEmpty, 'At least one catalog is required.'),
      _catalogs = catalogs {
    _processor = core.MessageProcessor<CatalogItem>(
      catalogs: catalogs,
      onAction: _onAction,
    );
    _processor.groupModel.onSurfaceCreated.addListener(_onSurfaceCreated);
    _processor.groupModel.onSurfaceDeleted.addListener(_onSurfaceDeleted);
  }

  final List<WebCatalog> _catalogs;
  late final core.MessageProcessor<CatalogItem> _processor;

  final StreamController<SurfaceUpdate> _updates =
      StreamController<SurfaceUpdate>.broadcast();
  final StreamController<UiActionEvent> _actions =
      StreamController<UiActionEvent>.broadcast();
  final StreamController<Object> _errors =
      StreamController<Object>.broadcast();

  /// The catalogs surfaces can be built from.
  List<WebCatalog> get catalogs => List.unmodifiable(_catalogs);

  /// Surfaces appearing and disappearing.
  Stream<SurfaceUpdate> get surfaceUpdates => _updates.stream;

  /// What users do to generated UIs.
  ///
  /// In a chat app, each of these becomes the next turn of the conversation.
  Stream<UiActionEvent> get actions => _actions.stream;

  /// Errors from messages that could not be applied.
  ///
  /// A malformed message is reported here rather than thrown, because it
  /// arrives mid-stream from a model and should cost that message only.
  Stream<Object> get errors => _errors.stream;

  /// The surface with this ID, or `null` if there is none.
  core.SurfaceModel<CatalogItem>? surface(String surfaceId) =>
      _processor.groupModel.getSurface(surfaceId);

  /// Every live surface.
  Iterable<core.SurfaceModel<CatalogItem>> get surfaces =>
      _processor.groupModel.allSurfaces;

  /// Applies one A2UI message.
  void handleMessage(core.A2uiMessage message) {
    try {
      _processor.processMessages([message]);
    } catch (error, stackTrace) {
      genUiLogger.severe('Could not apply A2UI message', error, stackTrace);
      if (!_errors.isClosed) _errors.add(error);
    }
  }

  /// What this client can render, for the model to be told about.
  Map<String, dynamic> clientCapabilities({bool includeInlineCatalogs = false}) =>
      _processor.getClientCapabilities(
        includeInlineCatalogs: includeInlineCatalogs,
      );

  void _onSurfaceCreated(core.SurfaceModel<CatalogItem> surface) {
    genUiLogger.fine('Surface created: ${surface.id}');
    if (!_updates.isClosed) _updates.add(SurfaceAdded(surface.id));
  }

  void _onSurfaceDeleted(String surfaceId) {
    genUiLogger.fine('Surface deleted: $surfaceId');
    if (!_updates.isClosed) _updates.add(SurfaceRemoved(surfaceId));
  }

  void _onAction(core.A2uiClientAction action) {
    final core.SurfaceModel<CatalogItem>? source = surface(action.surfaceId);
    final Object? data = source != null && source.sendDataModel
        ? source.dataModel.get('/')
        : null;
    genUiLogger.info('UI action "${action.name}" on ${action.surfaceId}');
    if (_actions.isClosed) return;
    _actions.add(
      UiActionEvent(
        action: action,
        dataModel: data is Map<String, Object?> ? data : null,
      ),
    );
  }

  /// Releases every surface and closes the streams.
  void dispose() {
    _processor.groupModel.onSurfaceCreated.removeListener(_onSurfaceCreated);
    _processor.groupModel.onSurfaceDeleted.removeListener(_onSurfaceDeleted);
    _processor.groupModel.dispose();
    _updates.close();
    _actions.close();
    _errors.close();
  }
}
