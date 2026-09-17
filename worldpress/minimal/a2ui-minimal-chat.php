<?php
/**
 * Plugin Name: A2UI Minimal Chat
 * Description: Points AI Engine at a provider and publishes the chat page this site is built around.
 * Version: 0.1.0
 * Requires PHP: 8.1
 * Author: a2ui4w
 * License: GPLv2 or later
 */

// Provider credentials are never stored in this repository and never written to
// the database. start.mjs reads them from .env or the shell and hands them to
// Playground as --define, so they exist only as PHP constants for the lifetime
// of the server process:
//
//   A2UI_AI_TYPE      AI Engine environment type. Default 'openai'.
//   A2UI_AI_API_KEY   The provider API key.
//   A2UI_AI_ENDPOINT  Base URL, for A2UI_AI_TYPE=custom (a local model, say).
//   A2UI_AI_MODEL     Model id to answer with. Default: AI Engine's own.

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'A2UI_PAGE_SLUG', 'ai-chat' );
define( 'A2UI_PAGE_READY_OPTION', 'a2ui_minimal_page_ready' );

/**
 * The provider settings this boot was started with. Absent constants come back
 * as empty strings so callers can treat "unset" and "blank" alike.
 */
function a2ui_minimal_provider() {
	return [
		'type'     => defined( 'A2UI_AI_TYPE' ) ? (string) A2UI_AI_TYPE : 'openai',
		'apikey'   => defined( 'A2UI_AI_API_KEY' ) ? (string) A2UI_AI_API_KEY : '',
		'endpoint' => defined( 'A2UI_AI_ENDPOINT' ) ? (string) A2UI_AI_ENDPOINT : '',
		'model'    => defined( 'A2UI_AI_MODEL' ) ? (string) A2UI_AI_MODEL : '',
	];
}

/**
 * A key is enough for the hosted providers; a bare endpoint is enough for a
 * local OpenAI-compatible server, which usually wants no key at all.
 */
function a2ui_minimal_is_configured() {
	$provider = a2ui_minimal_provider();
	return $provider['apikey'] !== '' || $provider['endpoint'] !== '';
}

/**
 * Inject the provider into AI Engine's stored settings as they are read.
 *
 * Filtering the option rather than saving it keeps the key out of the database
 * even when AI Engine rewrites its settings row, and means a restart with a
 * different key needs no cleanup. AI Engine generates the environment ids and
 * picks the first environment as the default, so patching index 0 is enough to
 * make it the environment every chatbot falls back to.
 */
function a2ui_minimal_filter_options( $options ) {
	if ( ! is_array( $options ) || empty( $options['ai_envs'] ) || ! is_array( $options['ai_envs'] ) ) {
		return $options;
	}
	if ( ! a2ui_minimal_is_configured() ) {
		return $options;
	}

	$provider = a2ui_minimal_provider();

	$options['ai_envs'][0]['type'] = $provider['type'];
	$options['ai_envs'][0]['name'] = $provider['type'] === 'custom'
		? 'Custom (OpenAI-Compatible)'
		: ucfirst( $provider['type'] );

	if ( $provider['apikey'] !== '' ) {
		$options['ai_envs'][0]['apikey'] = $provider['apikey'];
	}
	if ( $provider['endpoint'] !== '' ) {
		$options['ai_envs'][0]['endpoint'] = $provider['endpoint'];
	}
	if ( $provider['model'] !== '' ) {
		$options['ai_default_model'] = $provider['model'];
	}

	return $options;
}
add_filter( 'option_mwai_options', 'a2ui_minimal_filter_options' );

/**
 * Keep the chatbot on the requested model.
 *
 * AI Engine stores chatbots separately from settings and defaults them to an
 * OpenAI model, which is the wrong guess as soon as the key belongs to someone
 * else. On a fresh site this filter sees an empty list and does nothing; AI
 * Engine then creates its default chatbot and every later read comes through
 * here patched.
 */
