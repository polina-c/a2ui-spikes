#!/usr/bin/env node
/**
 * Boots the WordPress Playground server for this site.
 *
 * The only thing this adds over calling the Playground CLI directly is
 * credentials: it collects them from .env or the shell and passes them as PHP
 * constants, so no key ends up in blueprint.json, in git, or in the database.
 * Everything else is a flag you could type yourself; see README.md.
 */

import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const CLI = '@wp-playground/cli@3.1.54';

/** Settings a2ui-minimal-chat.php looks for, in the order it documents them. */
const FORWARDED = ['A2UI_AI_TYPE', 'A2UI_AI_API_KEY', 'A2UI_AI_ENDPOINT', 'A2UI_AI_MODEL'];

/** Enough .env parsing for KEY=value and quoted values. No dependency worth it. */
function readDotEnv(path) {
	if (!existsSync(path)) {
		return {};
	}
	const values = {};
	for (const rawLine of readFileSync(path, 'utf8').split('\n')) {
		const line = rawLine.trim();
		if (!line || line.startsWith('#')) {
			continue;
		}
		const separator = line.indexOf('=');
		if (separator < 1) {
			continue;
		}
		const name = line.slice(0, separator).trim();
		let value = line.slice(separator + 1).trim();
		if (/^(".*"|'.*')$/s.test(value)) {
			value = value.slice(1, -1);
		}
		values[name] = value;
	}
	return values;
}

const fromFile = readDotEnv(join(HERE, '.env'));
const provider = {};
for (const name of FORWARDED) {
	// The shell wins, so `A2UI_AI_MODEL=gpt-5 npm start` overrides .env for one run.
	const value = process.env[name] ?? fromFile[name];
	if (value) {
		provider[name] = value;
	}
}
// OPENAI_API_KEY is the variable people already have exported.
if (!provider.A2UI_AI_API_KEY && process.env.OPENAI_API_KEY) {
	provider.A2UI_AI_API_KEY = process.env.OPENAI_API_KEY;
}

if (!provider.A2UI_AI_API_KEY && !provider.A2UI_AI_ENDPOINT) {
	console.warn(
		'\n  No AI provider configured, so the chat will load but not answer.\n' +
			'  Copy .env.example to .env and fill in a key, or paste one into\n' +
			'  AI Engine > Settings once the site is up.\n'
	);
}

const args = [
	'--yes',
	CLI,
	'server',
	`--blueprint=${join(HERE, 'blueprint.json')}`,
	// Consent for the blueprint to read a2ui-minimal-chat.php next to itself.
	'--blueprint-may-read-adjacent-files',
	'--login',
	// Anything after `npm start --` reaches the CLI, e.g. `-- --port 9500`.
	...process.argv.slice(2),
];
for (const [name, value] of Object.entries(provider)) {
	args.push('--define', name, value);
}

const child = spawn('npx', args, { cwd: HERE, stdio: 'inherit' });
child.on('exit', (code, signal) => process.exit(signal ? 1 : (code ?? 0)));
