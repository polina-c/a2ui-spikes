# WebMCP: overview, adopters, code (as of 2026-10-10)

## The protocol in one paragraph

WebMCP lets a web page expose its own functionality as **tools** (name + description + JSON Schema input + JS callback) that an AI agent running *in the browser* (built-in assistant, extension, or automation framework) can discover and call. It borrows MCP's tool concept but is **not** the MCP wire protocol: there is no server, no JSON-RPC, no transport. Tools run in the page's JS, inside the user's session (cookies, auth, UI state), so the agent calls `add_to_cart({sku})` instead of clicking pixels. Spec status: W3C Web Machine Learning Community Group *Draft Community Group Report* (draft dated 9 Oct 2026), not a W3C standard.

Two ways to expose tools:
1. **Imperative** (JS): `document.modelContext.registerTool({...})`.
2. **Declarative** (HTML): `toolname` / `tooldescription` / `toolparamdescription` attributes on a `<form>`; the browser derives the schema. Still explainer-only, may change.

### API surface (current draft)

- `document.modelContext` (SecureContext). Older code uses `navigator.modelContext`, deprecated in Chrome 150 but still shipped during the origin trial.
- Page-side: `registerTool(tool, { signal })`. No `unregisterTool()`; abort the signal to remove a tool.
- Agent-side: `getTools()`, `executeTool()`.
- Events: `toolchange`, `toolactivated`, `toolcancel`.
- Tool fields: `name`, `title`, `description`, `inputSchema`, `execute(input, { signal })`, `annotations`.
- Annotations: `readOnlyHint`, `untrustedContentHint`, `consequentialHint`, `debugging`.
- Removed in Mar 2026: `provideContext()` / `clearContext()`. Many 2025 tutorials still show them.

