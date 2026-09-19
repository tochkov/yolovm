Read-only static inspection on 17 September 2026 of the installed ChatGPT desktop app. No application files or configuration were modified.

Package: `chatgpt 26.908.70816` (from `dpkg-query`).

Archive: `/usr/lib/chatgpt/resources/app.asar`

Archive SHA-256: `bffe9bb51691ce8633208db9ceb6e215490084cdad2c19cf5a2658596169e571`

The archive's ordinary ASAR file table was read with Python. Relevant JavaScript files were copied to `/tmp/yolo-capability-research/app` for inspection. Offsets below are zero-based UTF-8 byte offsets within the extracted files, not within the archive.

| File inside archive | Byte offset | Observation |
| --- | ---: | --- |
| `webview/assets/app-initial-cf777d5420b1.js` | 2916763 | Renderer task configuration calls `mcp-codex-config` only for the `local` host; other hosts receive null from this function |
| `.vite/build/main-DaMR-wdT.js` | 1531707 | Main-process task configuration likewise calls `buildMcpCodexConfig` only for the `local` host |
| `.vite/build/main-DaMR-wdT.js` | 145944 | The unified browser/computer-use plugin provisioning block is conditional on `hostConfig.kind === local` |

Two short exact excerpts establish the local-host conditions:

```js
readCodexConfig:async e=>n===`local`?(await r(`mcp-codex-config`,{params:{cwd:e}})).config:null
```

```js
readCodexConfig:t=>e===`local`?c.buildMcpCodexConfig(t):Promise.resolve(null)
```

The definition of `buildMcpCodexConfig` includes the browser runtime configuration path. Related selection code configures the `chrome` and `iab` backends, app-bundled runtime paths, and the `cua_repl` plugin. This is app integration plumbing rather than a capability supplied by merely installing the standalone CLI remotely.

**Interpretation:** these paths do not automatically provide the local app's native browser integration to an arbitrary SSH task. This is evidence against assuming feature parity from Docker's documented SSH connection alone.

**Limit:** this is static inspection, not a runtime test. It is not an exhaustive proof that all alternative integration paths are absent, nor a claim about future releases. Public OpenAI documentation explicitly excludes the built-in Browser from standalone Codex CLI; Docker documents SSH coding integration without promising browser parity. Use those documented distinctions together with this build-specific evidence.

Sources: [OpenAI Browser](https://learn.chatgpt.com/docs/browser), [OpenAI SSH connections](https://learn.chatgpt.com/docs/remote-connections#connect-to-an-ssh-host), [Docker ChatGPT integration](https://docs.docker.com/ai/sandboxes/integrations/chatgpt/).
