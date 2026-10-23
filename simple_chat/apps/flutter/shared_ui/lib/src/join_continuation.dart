/// Ends a word, so a word that follows needs a space.
final RegExp _wordEnd = RegExp(r'[\p{L}\p{N}.,!?;:]$', unicode: true);

/// Starts a word.
final RegExp _wordStart = RegExp(r'^[\p{L}\p{N}]', unicode: true);

/// Appends a resumed answer to the [partial] it continues.
///
/// The continuation is a new model turn, and a turn often starts without the
/// space that would separate it from the last word of [partial], which would
/// run 'dedicated' and 'water' together. A pause in the middle of a word gets
/// a stray space instead, which is the less likely and less harmful mistake.
///
/// Getting both cases right would mean asking the model to start by repeating
/// the last word of [partial], then dropping the overlap from the stream. That
/// needs buffering until the repeated word has fully arrived, and a fallback
/// for when the model does not repeat it, which is more than these chats need.
String joinContinuation(String partial, String next) {
  final bool needsSpace =
      _wordEnd.hasMatch(partial) && _wordStart.hasMatch(next);
  return needsSpace ? '$partial $next' : '$partial$next';
}