Sources: [spec draft](https://webmachinelearning.github.io/webmcp/), [explainer](https://github.com/webmachinelearning/webmcp/blob/main/README.md), ["The API moved" summary](https://mcpplaygroundonline.com/blog/what-is-webmcp)

### Browser and agent support

- **Chrome:** origin trial (149 to 156), aiming to ship in 157. For local hacking, enable `chrome://flags/#enable-webmcp-testing`. ([chromestatus](https://chromestatus.com/feature/5117755740913664))
- **Edge:** origin trial. ([announcement](https://blogs.windows.com/msedgedev/2026/09/21/new-in-edge-for-developers-create-better-components-and-make-your-site-agent-ready/), [webmcp-labs](https://github.com/MicrosoftEdge/webmcp-labs))
- **Brave:** behind a flag.
- **Firefox:** neutral position. ([position](https://github.com/mozilla/standards-positions/issues/1412))
- **Safari/WebKit:** opposed. ([position](https://github.com/WebKit/standards-positions/issues/670))
- **Agents that call WebMCP tools today:** ChatGPT desktop app and ChatGPT cloud browser, Vercel agent-browser, Stagehand. Behind flags: Chrome DevTools MCP, Puppeteer. Claude for Chrome: no support yet.
- Source for this list: [webmcp.com ecosystem tracker](https://webmcp.com/ecosystem-tracker) (updated 1 Oct 2026). This is a third-party tracker run by a vendor (nekuda), so treat its statuses as reported rather than verified.

## Adopters

### Open source (code you can read)

- **GoogleChromeLabs/webmcp-tools.** About 15 official demos (bistro, flight search in React, pizza maker, hotel chain, Angular sport shop, smart home, page-agent, and more) plus the [Model Context Tool Inspector](https://github.com/beaufortfrancois/model-context-tool-inspector) extension. [repo](https://github.com/GoogleChromeLabs/webmcp-tools), [demo list](https://github.com/GoogleChromeLabs/webmcp-tools/blob/main/AWESOME_WEBMCP.md)
- **MicrosoftEdge/webmcp-labs.** [repo](https://github.com/MicrosoftEdge/webmcp-labs)
- **MCP-B** (Alex Nahas): polyfill `@mcp-b/webmcp-polyfill`, an extension, and examples. It was the origin of the idea. [org](https://github.com/WebMCP-org), [polyfill README](https://cdn.jsdelivr.net/npm/@mcp-b/webmcp-polyfill@2.2.0/README.md)
- **Community demo sites with source:**
  - Shoe store: [live](https://andreinwald.github.io/webmcp-demo/), [code](https://github.com/andreinwald/webmcp-demo)
  - Blackjack: [code](https://github.com/happyhj/webmcp-blackjack)
  - WebMCP Flow: [code](https://github.com/ttimur-dev/webmcp-flow)
  - Air-bird booking: [code](https://github.com/hugozanini/air-bird-booking-web-mcp)
  - Wordup: [code](https://github.com/GoogleChromeLabs/web-ai-demos/tree/main/wordup)
  - WSG experiment: [site](https://mgifford.github.io/wsg-webmcp-experiment/)
- **Platform plugins:**
  - Shopware storefront plugin: [repo](https://github.com/agentic-commerce-lab/webmcp-plugin)
  - "Open for Agents" WordPress plugin (WP.org plugins are GPL): [plugin](https://wordpress.org/plugins/open-for-agents-ai-toolkit-with-mcp/)
- **Libraries:**
  - [agentk](https://github.com/stevysmith/agentk), a cmdk fork
  - [use-webmcp-tool](https://www.npmjs.com/package/use-webmcp-tool), a React hook
  - [webmcp-types](https://www.npmjs.com/package/webmcp-types), TypeScript types
  - Angular is listed as "offers tools" on the tracker.

Caveat: almost all of these are **demos or tooling**. I didn't find a well-known open-source *production* web app (for example, a big OSS SaaS) shipping WebMCP tools to its users.

### Closed source / commercial

- **Shopify:** the biggest real deployment. Since 5 Aug 2026, every Liquid storefront plus the Hydrogen preview exposes these tools, on by default:
  - Catalog: `search_catalog`, `browse_store`, `get_product`, `show_variant`
  - Cart: `get_cart`, `update_cart`, `cancel_cart`
  - Checkout and orders: `proceed_to_checkout`, `manage_orders`
  - Other: `search_shop_policies_and_faqs`

  Sources: [changelog](https://shopify.dev/changelog/webmcp-liquid-hydrogen), [tool docs](https://shopify.dev/docs/api/web-mcp)
- **Smaller sites and products** listed as exposing tools:
  - [Stacktree](https://stacktr.ee)
  - [isainative.dev](https://isainative.dev/)
  - [WordLift AI Audit](https://audit.wordlift.io/)
  - [jsonstat.com/webmcp](https://jsonstat.com/webmcp/)
  - [Conscriba](https://conscriba.com/), [Latch](https://latch.tools) (auto-generate tools for a site)
  - Meta AI on Ray-Ban Display, for web apps: "coming soon" ([docs](https://wearables.developer.meta.com/docs/develop/webapps/agent-tools))
- Adoption by other big brands is thin. I found commentary pieces but no first-party announcements. A Feb 2026 freeCodeCamp piece was literally titled ["Shipping a 0% Adoption Standard"](https://www.freecodecamp.org/news/a-developers-guide-to-webmcp/).

## What the code looks like

Imperative (current API, from the draft and the playground summary):

```js
const mc = document.modelContext ?? navigator.modelContext; // fallback for older Chrome
if (mc) {
  const ac = new AbortController();
  await mc.registerTool({
    name: 'find_order',
    description: 'Look up a customer order by its ID.',
    inputSchema: {
      type: 'object',
      properties: { orderId: { type: 'string', description: 'The order ID' } },
      required: ['orderId'],
    },
    annotations: { readOnlyHint: true },
    async execute({ orderId }, { signal }) {
      const order = await fetch(`/api/orders/${orderId}`, { signal }).then(r => r.json());
      return JSON.stringify(order);
    },
  }, { signal: ac.signal });
  // ac.abort() to unregister (e.g. on route change)
}
```

Declarative:

```html
<form toolname="requestSupport" tooldescription="Open a support request." action="/support">
  <input type="text" name="name">
  <select name="team" required toolparamdescription="Which team should handle this.">
    <option value="billing">Billing</option>
    <option value="shipping">Shipping</option>
  </select>
  <button type="submit">Send</button>
</form>
```

## How to start hacking

1. Use Chrome 149 or later and enable `chrome://flags/#enable-webmcp-testing`.
2. Install the [Model Context Tool Inspector](https://github.com/beaufortfrancois/model-context-tool-inspector) to list and call tools on any page.
3. Open a Chrome Labs demo, or any Shopify storefront, and poke at the tools.
4. Clone [webmcp-tools](https://github.com/GoogleChromeLabs/webmcp-tools) and add a tool to a demo.
5. To drive tools from an agent, use [Vercel agent-browser](https://agent-browser.dev/webmcp) or [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/src/tools/webmcp.ts).

## Best reading, in order

1. [Explainer](https://github.com/webmachinelearning/webmcp/blob/main/README.md): the why, plus examples.
2. [Spec draft](https://webmachinelearning.github.io/webmcp/): the exact IDL.
3. [Chrome early preview post](https://developer.chrome.com/blog/webmcp-epp)
4. [awesome-webmcp (official CG list)](https://github.com/webmachinelearning/awesome-webmcp)
5. [Ecosystem tracker](https://webmcp.com/ecosystem-tracker): who supports what.
