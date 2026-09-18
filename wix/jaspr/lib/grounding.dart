/// What the assistant is allowed to say, and how it is kept honest.
///
/// This is plain Dart with no browser in it, which is the point: everything
/// here decides what goes into a request or what comes back out of one, and
/// all of it is checked by `test/grounding_test.dart` without loading a
/// model. The rules are the ones measured for the vanilla widget in
/// [`wix/minimal`](../../minimal/README.md); this is a port, not a redesign.
library;

/// One thing the assistant knows about the business.
///
/// Keep each entry to one subject and give it a title that names that
/// subject: the title is what gets matched when there is more content than
/// fits in a single request.
class KnowledgeEntry {
  /// Creates a [KnowledgeEntry].
  const KnowledgeEntry({required this.title, required this.text});

  /// What the entry is about, in a few words.
  final String title;

  /// The facts themselves, in plain sentences.
  final String text;
}

/// Characters of site content sent with a question.
///
/// The models this site runs have a 4096 token window, and this leaves room
/// for the conversation and the answer. Content under this size is sent
/// whole; above it, the entries closest to the question are picked.
const int knowledgeBudget = 6000;

/// Turns of history sent to the model, not counting the system message.
///
/// A long chat would otherwise overrun the same 4096 token window.
const int maxHistory = 12;

/// Wrapped around the site content before it is handed to the model.
///
/// The models are small enough to invent business details when asked, so
/// they are told to answer from the text or not at all. This reduces the
/// inventing; [inventedContactDetail] is what catches the rest.
const String groundingInstruction =
    'Answer using only the information about this business given below. If '
    'the answer is not in it, say you do not have that information and '
    'suggest getting in touch through the site. Never invent prices, hours, '
    'addresses, links or policies.';

/// Shown instead of an answer that invented a way to contact the business.
const String withheldAnswer =
    "I don't have that detail. Please use the contact details on this site.";

/// Words too common to say anything about what a question is asking.
const Set<String> _stopwords = {
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'but', 'by', 'can', 'did', 'do',
  'does', 'for', 'from', 'get', 'give', 'has', 'have', 'how', 'i', 'in', 'is',
  'it', 'me', 'much', 'my', 'of', 'on', 'or', 'that', 'the', 'there', 'they',
  'this', 'to', 'was', 'we', 'what', 'when', 'where', 'which', 'who', 'why',
  'will', 'with', 'you', 'your',
};

/// The shapes a contact detail comes in.
///
/// Contact details are the one class of invention that can be checked rather
/// than discouraged: the model has no legitimate source for a phone number,
/// an email address or a link that is not in the site content, so anything
/// of that shape which does not appear there was made up.
enum _ContactShape {
  email(r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'),
  link(r"""\b(?:https?://|www\.)[^\s<>"')\]]+"""),
  phone(r'\+?\d[\d\s().-]{5,}\d');

  const _ContactShape(this._pattern);

  final String _pattern;

  RegExp get regExp => RegExp(_pattern, caseSensitive: false);
}

/// The words in [text] worth matching a question against.
List<String> keywords(String text) {
  return <String>{
    for (final RegExpMatch match
        in RegExp(r"[a-z0-9']+").allMatches(text.toLowerCase()))
      match[0]!,
  }.where((String word) => word.length > 2 && !_stopwords.contains(word)).toList();
}

/// How well [entry] answers [question].
///
/// How many of the question's words the entry contains, with a word in the
/// title counting double, because a title names the subject and a body can
/// mention it in passing.
int relevance(KnowledgeEntry entry, String question) {
  final List<String> asked = keywords(question);
  if (asked.isEmpty) return 0;

  final String title = ' ${entry.title.toLowerCase()} ';
  final String body = ' ${entry.text.toLowerCase()} ';
  int score = 0;
  for (final String word in asked) {
    if (title.contains(word)) {
      score += 2;
    } else if (body.contains(word)) {
      score += 1;
    }
  }
  return score;
}

/// The entries as the model sees them.
String renderEntries(Iterable<KnowledgeEntry> entries) {
  return entries
      .map((KnowledgeEntry e) => e.title.isEmpty ? e.text : '${e.title}\n${e.text}')
      .join('\n\n');
}

/// The site content to send with [question], within [budget] characters.
///
/// A small site fits whole, and sending everything beats picking wrongly.
/// A larger one falls back to the entries that match the question, taken
/// best first until the budget is used up, and then put back in the order
/// they were written so the model reads them as a document.
String contextFor(
  List<KnowledgeEntry> entries,
  String question, {
  int budget = knowledgeBudget,
}) {
  final List<KnowledgeEntry> usable =
      entries.where((KnowledgeEntry e) => e.text.isNotEmpty).toList();
  if (usable.isEmpty) return '';

  final String whole = renderEntries(usable);
  if (whole.length <= budget) return whole;

  final List<(int, KnowledgeEntry)> ranked = usable.indexed.toList()
    ..sort((a, b) {
      final int byScore =
          relevance(b.$2, question).compareTo(relevance(a.$2, question));
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });

  final List<(int, KnowledgeEntry)> picked = <(int, KnowledgeEntry)>[];
  int used = 0;
  for (final (int, KnowledgeEntry) candidate in ranked) {
    // The 40 covers the title and the blank line between entries.
    final int size = candidate.$2.text.length + 40;
    if (used + size > budget) continue;
    picked.add(candidate);
    used += size;
  }
  picked.sort((a, b) => a.$1.compareTo(b.$1));
  return renderEntries(picked.map((entry) => entry.$2));
}

String _digitsOf(String text) => text.replaceAll(RegExp(r'\D+'), '');

/// The first contact detail in [answer] that is absent from [source], or
/// null when every one of them checks out.
///
/// Measured on the vanilla widget: Qwen2.5-0.5B invented a phone number
/// under every system prompt tried, and Llama-3.2-1B invented a named
/// employee. Wording alone does not stop it, so an answer that fails this
/// check is replaced with [withheldAnswer] rather than shown.
///
/// Prices, hours and street numbers are deliberately not checked: they are
/// too short to tell from any other number, and the grounding instruction is
/// what covers them. Seven digits is the shortest run treated as a number
/// someone could call, which is one digit shorter than the vanilla widget
/// manages: its pattern needs eight characters to match at all, and
/// Qwen2.5-0.5B was watched answering "Your phone number is 5364217" through
/// it.
String? inventedContactDetail(String answer, String source) {
  final String haystack = source.toLowerCase();
  final String sourceDigits = _digitsOf(source);

  for (final _ContactShape shape in _ContactShape.values) {
    for (final RegExpMatch match in shape.regExp.allMatches(answer)) {
      final String token = match[0]!;
      if (shape == _ContactShape.phone) {
        final String digits = _digitsOf(token);
        if (digits.length >= 7 && !sourceDigits.contains(digits)) return token;
      } else if (!haystack.contains(token.toLowerCase())) {
        return token;
      }
    }
  }
  return null;
}
