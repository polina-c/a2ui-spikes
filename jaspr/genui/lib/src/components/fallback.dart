import 'package:jaspr/jaspr.dart';

/// Rendered in place of a component that could not be built.
///
/// A generated UI is only as good as the last thing the model emitted, so a
/// single bad component should cost that component and not the surface
/// around it.
class FallbackView extends StatelessComponent {
  /// Creates a [FallbackView].
  const FallbackView({required this.error, super.key});

  /// The error that stopped the component from rendering.
  final Object error;

  @override
  Component build(BuildContext context) {
    return DomComponent(
      tag: 'div',
      attributes: const {'class': 'a2ui-error', 'role': 'alert'},
      children: [Component.text('Could not render this: $error')],
    );
  }
}
