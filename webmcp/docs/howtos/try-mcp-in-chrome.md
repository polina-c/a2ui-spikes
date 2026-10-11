# Try WebMCP in Chrome with a coding agent (as of 2026-10-10)

This guide connects Claude Code to Chrome through [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp). It lets the agent list and call the WebMCP tools a page registers. Any MCP client works the same way (Cursor, Gemini CLI, Copilot), only the command in step 1 changes.

Tested on macOS with Chrome 154 and Node 25.

## 1. Add the Chrome DevTools MCP server

```bash
claude mcp add chrome-devtools --scope user -- npx -y chrome-devtools-mcp@latest \
  --categoryExperimentalWebmcp=true \
  --chromeArg=--enable-features=WebMCP
```

- `--categoryExperimentalWebmcp=true` turns on the two WebMCP tools, `list_webmcp_tools` and `execute_webmcp_tool`. They are off by default.
- `--chromeArg=--enable-features=WebMCP` turns on WebMCP in the Chrome window the server opens.
  - The Chrome Labs demos work without it, because they include an origin-trial token for their own domain.
  - Your own pages on `localhost` don't.
- `--scope user` makes the server available from any folder.
  - Without it, the server is added only for the folder you ran the command in.
  - If you ran it from `~`, it won't show up in your project.

All server flags are listed in the [configuration guide](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/configuration.md).

## 2. Restart and check

1. Start a new Claude Code session.
2. Run `/mcp` and check that `chrome-devtools` shows as connected.

The first time it's used, the server opens a **separate Chrome window**. It has its own profile in `~/.cache/chrome-devtools-mcp/`, so your normal profile isn't touched and you're logged out of everything there.

## 3. Try it on the demos

Give Claude these prompts one at a time:

1. "Open https://googlechromelabs.github.io/webmcp-tools/demos/french-bistro/ and list its WebMCP tools."
   - You should see `book_table_le_petit_bistro`, with a schema for name, phone, date, time, guests and seating.
   - The bistro builds this tool from HTML (`<form toolname=…>`).
2. "Book a table for 2 tomorrow at 19:30 on the terrace for Test User, phone 5551234567. Use the WebMCP tool, don't click the page."
   - Watch the form fill itself in the Chrome window.
3. "Now open https://googlechromelabs.github.io/webmcp-tools/demos/pizza-maker/ and make me a large BBQ pizza."
   - This demo registers its tools from JavaScript.

Tell the agent to use WebMCP. Otherwise it may fall back to clicking and filling the page through DevTools.

More demos: [Awesome WebMCP](https://github.com/GoogleChromeLabs/webmcp-tools/blob/main/AWESOME_WEBMCP.md).

## 4. Try a page of your own

1. Save this as `index.html`:

   ```html
   <!doctype html>
   <meta charset="utf-8">
   <title>WebMCP hello</title>
   <h1>Counter: <span id="count">0</span></h1>
   <script>
     let count = 0;
     document.modelContext.registerTool({
       name: "increment_counter",
       description: "Increase the counter on the page by the given amount.",
       inputSchema: {
         type: "object",
         properties: { amount: { type: "number", description: "How much to add" } },
         required: ["amount"],
       },
       async execute({ amount }) {
         count += amount;
         document.getElementById("count").textContent = count;
         return { content: [{ type: "text", text: `Counter is now ${count}` }] };
       },
     });
   </script>
   ```

2. Serve it from the same folder: `python3 -m http.server 8765`
3. Ask: "Open http://localhost:8765 and increment the counter by 5 using its WebMCP tool."
4. The tool should return `Counter is now 5`.

Use `document.modelContext`, not `navigator.modelContext`. Many tutorials still use the old name. With the setup above, a page that used `navigator.modelContext` registered no tools. The official demos also load a [small polyfill](https://github.com/GoogleChromeLabs/webmcp-tools/blob/main/demos/shared/webmcp-polyfill.js) as a fallback.

## Troubleshooting

- **`chrome-devtools` is missing from `/mcp`:** the server was probably added for a different folder.
  - Run `claude mcp list` in your project folder to check.
  - If it's not there, run `claude mcp remove chrome-devtools` from the folder where you added it.
  - Then add it again with `--scope user`.
- **"No WebMCP tools available" on localhost:** the Chrome flag isn't reaching the browser.
  - Check the server args with `claude mcp get chrome-devtools`.
  - Close any Chrome window left over from an earlier run with different flags. The server reuses it.
- **No WebMCP tools listed in `/mcp`:** `--categoryExperimentalWebmcp=true` is missing.
- **Using your everyday Chrome instead:**
  - Enable `chrome://flags/#enable-webmcp-testing` there.
  - Connect with `--autoConnect` (see the configuration guide).
  - I haven't tested this path.
