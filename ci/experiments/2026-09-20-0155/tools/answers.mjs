/**
 * What Jane answers, and how the landing page button is recognised.
 *
 * Jane has a plumbed kitchen with a 60 cm gap, a household of two, no open-plan
 * noise problem, and she cares about what the machine costs to run rather than
 * what it costs on the day. Following the knowledge base, that is the Eco.
 *
 * Each rule is tied to the question it answers with `when`, and only then picks
 * between the options with `want` and `avoid`. Matching on the options alone is
 * not enough: "On the countertop (no plumbing)" contains "no", which reads like
 * an answer to the question about noise.
 */
export const ANSWERS = [
  {
    name: 'where it goes',
    when: /where|install|plumb|counter|fitted|connect|drain|kitchen have/i,
    want: /under|fitted|built|plumbed|cabinet|permanent|water line|water and drain/i,
    avoid: /countertop|counter top|rent|portable|tank|studio|no plumbing/i,
  },
  {
    name: 'gap width',
    when: /45|60|gap|width|wide|how wide|cabinets leave/i,
    want: /\b60\b/,
    avoid: /\b45\b/,
  },
  {
    name: 'household size',
    when: /people|household|how many|eat|loads|dishes|cycles|pile up|often/i,
    want: /1\s*[–-]\s*4|1 to 4|up to 4|once (a day|daily)|\btwo\b|\bthree\b|couple|fewer|smaller/i,
    avoid: /5\s*\+|5 or more|\bfive\b|twice|lots of cooking|heavily|large/i,
  },
  {
    name: 'noise and night cycles',
    when: /quiet|noise|open plan|open space|night|sleep|televis|bedroom|living/i,
    want: /\bno\b|not really|closed|separate|daytime|during the day|standard kitchen/i,
    avoid: /\byes\b|open|night|bedroom|living|quiet/i,
  },
  {
    name: 'price against running cost',
    when: /price|cost|running|water|energy|care about|matters more|day, or/i,
    want: /running cost|water and (power|electricity)|energy use|consumption|efficien|bills|long run|afterwards|over time|less water/i,
    avoid: /\bprice\b|cheapest|upfront|on the day|budget|today|purchase/i,
  },
];

/** A landing page button reads like a link, or names the product. */
export const LANDING = /^(see|view|open the|visit|shop|buy|go to|learn more|read)\b/i;
export const PRODUCT = /just shining/i;

/** Buttons that are part of the app, not answers the assistant offered. */
export const CHROME = /^(send|change model|start the chat|enable accessibility)$/i;

/**
 * Picks Jane's answer. Rules whose question does not match are skipped, and a
 * rule only decides when it singles out exactly one option.
 */
export function choose(labels, question) {
  const applicable = ANSWERS.filter(r => r.when.test(question));
  for (const rule of applicable.length > 0 ? applicable : ANSWERS) {
    const hits = labels
      .map((l, i) => [l, i])
      .filter(([l]) => rule.want.test(l) && !rule.avoid.test(l));
    if (hits.length === 1) return {index: hits[0][1], rule: rule.name};
  }
  return {index: -1, rule: null};
}
