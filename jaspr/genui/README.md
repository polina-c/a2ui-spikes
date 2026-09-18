# genui for Jaspr

Generative UI for Dart on the web. A model sends [A2UI][a2ui] messages, and this
renders them as a live page: bound values track a data model, buttons dispatch
events back, and what the user types is readable on the next turn.

This is a port of [Flutter GenUI][genui] to [Jaspr][jaspr]. The protocol, the
data model and the reactive binder are the same code in both, because both
depend on [`package:a2ui_core`][a2ui_core], which is plain Dart. What is ported
is the layer above: in Flutter that layer builds widgets, and here it builds DOM
elements.

[a2ui]: https://a2ui.org
[genui]: https://github.com/flutter/genui/tree/main/packages/genui
[jaspr]: https://jaspr.site
[a2ui_core]: https://pub.dev/packages/a2ui_core

For a running app built on this, see [simple_chat](../simple_chat).

## What it does

A model that speaks A2UI does not send HTML. It sends messages: open a surface,
put these components on it, set this value. A component's properties can be
literals, or paths into a data model, or calls to functions the catalog
provides. This package turns that into a page and keeps it in sync.

The loop that makes it useful runs in both directions. A `TextField` bound to
`/form/email` writes what the user types into the data model; a `Button` whose
check calls `required` on that same path stays disabled until the field is
filled; and when the button is finally pressed, the data model goes back to the
model along with the event. The model wrote the form, so it knows how to read
the answers.

## Using it

```dart
import 'package:genui/genui.dart';
import 'package:genui/web_llm.dart';

final catalog = basicCatalog();
final controller = SurfaceController(catalogs: [catalog]);

final conversation = Conversation(
  generator: WebLlmClient(),
  controller: controller,
  systemPrompt: PromptBuilder.chat(catalog: catalog).systemPromptJoined(),
);

// Surfaces appear here as the model builds them.
controller.surfaceUpdates.listen((update) {
  if (update case SurfaceAdded(:final surfaceId)) {
    // Render SurfaceView(surface: controller.surface(surfaceId)!)
  }
});

await conversation.send('Help me plan a weekend in Lisbon.');
```

`SurfaceView` renders a surface. It is an ordinary Jaspr component and can go
anywhere a component can:

```dart
SurfaceView(
  surface: controller.surface('s1')!,
  placeholder: p([Component.text('Building the UI...')]),
)
```

## The catalog

A catalog is the contract with the model: the components it may use, their
properties, and the functions a binding may call. `basicCatalog()` is the A2UI
basic catalog, so an agent written against that specification drives this
renderer without knowing it is talking to a web page. It has `Text`, `Column`,
`Row`, `Card`, `List`, `Divider`, `Button`, `TextField`, `CheckBox`,
`ChoicePicker`, `Slider`, `DateTimeInput`, `Tabs` and `Image`.

`basicCatalogWithoutAssets()` drops `Image`, which is the right catalog for an
app that has no image URLs to hand the model.

Components render plain HTML with `a2ui-` class names and carry no styles of
their own, so the app decides how a generated surface looks. `simple_chat`'s
[styles.css](../simple_chat/web/styles.css) is a worked example.

### Adding a component

A `CatalogItem` is a name, a schema, and a builder:

```dart
final rating = CatalogItem(
  name: 'Rating',
  schema: Schema.object(
    description: 'A star rating.',
    properties: {
      'value': A2uiSchemas.number(description: 'Stars, 1 to 5.'),
      'label': A2uiSchemas.string(),
    },
    required: ['value'],
  ),
  builder: (context) => div(classes: 'rating', [
    Component.text('*' * (context.number('value') ?? 0).round()),
  ]),
);

final catalog = basicCatalog().withItems(
  [rating],
  newSystemPromptFragments: ['Use Rating to show a score out of five.'],
);
```

The schema is not only documentation. `a2ui_core`'s binder reads it to work out
which properties are live: a property declared with `A2uiSchemas.number()`
accepts a binding and updates when the data behind it changes, while one
declared as a bare `Schema.number()` is a constant no matter what JSON the model
sends. `A2uiSchemas.action()` produces a callback, and `A2uiSchemas.children()`
produces child nodes. Getting this wrong is the usual reason a generated
component renders once and then goes stale.

Inside a builder, `context.properties` are already resolved: bindings have
become values, actions have become callbacks, and children have become
`ChildNode`s to pass to `context.buildChild`. `context.setValue('value', x)`
writes back through a binding, and returns false when there is nothing to write
to.

## The system prompt

`PromptBuilder` writes the system prompt from the catalog. It has a setting the
Flutter package does not need:

