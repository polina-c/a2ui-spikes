// A2UI renderer for Jaspr.
//
// a2ui has no Jaspr renderer. It has `a2ui_core`, which is plain Dart and does
// the protocol work: it parses messages, keeps the component tree and the data
// model, resolves bindings, and dispatches actions. What is missing is the last
// step, turning a component tree into a framework's views. That is this file.
//
// It covers the minimal catalog that ships with `a2ui_core`: Text, Row, Column,
// Button and TextField. A component the catalog does not have is drawn as a
// visible placeholder rather than skipped, so a model that reaches past the
// catalog shows up on screen instead of silently rendering nothing.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders one A2UI surface.
class A2uiSurface extends StatefulComponent {
  const A2uiSurface({required this.surface, super.key});

  final SurfaceModel<ComponentApi> surface;

  @override
  State<A2uiSurface> createState() => _A2uiSurfaceState();
}

class _A2uiSurfaceState extends State<A2uiSurface> {
  // The data model hands out signals per path and holds them weakly, so this
  // reference is what keeps the root subscription alive.
  ReadonlySignal<Object?>? _root;
  void Function()? _unwatch;

  void _rebuild(Object? _) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // The model changes after the first paint: components arrive, then the
    // data they bind to. Both have to redraw the surface. Watching '/' covers
    // every path, because a change notifies the ancestors of the path it hit.
    component.surface.componentsModel.onCreated.addListener(_rebuild);
    component.surface.componentsModel.onDeleted.addListener(_rebuild);
    _root = component.surface.dataModel.watch<Object?>('/');
    _unwatch = _root!.subscribe(_rebuild);
  }

  @override
  void dispose() {
    component.surface.componentsModel.onCreated.removeListener(_rebuild);
    component.surface.componentsModel.onDeleted.removeListener(_rebuild);
    _unwatch?.call();
    _root = null;
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'a2ui-surface', [
      _A2uiNode(surface: component.surface, id: 'root'),
    ]);
  }
}

/// Renders one component of a surface, and its children.
class _A2uiNode extends StatelessComponent {
  const _A2uiNode({required this.surface, required this.id});

  final SurfaceModel<ComponentApi> surface;
  final String id;

  @override
  Component build(BuildContext context) {
    final model = surface.componentsModel.get(id);
    if (model == null) {
      return div(classes: 'a2ui-missing', [
        Component.text('missing component "$id"'),
      ]);
    }

    final props = model.properties;
    return switch (model.type) {
      'Text' => _text(props),
      'Column' => _stack(props, 'a2ui-column'),
      'Row' => _stack(props, 'a2ui-row'),
      'Card' => div(classes: 'a2ui-card', [
        if (props['child'] is String)
          _A2uiNode(surface: surface, id: props['child'] as String),
      ]),
      'Button' => _button(model),
      'TextField' => _textField(props),
      _ => div(classes: 'a2ui-missing', [
        Component.text('no renderer for "${model.type}"'),
      ]),
    };
  }

  /// Resolves a property that may be a literal or a binding into the data model.
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
      _children(props['children']).map((c) => _A2uiNode(surface: surface, id: c)).toList(),
    );
  }

  /// `children` is a list of ids, or a template that repeats over a data list.
  Iterable<String> _children(Object? value) sync* {
    if (value is List) {
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
      [
        if (props['child'] is String)
          _A2uiNode(surface: surface, id: props['child'] as String),
      ],
    );
  }

  Component _textField(Map<String, dynamic> props) {
    return label(classes: 'a2ui-field', [
      span([Component.text(_string(props['label']))]),
      input(
        type: props['variant'] == 'obscured' ? InputType.password : InputType.text,
        value: _string(props['value']),
        attributes: {},
      ),
    ]);
  }
}
