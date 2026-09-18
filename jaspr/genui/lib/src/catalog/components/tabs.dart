import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../catalog_item.dart';
import '../schemas.dart';

/// Shows one of several children at a time, chosen by a tab bar.
final CatalogItem tabsItem = CatalogItem(
  name: 'Tabs',
  schema: Schema.object(
    description: 'A row of tabs, each showing a different component.',
    properties: {
      'tabs': Schema.list(
        description: 'The tabs, in the order they appear.',
        items: Schema.object(
          properties: {
            'label': A2uiSchemas.string(description: 'The label of the tab.'),
            'content': A2uiSchemas.componentId(
              description: 'The ID of the component this tab shows.',
            ),
          },
          required: ['label', 'content'],
        ),
      ),
      'activeTab': A2uiSchemas.number(
        description:
            'The index of the open tab. Bind this to a path to let the '
            'chosen tab survive a rebuild and be readable later.',
      ),
    },
    required: ['tabs'],
  ),
  builder: (context) {
    final List<Map<String, Object?>> tabs = _tabsOf(context['tabs']);
    if (tabs.isEmpty) return Component.empty();

    final int active = (context.number('activeTab') ?? 0).round().clamp(
      0,
      tabs.length - 1,
    );

    return div(classes: 'a2ui-tabs', [
      div(classes: 'a2ui-tab-bar', attributes: {'role': 'tablist'}, [
        for (final (int index, Map<String, Object?> tab) in tabs.indexed)
          button(
            classes: index == active
                ? 'a2ui-tab a2ui-tab-active'
                : 'a2ui-tab',
            type: ButtonType.button,
            attributes: {
              'role': 'tab',
              'aria-selected': '${index == active}',
            },
            // Without a bound activeTab there is nowhere to record the
            // choice, so the tabs render but do not switch. Saying so is
            // better than a tab bar that silently ignores clicks.
            onClick: () => context.setValue('activeTab', index),
            [Component.text('${tab['label'] ?? ''}')],
          ),
      ]),
      div(classes: 'a2ui-tab-panel', attributes: {'role': 'tabpanel'}, [
        context.buildChild(tabs[active]['content']),
      ]),
    ]);
  },
);

List<Map<String, Object?>> _tabsOf(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final Object? tab in raw)
      if (tab is Map) tab.cast<String, Object?>(),
  ];
}
