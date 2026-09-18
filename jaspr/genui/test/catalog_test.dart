import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:jaspr/jaspr.dart';
import 'package:test/test.dart';

/// Binds one component the way the renderer does.
///
/// Returns the resolved properties the builder would see, and the surface
/// they were resolved against, so a test can check what a write-back did.
({Map<String, dynamic> props, core.SurfaceModel<CatalogItem> surface}) bindOn(
  CatalogItem item,
  Map<String, dynamic> properties, {
  Map<String, Object?> data = const {},
  String basePath = '/',
}) {
  final WebCatalog catalog = basicCatalog();
  final surface = core.SurfaceModel<CatalogItem>('s', catalog: catalog);
  surface.dataModel.set('/', Map<String, Object?>.from(data));
  final model = core.ComponentModel('c', item.name, properties);
  surface.componentsModel.addComponent(model);

  final binder = core.GenericBinder(
    core.ComponentContext(surface, model, basePath: basePath),
    item.schema,
  );
  return (props: binder.resolvedProps.value, surface: surface);
}

/// The resolved properties a builder would see for one component.
Map<String, dynamic> bind(
  CatalogItem item,
  Map<String, dynamic> properties, {
  Map<String, Object?> data = const {},
  String basePath = '/',
}) => bindOn(item, properties, data: data, basePath: basePath).props;

/// Flattens a component tree to the tags and text it renders.
String render(Component component) {
  final buffer = StringBuffer();
  void walk(Component node) {
    switch (node) {
      case Fragment(:final List<Component> children):
        children.forEach(walk);
      case DomComponent(:final String tag, :final List<Component>? children):
        buffer.write('<$tag>');
        children?.forEach(walk);
        buffer.write('</$tag>');
      case Text(:final String text):
        buffer.write(text);
      default:
        buffer.write('?');
    }
  }

  walk(component);
  return buffer.toString();
}

void main() {
  group('basicCatalog', () {
    test('uses the A2UI basic catalog ID', () {
      expect(basicCatalog().id, basicCatalogId);
    });

    test('offers every component it documents', () {
      expect(
        basicCatalog().components.keys,
        containsAll([
          'Text',
          'Column',
          'Row',
          'Card',
          'Button',
          'TextField',
          'CheckBox',
          'ChoicePicker',
          'Slider',
          'Divider',
          'Image',
          'List',
          'Tabs',
          'DateTimeInput',
        ]),
      );
    });

    test('drops Image when an app has no images to show', () {
      expect(basicCatalogWithoutAssets().components, isNot(contains('Image')));
      expect(basicCatalogWithoutAssets().components, contains('Text'));
    });
  });

  group('property binding', () {
    test('a literal is passed straight through', () {
      expect(bind(BasicCatalogItems.text, {'text': 'hello'})['text'], 'hello');
    });

    test('a path is resolved against the data model', () {
      expect(
        bind(
          BasicCatalogItems.text,
          {
            'text': {'path': '/user/name'},
          },
          data: {
            'user': {'name': 'Ada'},
          },
        )['text'],
        'Ada',
      );
    });

    test('a relative path resolves against the component base path', () {
      // This is what makes a templated list work: each row is bound at its
      // own index, and reads its fields by relative path.
      expect(
        bind(
          BasicCatalogItems.text,
          {
            'text': {'path': 'name'},
          },
          data: {
            'people': [
              {'name': 'Ada'},
              {'name': 'Grace'},
            ],
          },
          basePath: '/people/1',
        )['text'],
        'Grace',
      );
    });

    test('a function call is evaluated', () {
      expect(
        bind(BasicCatalogItems.text, {
          'text': {
            'call': 'formatCurrency',
            'args': {'value': 12.5, 'currencyCode': 'USD'},
          },
        })['text'],
        contains('12.50'),
      );
    });

    test('an explicit child list becomes child nodes', () {
      final Object? children = bind(BasicCatalogItems.column, {
        'children': ['a', 'b'],
      })['children'];

      expect(children, isA<List<Object?>>());
      expect(
        (children! as List<Object?>).map((c) => (c! as core.ChildNode).id),
        ['a', 'b'],
      );
    });

    test('a templated child list yields one node per item, each at its own '
        'path', () {
      final Object? children = bind(
        BasicCatalogItems.column,
        {
          'children': {'componentId': 'row', 'path': '/items'},
        },
        data: {
          'items': [1, 2, 3],
        },
      )['children'];

      final List<core.ChildNode> nodes =
          (children! as List<Object?>).cast<core.ChildNode>();
      expect(nodes.map((n) => n.id), ['row', 'row', 'row']);
      expect(nodes.map((n) => n.basePath), ['/items/0', '/items/1', '/items/2']);
    });

    test('an action becomes a callback', () {
      final Map<String, dynamic> props = bind(BasicCatalogItems.button, {
        'child': 'label',
        'action': {
          'event': {'name': 'go'},
        },
      });
      expect(props['action'], isA<Function>());
    });

    test('a bound value gets a setter that writes to the data model', () {
      // This is how what a user types becomes something the model can read
      // back on the next turn.
      final bound = bindOn(BasicCatalogItems.textField, {
        'label': 'Email',
        'value': {'path': '/form/email'},
      });

      final Object? setter = bound.props['setValue'];
      expect(setter, isA<void Function(Object?)>());
      (setter! as void Function(Object?))('ada@example.com');

      expect(bound.surface.dataModel.get('/form/email'), 'ada@example.com');
    });

    test('a value written as a literal has no setter to write back through',
        () {
      // Nothing to write to is worth knowing about: the component renders
      // read-only rather than dropping what the user types.
      final Map<String, dynamic> props = bind(BasicCatalogItems.textField, {
        'label': 'Email',
        'value': 'fixed@example.com',
      });
      expect(props['setValue'], isNull);
    });

    test('checks decide whether the component reads as valid', () {
      final Map<String, dynamic> valid = bind(
        BasicCatalogItems.button,
        {
          'child': 'label',
          'action': {
            'event': {'name': 'go'},
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
        data: {
          'form': {'email': 'a@b.co'},
        },
      );
      expect(valid['isValid'], isTrue);
      expect(valid['validationErrors'], isEmpty);

      final Map<String, dynamic> invalid = bind(
        BasicCatalogItems.button,
        {
          'child': 'label',
          'action': {
            'event': {'name': 'go'},
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
        data: {
          'form': {'email': ''},
        },
      );
      expect(invalid['isValid'], isFalse);
      expect(invalid['validationErrors'], ['Email is required.']);
    });
  });

  group('inline markdown', () {
    test('renders emphasis and code as elements', () {
      expect(
        render(Component.fragment(renderInlineMarkdown('a **b** *c* `d`'))),
        'a <strong>b</strong> <em>c</em> <code>d</code>',
      );
    });

    test('renders an http link', () {
      expect(
        render(
          Component.fragment(renderInlineMarkdown('[docs](https://a2ui.org)')),
        ),
        contains('<a>docs</a>'),
      );
    });

    test('refuses a javascript: link, keeping the label', () {
      // The text comes from a model, so a link target is untrusted input.
      final String html = render(
        Component.fragment(
          renderInlineMarkdown('[click](javascript:alert(1))'),
        ),
      );
      expect(html, isNot(contains('<a>')));
      expect(html, contains('click'));
    });

    test('leaves markup in the text as text', () {
      expect(
        render(Component.fragment(renderInlineMarkdown('<script>x</script>'))),
        '<script>x</script>',
      );
    });
  });
}