function a2ui_minimal_filter_chatbots( $chatbots ) {
	$provider = a2ui_minimal_provider();
	if ( $provider['model'] === '' || ! is_array( $chatbots ) ) {
		return $chatbots;
	}
	foreach ( $chatbots as &$chatbot ) {
		if ( is_array( $chatbot ) && ( $chatbot['botId'] ?? '' ) === 'default' ) {
			$chatbot['model'] = $provider['model'];
		}
	}
	return $chatbots;
}
add_filter( 'option_mwai_chatbots', 'a2ui_minimal_filter_chatbots' );

/**
 * Block markup for the chat page: a heading, a line of orientation, and the
 * AI Engine shortcode. Bare [mwai_chatbot] resolves to AI Engine's 'default'
 * chatbot, which it creates on first use, so no chatbot has to be set up first.
 */
function a2ui_minimal_page_content() {
	return implode( "\n\n", [
		'<!-- wp:heading {"level":1} -->' . "\n" . '<h1 class="wp-block-heading">Chat with AI</h1>' . "\n" . '<!-- /wp:heading -->',
		'<!-- wp:paragraph -->' . "\n" . '<p>This WordPress site is running entirely in WebAssembly on your machine. The replies below come from <a href="https://wordpress.org/plugins/ai-engine/">AI Engine</a> calling your AI provider.</p>' . "\n" . '<!-- /wp:paragraph -->',
		'<!-- wp:shortcode -->' . "\n" . '[mwai_chatbot]' . "\n" . '<!-- /wp:shortcode -->',
	] );
}

/**
 * Publish the chat page and make it the front page, once per site.
 */
function a2ui_minimal_ensure_front_page() {
	if ( get_option( A2UI_PAGE_READY_OPTION ) ) {
		return;
	}

	$existing = get_page_by_path( A2UI_PAGE_SLUG );
	$page_id  = $existing
		? $existing->ID
		: wp_insert_post( [
			'post_type'    => 'page',
			'post_status'  => 'publish',
			'post_title'   => 'Chat with AI',
			'post_name'    => A2UI_PAGE_SLUG,
			'post_content' => a2ui_minimal_page_content(),
		] );

	if ( is_wp_error( $page_id ) || ! $page_id ) {
		return;
	}

	update_option( 'show_on_front', 'page' );
	update_option( 'page_on_front', $page_id );
	update_option( A2UI_PAGE_READY_OPTION, $page_id );
}
add_action( 'init', 'a2ui_minimal_ensure_front_page' );

/**
 * Say what is missing, rather than letting the chat fail on its own terms.
 *
 * Without a provider the chat still renders and still accepts a message; the
 * failure only shows up as an error inside the message thread, which does not
 * hint at where the key belongs. Shown to admins only, so the notice cannot
 * leak setup details if this site is ever put somewhere public.
 */
function a2ui_minimal_setup_hint( $content ) {
	if ( a2ui_minimal_is_configured() || ! is_front_page() || ! current_user_can( 'manage_options' ) ) {
		return $content;
	}

	$notice = '<div style="border-left:4px solid #d63638;background:#fcf0f1;padding:12px 16px;margin:0 0 24px;">'
		. '<strong>No AI provider configured.</strong> The chat will load but cannot answer. '
		. 'Add a key to <code>worldpress/minimal/.env</code> and restart, or paste one into '
		. '<a href="' . esc_url( admin_url( 'admin.php?page=mwai_settings' ) ) . '">AI Engine &rsaquo; Settings</a> '
		. 'to try it out for this session.'
		. '</div>';

	return $notice . $content;
}
add_filter( 'the_content', 'a2ui_minimal_setup_hint' );

/**
 * The same warning in wp-admin, where someone who went looking for the settings
 * screen will already be.
 */
function a2ui_minimal_admin_notice() {
	if ( a2ui_minimal_is_configured() || ! current_user_can( 'manage_options' ) ) {
		return;
	}
	echo '<div class="notice notice-warning"><p>'
		. '<strong>A2UI Minimal Chat:</strong> no AI provider configured. '
		. 'Set <code>A2UI_AI_API_KEY</code> in <code>worldpress/minimal/.env</code> and restart the server, '
		. 'or enter a key below to use one just for this session.'
		. '</p></div>';
}
add_action( 'admin_notices', 'a2ui_minimal_admin_notice' );
