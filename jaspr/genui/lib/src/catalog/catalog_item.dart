import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../primitives/simple_items.dart';

/// Builds the Jaspr component for one A2UI component instance.
typedef A2uiComponentBuilder = Component Function(A2uiBuildContext context);

/// A component in a [WebCatalog]: its name, its schema, and how to render it.
///
/// This is the web counterpart of Flutter GenUI's `CatalogItem`. The schema
/// plays a double role: it is sent to the model as the contract for what the
/// component accepts, and it is what `a2ui_core`'s binder reads to decide
/// which properties are data bindings, which are actions, and which are
/// children. Marking a property with the helpers on [core.CommonSchemas] is
/// therefore not decoration; it is what makes the property reactive.
final class CatalogItem extends core.ComponentApi {
  /// Creates a [CatalogItem].
  CatalogItem({
    required this.name,
    required this.schema,
    required this.builder,
  });

  @override
  final String name;

  @override
  final Schema schema;

  /// Renders an instance of this component.
  final A2uiComponentBuilder builder;
}

/// What a [CatalogItem.builder] is given to render one component instance.
///
/// [properties] are already resolved by `a2ui_core`'s binder, so a builder
/// never sees the raw protocol JSON: a `{"path": "/user/name"}` binding
/// arrives as the string it currently points at, an action arrives as a
/// callback, and a child list arrives as [core.ChildNode]s. When the data
/// behind a binding changes, the renderer rebuilds with new [properties].
final class A2uiBuildContext {
  /// Creates an [A2uiBuildContext].
  const A2uiBuildContext({
    required this.id,
    required this.type,
    required this.properties,
    required this.componentContext,
    required this.surfaceId,
    required this.buildChild,
    required this.reportError,
  });

  /// The unique ID of this component within its surface.
  final String id;

  /// The component type, e.g. `Text`.
  final String type;

  /// The component's resolved properties.
  final JsonMap properties;

  /// The underlying core context, for data access beyond [properties].
  final core.ComponentContext componentContext;

  /// The ID of the surface this component belongs to.
  final String surfaceId;

  /// Renders a child.
  ///
  /// Accepts either a component ID, as a `child` property holds, or a
  /// [core.ChildNode], as an entry of a resolved `children` list holds. The
  /// distinction matters for templated lists, where each child renders
  /// against its own slice of the data model.
  final Component Function(Object? child) buildChild;

  /// Reports an error raised while rendering this component.
  final void Function(Object error, StackTrace stackTrace) reportError;

  /// The value of [key], or `null` if absent.
  Object? operator [](String key) => properties[key];

  /// [key] as a string, or `null`. Numbers and booleans are stringified,
  /// because a model that binds a count to a label is being reasonable.
  String? string(String key) {
    final Object? value = properties[key];
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return '$value';
    return null;
  }

  /// [key] as a number, or `null`. Parses numeric strings, because a value
  /// that made a round trip through the data model may have become one.
  double? number(String key) {
    final Object? value = properties[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// [key] as a boolean, or `null`.
  bool? boolean(String key) {
    final Object? value = properties[key];
    if (value is bool) return value;
    if (value is String) return value == 'true';
    return null;
  }

  /// [key] as the callback the binder produced for an action property, or
  /// `null` if the component did not declare one.
  ///
  /// Calling it dispatches the action: an `event` reaches the app through
  /// [core.SurfaceModel.onAction], a `functionCall` runs in the catalog.
  void Function()? action(String key) {
    final Object? value = properties[key];
    if (value is Future<void> Function()) return () => value();
    if (value is void Function()) return value;
    return null;
  }

  /// [key] as a list of children, whether it was written as explicit IDs or
  /// as a template bound to a list in the data model.
  List<core.ChildNode> children(String key) {
    final Object? value = properties[key];
    if (value is List) return value.whereType<core.ChildNode>().toList();
    return const [];
  }

  /// Writes [value] back through the binding behind [key].
  ///
  /// The binder supplies a setter for every dynamic property written as a
  /// `{"path": ...}` binding; this is how an input returns what the user
  /// typed to the data model, where the agent can read it. Returns whether
  /// there was a binding to write to: a component bound to a literal has
  /// nowhere to put the value, which is a UI worth rendering as read-only
  /// rather than one that silently drops input.
  bool setValue(String key, Object? value) {
    final String setter = 'set${key[0].toUpperCase()}${key.substring(1)}';
    final Object? fn = properties[setter];
    if (fn is void Function(Object?)) {
      fn(value);
      return true;
    }
    return false;
  }

  /// The validation messages for checks that currently fail.
  ///
  /// The binder evaluates a component's `checks` and leaves the outcome in
  /// `isValid` and `validationErrors`.
  List<String> get validationErrors {
    final Object? errors = properties['validationErrors'];
    if (errors is List) return errors.map((e) => '$e').toList();
    return const [];
  }

  /// Whether every check on this component currently passes.
  bool get isValid => properties['isValid'] as bool? ?? true;
}

/// A set of components and functions a surface can be built from.
///
/// A catalog is both halves of the contract with the model: [core.Catalog]
/// carries the schemas that go into the prompt and the functions the surface
/// may call, while each [CatalogItem] knows how to render itself.
/// [systemPromptFragments] carries the prose that the schemas cannot.
class WebCatalog extends core.Catalog<CatalogItem> {
  /// Creates a [WebCatalog].
  WebCatalog({
    required super.id,
    required List<CatalogItem> components,
    super.functions,
    super.themeSchema,
    this.systemPromptFragments = const [],
  }) : super(components: components);

  /// Prose added to the system prompt for this catalog.
  final List<String> systemPromptFragments;

  /// Returns a copy of this catalog without the named components.
  ///
  /// Useful for trimming a catalog to what an app can actually honor; there
  /// is no point offering the model an `Image` if the app has no images.
  WebCatalog without(Iterable<String> componentNames) {
    final Set<String> removed = componentNames.toSet();
    return WebCatalog(
      id: id,
      components: components.values
          .where((c) => !removed.contains(c.name))
          .toList(),
      functions: functions.values.toList(),
      themeSchema: themeSchema,
      systemPromptFragments: systemPromptFragments,
    );
  }

  /// Returns a copy of this catalog with extra components and prompt prose.
  WebCatalog withItems(
    List<CatalogItem> newComponents, {
    List<String> newSystemPromptFragments = const [],
  }) {
    return WebCatalog(
      id: id,
      components: [...components.values, ...newComponents],
      functions: functions.values.toList(),
      themeSchema: themeSchema,
      systemPromptFragments: [
        ...systemPromptFragments,
        ...newSystemPromptFragments,
      ],
    );
  }
}
