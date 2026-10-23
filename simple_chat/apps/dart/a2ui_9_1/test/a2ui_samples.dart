import 'package:a2ui_9_1/catalog.dart';

final String _catalogId = chatCatalog().id;

/// What the user says by pressing the button in [questionBlock].
const String underTheCounter = 'It goes under the counter';

/// What the user says by selecting the second card in [carouselBlock].
const String takeTheEco = 'I will take the Eco';

/// A block with a button that answers for the user, written as the prompt
/// asks the model to write it.
String questionBlock({String surfaceId = 'question'}) =>
    '''
<a2ui-json>
[
  {"version": "v0.9.1", "createSurface": {"surfaceId": "$surfaceId", "catalogId": "$_catalogId"}},
  {"version": "v0.9.1", "updateComponents": {"surfaceId": "$surfaceId", "components": [
    {"id": "root", "component": "Button", "child": "label", "action": {"event": {"name": "reply", "context": {"text": "$underTheCounter"}}}},
    {"id": "label", "component": "Text", "text": "Under the counter"}
  ]}}
]
</a2ui-json>''';

/// A block with two models side by side, each card answering for the user.
String carouselBlock() =>
    '''
<a2ui-json>
[
  {"version": "v0.9.1", "createSurface": {"surfaceId": "options", "catalogId": "$_catalogId"}},
  {"version": "v0.9.1", "updateComponents": {"surfaceId": "options", "components": [
    {"id": "root", "component": "MdCarousel", "items": [
      {"name": "Silent", "markdown": "**39 dB**", "action": {"event": {"name": "reply", "context": {"text": "I will take the Silent"}}}},
      {"name": "Eco", "markdown": "**6.8 liters**", "action": {"event": {"name": "reply", "context": {"text": "$takeTheEco"}}}}
    ]}
  ]}}
]
</a2ui-json>''';
