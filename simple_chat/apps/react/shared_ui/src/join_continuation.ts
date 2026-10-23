/** Ends a word, so a word that follows needs a space. */
const wordEnd = /[\p{L}\p{N}.,!?;:]$/u;

/** Starts a word. */
const wordStart = /^[\p{L}\p{N}]/u;

/**
 * Appends a resumed answer to the `partial` text it continues.
 *
 * The continuation is a new model turn, and a turn often starts without the
 * space that would separate it from the last word of `partial`, which would
 * run 'dedicated' and 'water' together. A pause in the middle of a word gets a
 * stray space instead, which is the less likely and less harmful mistake.
 *
 * Getting both cases right would mean asking the model to start by repeating
 * the last word of `partial`, then dropping the overlap from the stream. That
 * needs buffering until the repeated word has fully arrived, and a fallback for
 * when the model does not repeat it, which is more than these chats need.
 */
export function joinContinuation(partial: string, next: string): string {
  const needsSpace = wordEnd.test(partial) && wordStart.test(next);
  return needsSpace ? `${partial} ${next}` : partial + next;
}
