import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:jaspr/jaspr.dart';

import '../catalog/catalog_item.dart';
import '../primitives/logging.dart';
import 'fallback.dart';

/// Renders an A2UI surface.
///
/// A surface arrives in pieces: `createSurface` opens an empty one and each
/// `updateComponents` fills or replaces part of it, so this rebuilds as
/// components appear and renders nothing until one of them is `root`.
class SurfaceView extends StatefulComponent {
  /// Creates a [SurfaceView] for [surface].
  const SurfaceView({
    required this.surface,
    this.placeholder,
    this.onError,
    super.key,
  });

  /// The live surface to render.
  final core.SurfaceModel<CatalogItem> surface;

  /// What to show before the surface has a `root` component.
  final Component? placeholder;

  /// Called for errors raised while rendering.
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<SurfaceView> createState() => _SurfaceViewState();
}

class _SurfaceViewState extends State<SurfaceView> {
  @override
  void initState() {
    super.initState();
    _listen(component.surface);
  }

  @override
  void didUpdateComponent(SurfaceView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.surface != component.surface) {
      _unlisten(oldComponent.surface);
      _listen(component.surface);
    }
  }

  void _listen(core.SurfaceModel<CatalogItem> surface) {
    surface.componentsModel.onCreated.addListener(_onComponentCreated);
    surface.componentsModel.onDeleted.addListener(_onComponentDeleted);
  }

  void _unlisten(core.SurfaceModel<CatalogItem> surface) {
    surface.componentsModel.onCreated.removeListener(_onComponentCreated);
    surface.componentsModel.onDeleted.removeListener(_onComponentDeleted);
  }

  // Only the arrival or removal of a component changes what this level
  // renders. Property changes within a component are handled by that
  // component's own binder, which is the whole point of binding per
  // component rather than re-rendering the surface on every token.
  void _onComponentCreated(core.ComponentModel _) => setState(() {});
  void _onComponentDeleted(String _) => setState(() {});

  @override
  void dispose() {
    _unlisten(component.surface);
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final core.SurfaceModel<CatalogItem> surface = component.surface;
    if (surface.componentsModel.get('root') == null) {
      genUiLogger.fine('Surface ${surface.id} has no root component yet.');
      return component.placeholder ?? Component.empty();
    }
    return ComponentView(
      surface: surface,
      componentId: 'root',
      basePath: '/',
      onError: component.onError,
    );
  }
}

/// Renders one component of a surface, and its children.
///
/// Each instance owns a [core.GenericBinder], which resolves the component's
/// protocol JSON against the data model and re-emits whenever a value the
/// component reads changes. Binding at this granularity is what keeps a data
/// model update from re-rendering the whole surface.
class ComponentView extends StatefulComponent {
  /// Creates a [ComponentView].
  const ComponentView({
    required this.surface,
    required this.componentId,
    required this.basePath,
    this.onError,
    super.key,
  });

  /// The surface this component belongs to.
  final core.SurfaceModel<CatalogItem> surface;

  /// The ID of the component to render.
  final String componentId;

  /// The data model path this component resolves relative paths against.
  ///
  /// Children of a templated list each get their own, which is how one
  /// component definition renders once per item.
  final String basePath;

  /// Called for errors raised while rendering.
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<ComponentView> createState() => _ComponentViewState();
}

class _ComponentViewState extends State<ComponentView> {
  core.ComponentContext? _context;
  core.GenericBinder? _binder;
  void Function()? _unsubscribe;
  Object? _bindError;

  // preact_signals calls a new subscriber immediately. That first call
  // happens inside initState, where setState is not allowed and is not
  // needed, since the value it carries is the one the coming build reads.
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateComponent(ComponentView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.surface != component.surface ||
        oldComponent.componentId != component.componentId ||
        oldComponent.basePath != component.basePath) {
      _unbind();
      _bind();
    }
  }

  void _bind() {
    _bindError = null;
    try {
      final core.ComponentModel? model = component.surface.componentsModel.get(
        component.componentId,
      );
      if (model == null) {
        throw StateError('Component "${component.componentId}" not found.');
      }
      final CatalogItem? item = component.surface.catalog.components[model.type];
      if (item == null) {
        throw StateError(
          'Component type "${model.type}" is not in catalog '
          '"${component.surface.catalog.id}".',
        );
      }

      final context = core.ComponentContext(
        component.surface,
        model,
        basePath: component.basePath,
      );
      final binder = core.GenericBinder(context, item.schema);
      _context = context;
      _binder = binder;
      _subscribed = false;
      _unsubscribe = binder.resolvedProps.subscribe((_) {
        if (!_subscribed) return;
        setState(() {});
      });
      _subscribed = true;
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
      _bindError = error;
    }
  }

  void _unbind() {
    _unsubscribe?.call();
    _unsubscribe = null;
    _binder?.dispose();
    _binder = null;
    _context = null;
  }

  void _reportError(Object error, StackTrace stackTrace) {
    genUiLogger.severe(
      'Error rendering component ${component.componentId}',
      error,
      stackTrace,
    );
    component.onError?.call(error, stackTrace);
    component.surface.dispatchError(
      core.A2uiClientError(
        code: 'RENDER_ERROR',
        surfaceId: component.surface.id,
        message: '$error',
        details: {'componentId': component.componentId},
      ),
    );
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final Object? bindError = _bindError;
    if (bindError != null) return FallbackView(error: bindError);

    final core.GenericBinder binder = _binder!;
    final core.ComponentContext componentContext = _context!;
    final core.ComponentModel model = componentContext.componentModel;
    final CatalogItem item = component.surface.catalog.components[model.type]!;

    try {
      return item.builder(
        A2uiBuildContext(
          id: model.id,
          type: model.type,
          properties: binder.resolvedProps.value,
          componentContext: componentContext,
          surfaceId: component.surface.id,
          buildChild: _buildChild,
          reportError: _reportError,
        ),
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return FallbackView(error: error);
    }
  }

  Component _buildChild(Object? child) {
    final (String id, String basePath) = switch (child) {
      core.ChildNode node => (node.id, node.basePath),
      String id => (id, component.basePath),
      _ => ('', ''),
    };
    if (id.isEmpty) {
      return FallbackView(
        error: StateError('Not a child reference: ${child.runtimeType}'),
      );
    }
    return ComponentView(
      // A templated list renders the same component definition once per
      // item, so the ID alone does not identify an instance; without the
      // path in the key, reordering the list would leave each rendered row
      // bound to its old slice of the data model.
      key: ValueKey<String>('$id@$basePath'),
      surface: component.surface,
      componentId: id,
      basePath: basePath,
      onError: component.onError,
    );
  }
}
