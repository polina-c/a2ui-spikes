/**
 * What Jane answers.
 *
 * Jane has a plumbed kitchen with a 60 cm gap and a household of five, and
 * her kitchen is open to the living room. She tells the assistant about the
 * kitchen only after pausing an answer, which is how every video shows pause
 * and resume.
 *
 * Each rule is one of the assistant's questions. When the assistant offers
 * options, a rule picks one with `want` and `avoid`, and a rule decides only
 * when it singles out exactly one option. When the assistant offers none, Jane
 * types the `reply` of the next rule that has one. `pause` is the context she
 * adds after pausing the answer to that rule.
 *
 * Adapted from ci/experiments/2026-09-20-0155/tools/answers.mjs.
 */
export const PERSONA = [
  {
    name: 'where it goes',
    want: /under|fitted|built|plumbed|water line|water and drain|drain/i,
    avoid: /countertop|counter top|rent|portable|tank|studio|no plumbing/i,
    reply:
      'It goes under the counter in my own kitchen. There is a water ' +
      'connection and a drain.',
  },
  {
    name: 'gap width',
    want: /\b60\b/,
    avoid: /\b45\b/,
    reply: 'I measured it: the gap is 60 cm.',
  },
  {
    name: 'household size',
    want: /5\s*\+|5 or more|\bfive\b|more than four|large|big/i,
    avoid: /1\s*[–-]\s*4|1 to 4|up to 4|\btwo\b|\bthree\b|couple|fewer|small/i,
    reply: 'We are five people and we cook at home every day.',
    pause: 'Also, the kitchen is open to the living room.',
  },
  {
    name: 'noise and night cycles',
    want: /\byes\b|open|living|quiet/i,
    avoid: /\bno\b|closed|separate|not an issue|standard/i,
  },
  {
    name: 'price against running cost',
    want: /\bprice\b|upfront|on the day|cheap|budget/i,
    avoid: /running|water|energy|consumption|efficien/i,
  },
];

/**
 * A button that opens a landing page reads like a link, or names the product,
 * and it means the assistant has made its recommendation.
 */
export const LANDING = /^(see|view|open|visit|shop|buy|order|go to|learn more|read)\b|just shining/i;

/** Buttons that belong to the app, not options the assistant offered. */
export const CONTROLS =
  /^(send|pause|resume|cancel|send and resume|scroll left|scroll right|select|enable accessibility)$/i;

/**
 * Picks Jane's answer among [options], from the rules she has not used yet.
 *
 * Returns the rule and the index of the option, or an index of -1 when no
 * rule singles one out.
 */
export function choose(options, used) {
  for (const rule of PERSONA.filter(r => !used.has(r))) {
    const hits = options
      .map((label, index) => [label, index])
      .filter(([label]) => rule.want.test(label) && !rule.avoid.test(label));
    if (hits.length === 1) return {rule, index: hits[0][1]};
  }
  return {rule: null, index: -1};
}
