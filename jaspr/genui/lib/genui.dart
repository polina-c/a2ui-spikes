/// Generative UI (A2UI) for Dart on the web, rendered with Jaspr.
///
/// This is a port of [Flutter GenUI](https://github.com/flutter/genui) to
/// Jaspr. The protocol, the data model and the reactive binder are the same
/// code in both: they come from `package:a2ui_core`. What is ported is
/// everything above them, the layer that turns an A2UI surface into
/// something on screen, which in Flutter means widgets and here means DOM
/// elements.
///
/// The browser-side inference client lives in `package:genui/web_llm.dart`,
/// which is a separate entry point because it only compiles for the web.
library;

export 'src/catalog/basic_catalog.dart';
export 'src/catalog/catalog_item.dart';
export 'src/catalog/functions.dart';
export 'src/catalog/markdown.dart' show renderInlineMarkdown;
export 'src/catalog/schemas.dart';
export 'src/components/fallback.dart';
export 'src/components/surface.dart';
export 'src/engine/surface_controller.dart';
export 'src/facade/conversation.dart';
export 'src/facade/prompt_builder.dart';
export 'src/model/generation_events.dart';
export 'src/primitives/a2ui_validation_exception.dart';
export 'src/primitives/logging.dart';
export 'src/primitives/simple_items.dart';
export 'src/transport/a2ui_parser_transformer.dart';
export 'src/utils/json_block_parser.dart';
