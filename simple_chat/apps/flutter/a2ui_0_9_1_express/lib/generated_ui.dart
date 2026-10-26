import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';

import 'answer_content.dart';
import 'catalog.dart';

/// How a button tells the app what the user says by pressing it.
class _Reply {
  /// The key in the action's context that holds the user's message.
  static const String key = 'text';
}

/// The UI the model can generate in the chat.
///
/// The app plays both A2UI roles. It renders the catalog, and, since it calls
/// the model itself, it also uses the agent SDK to teach the model the
/// catalog and to read the A2UI in its answers.
class GeneratedUi {
  GeneratedUi() : this._(chatCatalog());

  GeneratedUi._(this.catalog)
    // The default format, Express, is shorter than direct JSON, but the agent
    // SDK reads it only once a block is complete.
    : _agent = A2uiGenerator(catalogs: [CatalogConfig(catalog)])
          .createProcessor(
            A2uiRendererCapabilities.forCatalogIds([
              catalog.id,
            ], version: protocolVersion),
          );

  static const A2uiProtocolVersion protocolVersion = A2uiProtocolVersion.v0_9_1;

  final CatalogImplementation catalog;

  /// Teaches the model the catalog, and reads its answers.
  final A2uiRequestProcessor _agent;

  /// Tells the model how to write UI in this chat, for the system prompt.
  String get prompt =>
      '''
# Generated UI in this chat

The app renders A2UI, protocol version ${protocolVersion.jsonValue}, with the
catalog `${catalog.id}` described below. Put UI where the user should see it in
a message, in A2UI Express blocks between parts of the text.

1. Each block builds one new surface: it starts with `surface("...")`, with a
   surface id that no other block in the message uses, and assigns `root`.
2. A button answers for the user. Give it an `Event` whose context holds
   `${_Reply.key}`: what the user says by pressing it, written as they would
   type it, such as
   `Button(Text("Under the counter"), _, Event("reply", {${_Reply.key}: "It goes under the counter"}))`.
   The app sends that text as the user's next message.
3. A button that opens a link calls `openUrl` instead:
   `Button(Text("View it"), _, openUrl("https://..."))`.
4. `MdCarousel` shows options side by side. Give each card an action, as for
   a button. A card that opens a link writes its action as a map,
   `{functionCall: {call: "openUrl", args: {url: "https://..."}}}`, since
   `openUrl(...)` inside a card does not compile.
5. The text of a `Text` component can use simple Markdown, such as bold and
   `- ` lists. A heading (`variant` h1 to h5) shows its text as written, so
   it has no Markdown.
6. When the UI shows a picture, the text of the message leaves it out.

${_agent.promptSnippet}''';

  /// Starts reading an answer.
  ///
  /// [onReply] receives what the user sends by pressing a button in the
  /// answer's UI.
  AnswerContent read({required ValueChanged<String> onReply}) => AnswerContent(
    agent: _agent,
    catalog: catalog,
    onAction: (action) => onReply(replyOf(action)),
  );

  /// What the user sends by triggering [action]: the text the prompt asks
  /// the model to put in its context, or, without one, the action's name.
  @visibleForTesting
  static String replyOf(A2uiRendererAction action) =>
      switch (action.context[_Reply.key]) {
        final String text when text.trim().isNotEmpty => text.trim(),
        _ => action.name,
      };
}