```dart
PromptBuilder.chat(catalog: catalog, detail: PromptDetail.compact)  // default
PromptBuilder.chat(catalog: catalog, detail: PromptDetail.full)
```

`PromptDetail.full` sends the A2UI protocol schemas as they are, which is what
Flutter GenUI does and what a large hosted model can use. That prompt is around
twenty thousand tokens. A model small enough to run in a browser tab has a
context window that would leave no room for the conversation, so `compact` is
the default: it names the shared value types once and prints each component as a
line per property, which comes to about a quarter of the size. Both describe the
same protocol.

## Running a model in the browser

`package:genui/web_llm.dart` is a separate entry point because it only compiles
for the web. It wraps [WebLLM][webllm], which compiles a model to WebGPU and
runs it on the page.

[webllm]: https://github.com/mlc-ai/web-llm

It needs two pieces. The Dart half is `WebLlmClient`. The other half is
[`lib/assets/web_llm.js`](lib/assets/web_llm.js), which imports WebLLM and
installs the shim the Dart half talks to. Copy it next to your `index.html` and
load it:

```html
<script type="module" src="web_llm.js"></script>
```

`WebLlmClient` implements `TextGenerator`, which is the only thing
`Conversation` needs. Anything that streams text can take its place: a hosted
API, a proxy, or a fake in a test.

It takes an optional `Sampling`, which is passed to WebLLM on every request:

```dart
WebLlmClient(
  modelId: 'Llama-3.2-1B-Instruct-q4f16_1-MLC',
  sampling: const Sampling(temperature: 0.7, repetitionPenalty: 1.1),
);
```

Left out, the temperature is low and the penalties are WebLLM's own, which is
the setting for generating A2UI: a surface has to parse far more often than it
has to be interesting. A client answering in prose wants the opposite, and the
penalties are what stop a small model answering every question with a rewording
of its last answer. [`wix/jaspr`](../../wix/jaspr) sets all four and says what
was measured.

It also takes a `ContextWindow`, which is fixed when the model is loaded rather
than sent per request:

```dart
WebLlmClient(contextWindow: const ContextWindow.fixed(8192));
WebLlmClient(
  contextWindow: const ContextWindow.sliding(8192, attentionSinkTokens: 2048),
);
```

Left out, the model keeps the window its own configuration asks for, which on
most prebuilt models is 4096 tokens;
`WebLlmClient.defaultContextWindowSize` reports it. A system prompt built from a
catalog takes a good part of that, and once what is cached plus the next message
no longer fits, WebLLM throws `ContextWindowSizeExceededError` on a message of
any length. A fixed window is larger, and costs GPU memory in proportion,
because the key-value cache is sized from it. A sliding window drops its oldest
tokens rather than failing, and `attentionSinkTokens` is how much of the start
it keeps anyway, which is what stops the system prompt falling out of it.

## What was ported, and what was not

Reused from `package:a2ui_core` rather than ported: the A2UI message types, the
data model, expression evaluation, `MessageProcessor`, and `GenericBinder`,
which is the reactive property resolution that both renderers are built on.

Ported from Flutter GenUI: the streaming response parser, which pulls A2UI
messages out of a token stream and is the same code; the JSON block parser; the
catalog functions (`required`, `regex`, `formatCurrency`, and the rest);
`PromptBuilder`; the surface controller; and the catalog, rewritten from widgets
to DOM elements.

Not ported: `AudioPlayer`, `Video` and `Modal`, which wrap Flutter plugins with
no direct web equivalent; the catalog gallery development tool; and the Flutter
`CatalogItem` plumbing, which the core binder replaces.

Three things differ on purpose. `Text` renders a small Markdown subset (bold,
italic, code and links) as Jaspr nodes rather than as HTML, because model output
is untrusted input and building nodes means markup in it can only ever be text;
link targets are limited to http and https for the same reason. `PromptDetail`
exists because of the context window a browser model has.

The third is a fix. The streaming parser here holds back a trailing backtick or
two instead of emitting it as text, because a chunk boundary inside an opening
fence otherwise puts the backticks in the prose the user reads and leaves the
rest of the fence to be read as more prose. A model streams "```" and "json" as
separate tokens, so that boundary falls there routinely. The messages still
parsed without this, by way of the raw-JSON path; what leaked was the fence.

## Tests

```sh
dart test
```

The suite covers the streaming parser, the catalog functions, property binding,
the surface controller, the prompt builder, and the renderer itself, which is
exercised through `jaspr_test` by feeding it the A2UI messages a model would
send and checking what comes out.
