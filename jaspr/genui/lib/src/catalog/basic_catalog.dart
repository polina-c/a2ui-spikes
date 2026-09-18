import 'package:json_schema_builder/json_schema_builder.dart';

import '../primitives/simple_items.dart';
import 'catalog_item.dart';
import 'components/button.dart';
import 'components/choice_picker.dart';
import 'components/inputs.dart';
import 'components/layout.dart';
import 'components/tabs.dart';
import 'components/text.dart';
import 'functions.dart';

/// The components of the basic catalog, by name.
abstract final class BasicCatalogItems {
  /// A button that runs an action when pressed.
  static final CatalogItem button = buttonItem;

  /// A container that visually groups one child.
  static final CatalogItem card = cardItem;

  /// A labelled checkbox.
  static final CatalogItem checkBox = checkBoxItem;

  /// Lets the user choose one or more options from a list.
  static final CatalogItem choicePicker = choicePickerItem;

  /// Arranges children vertically.
  static final CatalogItem column = columnItem;

  /// A picker for a date, a time, or both.
  static final CatalogItem dateTimeInput = dateTimeInputItem;

  /// A line separating content.
  static final CatalogItem divider = dividerItem;

  /// An image from a URL.
  static final CatalogItem image = imageItem;

  /// A scrollable list of children.
  static final CatalogItem list = listItem;

  /// Arranges children horizontally.
  static final CatalogItem row = rowItem;

  /// A slider over a numeric range.
  static final CatalogItem slider = sliderItem;

  /// A row of tabs, each showing a different child.
  static final CatalogItem tabs = tabsItem;

  /// A block of text.
  static final CatalogItem text = textItem;

  /// A field the user types into.
  static final CatalogItem textField = textFieldItem;

  /// Every component above.
  static List<CatalogItem> get all => [
    button,
    card,
    checkBox,
    choicePicker,
    column,
    dateTimeInput,
    divider,
    image,
    list,
    row,
    slider,
    tabs,
    text,
    textField,
  ];
}

/// The catalog a generated UI is built from, unless an app supplies its own.
///
/// The ID is the A2UI basic catalog's, and the component names and property
/// shapes follow it, so an agent written for the basic catalog drives this
/// renderer without knowing it is talking to a web page.
WebCatalog basicCatalog({List<String> systemPromptFragments = const []}) {
  return WebCatalog(
    id: basicCatalogId,
    components: BasicCatalogItems.all,
    functions: basicFunctions(),
    themeSchema: Schema.object(
      properties: {
        'primaryColor': Schema.string(pattern: r'^#[0-9a-fA-F]{6}$'),
      },
      additionalProperties: true,
    ),
    systemPromptFragments: [basicCatalogRules, ...systemPromptFragments],
  );
}

/// A catalog without the components that need assets the app may not have.
///
/// Offering `Image` to a model that has no URLs to point it at produces
/// broken images, so an app with no image sources is better off without it.
WebCatalog basicCatalogWithoutAssets({
  List<String> systemPromptFragments = const [],
}) => basicCatalog(
  systemPromptFragments: systemPromptFragments,
).without(const ['Image']);

/// Rules the schemas cannot express, added to the system prompt.
const String basicCatalogRules = r'''
**REQUIRED PROPERTIES:** Include every required property of a component, even
when the value is bound to data rather than written out.
- `Text` must have `text`. If it is dynamic, write `{ "path": "..." }`.
- `Image` must have `url`.
- `Button` must have `child` and `action`.
- `TextField`, `CheckBox` and `ChoicePicker` must have `label`.

**EXAMPLES:**

1. Create a surface:
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "s1",
    "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json",
    "sendDataModel": true
  }
}
```

2. Fill it with components:
```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "s1",
    "components": [
      {"id": "root", "component": "Column", "children": ["title", "go"]},
      {"id": "title", "component": "Text", "text": "Pick a size", "variant": "h3"},
      {"id": "goLabel", "component": "Text", "text": "Continue"},
      {"id": "go", "component": "Button", "child": "goLabel",
       "action": {"event": {"name": "continue"}}}
    ]
  }
}
```

**IMPORTANT:**
- Exactly one component must have `id: "root"`, or nothing is shown.
- Every ID mentioned in `children`, `child` or `content` must also be defined
  in the same `updateComponents` list.
- `createSurface` only opens a surface; it carries no components. Send
  `updateComponents` after it.
- To read back what the user entered, bind an input's `value` to a path:
  `"value": {"path": "/form/email"}`.
''';
