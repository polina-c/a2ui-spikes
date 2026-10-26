/// What the user says by pressing the button in [questionBlock].
const String underTheCounter = 'It goes under the counter';

/// What the user says by selecting the second card in [carouselBlock].
const String takeTheEco = 'I will take the Eco';

/// A block with a button that answers for the user, written as the prompt
/// asks the model to write it.
String questionBlock({String surfaceId = 'question'}) =>
    '''
<a2ui>
surface("$surfaceId")
root = Button(Text("Under the counter"), _, Event("reply", {text: "$underTheCounter"}))
</a2ui>''';

/// A block with two models side by side, each card answering for the user.
String carouselBlock() =>
    '''
<a2ui>
surface("options")
root = MdCarousel([
  {name: "Silent", markdown: "**39 dB**", action: Event("reply", {text: "I will take the Silent"})},
  {name: "Eco", markdown: "**6.8 liters**", action: Event("reply", {text: "$takeTheEco"})}
])
</a2ui>''';

/// A block with a button that opens a page.
String linkBlock() => '''
<a2ui>
surface("link")
root = Button(Text("View it"), _, openUrl("https://example.com"))
</a2ui>''';

/// A carousel whose cards open pages, written as the prompt asks.
String linkCarouselBlock() => '''
<a2ui>
surface("pages")
root = MdCarousel([
  {name: "Silent", markdown: "**39 dB**", action: {functionCall: {call: "openUrl", args: {url: "https://example.com/silent"}}}},
  {name: "Eco", markdown: "**6.8 liters**", action: {functionCall: {call: "openUrl", args: {url: "https://example.com/eco"}}}}
])
</a2ui>''';
