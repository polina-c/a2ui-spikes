// An A2UI renderer for Jaspr.
//
// a2ui has no Jaspr renderer. What it has is `a2ui_core`: plain Dart that does
// the protocol work - parsing messages, holding the component tree and the data
// model, resolving `{path: ...}` bindings and dispatching actions. The step it
// leaves to the host is turning a component tree into a framework's views, and
// that is what this file is.
//
// It covers the minimal catalog `a2ui_core` ships (Text, Row, Column, Button,
// TextField) plus Card, which the model reaches for constantly. Anything else
// is drawn as a visible placeholder instead of being skipped, so a model that
// asks for a component this app does not have shows up on screen rather than
// rendering nothing.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders one A2UI surface, and redraws it when its model changes.
class A2uiSurface extends StatefulComponent {
  const A2uiSurface({required this.surface, super.key});

  final SurfaceModel<ComponentApi> surface;

  @override
  State<A2uiSurface> createState() => _A2uiSurfaceState();
}

class _A2uiSurfaceState extends State<A2uiSurface> {
  // The data model hands out one signal per path and holds them weakly, so
  // this field is what keeps the root subscription from being collected.
  ReadonlySignal<Object?>? _root;
  void Function()? _unwatch;

  void _redraw(Object? _) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // A surface arrives in pieces: the components first, the data they bind to
    // after. Both have to redraw it. Watching '/' covers every path, since a
    // change notifies the ancestors of the path it landed on.
    component.surface.componentsModel.onCreated.addListener(_redraw);
    component.surface.componentsModel.onDeleted.addListener(_redraw);
    _root = component.surface.dataModel.watch<Object?>('/');
    _unwatch = _root!.subscribe(_redraw);
  }

  @override
  void dispose() {
    component.surface.componentsModel.onCreated.removeListener(_redraw);
    component.surface.componentsModel.onDeleted.removeListener(_redraw);
    _unwatch?.call();
    _root = null;
    super.dispose();
  }

  @override
  Component build(BuildContext context) => div(classes: 'a2ui-surface', [
    _Node(surface: component.surface, id: 'root'),
  ]);
}

/// Renders one component of a surface, and through it that component's children.
class _Node extends StatelessComponent {
  const _Node({required this.surface, required this.id});

  final SurfaceModel<ComponentApi> surface;
  final String id;

  @override
  Component build(BuildContext context) {
    final model = surface.componentsModel.get(id);
    if (model == null) {
      return div(classes: 'a2ui-missing', [Component.text('missing component "$id"')]);
    }

    final props = model.properties;
    return switch (model.type) {
      'Text' => _text(props),
      'Column' => _stack(props, 'a2ui-column'),
      'Row' => _stack(props, 'a2ui-row'),
      'Card' => div(classes: 'a2ui-card', [..._childNodes(props['child'])]),
      'Button' => _button(model),
      'TextField' => _textField(props),
      _ => div(classes: 'a2ui-missing', [
        Component.text('no renderer for "${model.type}"'),
      ]),
    };
  }

  /// Resolves a property that is either a literal or a binding into the data
  /// model. This is the whole of what `{"path": "/title"}` means to a renderer.
  Object? _resolve(Object? value) {
    if (value is Map && value['path'] is String) {
      return surface.dataModel.get(value['path'] as String);
    }
    return value;
  }

  String _string(Object? value) => _resolve(value)?.toString() ?? '';

  Component _text(Map<String, dynamic> props) {
    final content = _string(props['text']);
    return switch (props['variant']) {
      'h1' => h1(classes: 'a2ui-text', [Component.text(content)]),
      'h2' => h2(classes: 'a2ui-text', [Component.text(content)]),
      'h3' => h3(classes: 'a2ui-text', [Component.text(content)]),
      'h4' || 'h5' => h4(classes: 'a2ui-text', [Component.text(content)]),
      'caption' => span(classes: 'a2ui-text a2ui-caption', [Component.text(content)]),
      _ => p(classes: 'a2ui-text', [Component.text(content)]),
    };
  }

  Component _stack(Map<String, dynamic> props, String cls) {
    final justify = props['justify'];
    final align = props['align'];
    return div(
      classes: [
        cls,
        if (justify is String) 'a2ui-justify-$justify',
        if (align is String) 'a2ui-align-$align',
      ].join(' '),
      [..._childNodes(props['children'])],
    );
  }

  /// A child property is an id, a list of ids, or an explicit list wrapper.
  Iterable<Component> _childNodes(Object? value) sync* {
    for (final childId in _childIds(value)) {
      yield _Node(surface: surface, id: childId);
    }
  }

  Iterable<String> _childIds(Object? value) sync* {
    if (value is String) {
      yield value;
    } else if (value is List) {
      for (final child in value) {
        if (child is String) yield child;
      }
    } else if (value is Map && value['explicitList'] is List) {
      for (final child in value['explicitList'] as List) {
        if (child is String) yield child;
      }
    }
  }

  Component _button(ComponentModel model) {
    final props = model.properties;
    final variant = props['variant'];
    return button(
      classes: [
        'a2ui-button',
        if (variant is String) 'a2ui-button-$variant',
      ].join(' '),
      events: {
        'click': (_) {
          final action = props['action'];
          if (action is Map<String, dynamic>) {
            surface.dispatchAction(action, model.id);
          }
        },
      },
      [..._childNodes(props['child'])],
    );
  }

  Component _textField(Map<String, dynamic> props) => label(
    classes: 'a2ui-field',
    [
      span([Component.text(_string(props['label']))]),
      input(
        type: props['variant'] == 'obscured'
            ? InputType.password
            : InputType.text,
        value: _string(props['value']),
        attributes: const {},
      ),
    ],
  );
}
