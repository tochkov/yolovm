Research checked on 17 September 2026. This follow-up applies the clarified requirement: preserve the vendors' native desktop/browser experience, authenticated browser sessions, and a general-purpose computer that agents can operate. It supersedes the coding-first recommendation in `YOLO_RESEARCH.md` for this use case.

**Recommendation: use a complete desktop VM as the primary environment for Codex and Claude Code. Stock Docker Sandboxes does not establish equivalent native browser/desktop capability. It remains useful for CLI work, and some native-browser combinations are possible, but they must be evaluated individually.**

This assessment combines current OpenAI, Anthropic, and Docker documentation with read-only inspection of the ChatGPT app installed here. It is not a live Docker Sandbox compatibility test. No sandbox, guest, authentication, or host configuration was changed.

The distinction that matters is between the model, the agent runtime, the interface, and the tools connected to that runtime. Running the same model and CLI in a microVM does not automatically supply the browser profile, app-owned tools, native messaging integration, display server, or desktop session. Conversely, a CLI can have sophisticated native integrations. “CLI” alone does not imply reduced capability.

| Arrangement | Evidence for the required capabilities | Decision for this project |
| --- | --- | --- |
| Stock `sbx run codex` | Codex CLI runs; OpenAI explicitly excludes its built-in Browser from standalone CLI | Insufficient by itself |
| ChatGPT app outside `sbx`, remote Codex inside | SSH integration documented; app-native browser parity is not established, and installed app code has local-only integration paths | Do not assume equivalent to a local desktop-app task |
| Stock `sbx run claude` | Real Claude Code CLI, whose official Chrome integration supports remote scenarios | Browser still needs pairing, suitable authentication, network access, and an actual browser somewhere |
| Claude Desktop outside `sbx`, Claude Code inside | Docker documents SSH connection; Anthropic documents remote execution | Useful candidate, but not proof every desktop tool is available or inside the sandbox |
| Desktop apps and Chrome installed inside a custom `sbx` GUI environment | Docker exposes graphical-display configuration; no turnkey recipe validating this combination was established | Possible engineering project; simplification unproven |
| Desktop apps, Claude CLI, Chrome, and projects inside one complete VM | Co-locates the normal vendor integrations and their browser/desktop resources | Best architectural match, subject to Linux product limitations and normal integration testing |

**OpenAI's browser belongs to the desktop experience.** Its current Browser documentation explicitly says it is unavailable in Codex CLI and the IDE extension. The desktop browser has its own profile and supports agent interaction. The browser extension connects the desktop app to supported external browsers. These are distinct from merely installing Chromium or adding an unrelated browser automation server. [Browser](https://learn.chatgpt.com/docs/browser), [browser extension](https://learn.chatgpt.com/docs/chrome-extension).

Docker's Codex recipe launches the CLI. Its separate ChatGPT integration connects the external desktop app over SSH to a remote `codex` executable. This confirms remote coding support; it does not say that the desktop app, its browser profile, or native browser tools move into the microVM. [Docker Codex integration](https://docs.docker.com/ai/sandboxes/agents/codex/), [Docker ChatGPT integration](https://docs.docker.com/ai/sandboxes/integrations/chatgpt/).

There is also concrete local evidence against casually promising parity. Installed package `chatgpt` is version `26.908.70816`. In its packaged JavaScript, both renderer and main-process task configuration paths request app-owned Codex configuration only for a `local` host. Browser runtime configuration is part of that app-owned configuration, and the unified browser/computer-use plugin provisioning path also has a local-host condition. Details and reproducible file identifiers are in [APP_BROWSER_EVIDENCE.md](APP_BROWSER_EVIDENCE.md).

This is static evidence about the normal integration in this installed build. It does not prove that every remote path, later build, or manually configured bridge is impossible. It does mean that “the app connects to SSH” is insufficient grounds for treating `@Browser` and `@Chrome` as available to the remote agent. A visible browser pane that the human can open is also not proof that the remote task has browser-control tools.

**Claude Code is different.** The CLI's official `--chrome` integration controls an ordinary visible browser and its signed-in sessions. Current documentation requires a direct Anthropic plan and `/login`; API keys and `setup-token` credentials do not enable this feature. Thus successful model authentication is not sufficient evidence of browser eligibility. [Claude Code with Chrome](https://code.claude.com/docs/en/chrome).

The integration is not exclusively a same-machine Unix-socket arrangement. Anthropic's network reference lists the extension's WebSocket bridge at `bridge.claudeusercontent.com`, and its changelog records fixes for Chrome uploads from remote sessions. This rules out an absolute claim that a sandboxed or remote Claude CLI cannot use native Chrome. [Network reference](https://code.claude.com/docs/en/network-config), [changelog](https://code.claude.com/docs/en/changelog).

However, I did not establish a vendor-validated recipe for the precise combination of current Docker `sbx`, Claude OAuth, and your intended browser placement. The responsible classification is a plausible native integration requiring a targeted test. It is not a Playwright substitution. Anthropic exposes its own Chrome feature through MCP internally; protocol naming does not make it a generic replacement for the native feature.

The browser's location remains decisive. If the CLI is inside `sbx` but Chrome runs on Atlas, browser actions happen on Atlas. If Chrome runs inside a separate desktop VM, those actions happen there. If everything must be contained in `sbx`, it needs its own browser and usable graphical session. Browser access through a relay does not change any of these locations.

Consequently, sandbox shell networking cannot be assumed to constrain an external browser. A browser on Atlas can reach whatever Atlas can reach, even when the coding microVM cannot. File uploads and downloads also cross different filesystems in a split arrangement. A separate browser profile can separate cookies, but it does not put that browser process inside the microVM's operating-system boundary.

**Claude Desktop adds its own features rather than simply displaying CLI text.** Current documentation describes a built-in Browser pane, external browsing, SSH sessions, and differences from CLI capabilities. Linux now has an official desktop beta. Docker explicitly supports connecting that desktop app to a Claude sandbox; its guide also notes a token-refresh connection issue and that desktop credentials enter the sandboxed Claude process. These are reasons to test the actual integration instead of extrapolating from SSH login alone. [Claude Desktop](https://code.claude.com/docs/en/desktop), [Linux beta](https://code.claude.com/docs/en/desktop-linux), [Docker Claude Desktop integration](https://docs.docker.com/ai/sandboxes/integrations/claude-desktop/).

Do not infer a universal “desktop is more capable than CLI” ordering. Anthropic's current comparison, for example, lists CLI agent teams separately from desktop session management. Native-browser requirements, scripting requirements, and UI convenience can point toward different interfaces. Keeping both the app and CLI inside one VM lets you select the appropriate interface without splitting the computer they use.

**Remote control names describe different operations.**

| Feature | What it does | What it does not establish |
| --- | --- | --- |
| OpenAI desktop SSH projects | Uses a remote Codex app server for files and commands | Native browser/desktop tool parity over SSH |
| OpenAI Remote | Lets another supported device control a desktop-app host and its tools | Linux-host support; current guide specifies macOS/Windows hosts |
| Claude Remote Control | Lets web/mobile steer the existing CLI/VS Code execution environment | Installing a browser or desktop into that environment |
| Claude Desktop SSH | Runs Claude Code on a remote Linux/macOS machine through the desktop UI | That all graphical tools run remotely |
| Claude cloud sessions | Run in the selected cloud environment | That work remains in your local VM |
| SPICE/RDP/VNC access to a guest | Lets you view and operate the guest's desktop | Automatic agent-task recovery after a reboot |

OpenAI documents desktop-host Remote separately from SSH, including that mobile setup cannot be done from the CLI. Docker expressly supports Claude Remote Control after `sbx settings set claude.remoteControl true`; Claude requires eligible subscription login and supporting service access. Keep the underlying machine/process alive independently of the remote interface. [OpenAI remote connections](https://learn.chatgpt.com/docs/remote-connections), [Claude Remote Control](https://code.claude.com/docs/en/remote-control), [Docker Claude configuration](https://docs.docker.com/ai/sandboxes/agents/claude-code/), [Claude cloud sessions](https://code.claude.com/docs/en/claude-code-on-the-web).

**A full Linux VM still has product limitations.** OpenAI's Linux app does not yet provide native whole-desktop Computer Use. Anthropic's Linux desktop beta also lacks that feature; Claude CLI's built-in computer-use feature is currently macOS-only. Those are platform restrictions, not Docker restrictions. [OpenAI Linux app](https://learn.chatgpt.com/docs/linux/linux-app), [Claude Linux beta](https://code.claude.com/docs/en/desktop-linux), [Claude CLI computer use](https://code.claude.com/docs/en/computer-use).

The user's proposed terminal fallback remains valid as an architectural option: install tools for capturing the guest display and controlling applications, and let agents invoke them. That is a configured automation capability, not automatic parity with vendor Computer Use. It requires an actual display/session and compatible tools. For example, xdotool targets X11 and warns that it does not work correctly under Wayland. Select the guest session around the automation tools you intend to use. [xdotool](https://github.com/jordansissel/xdotool).

**Docker can be extended with graphical applications; claiming it categorically cannot would be inaccurate.** Current experimental environment files expose `sandboxOptions.display`, and the release notes confirm display-related configuration. But a display socket does not itself supply a complete maintained desktop, browser state, native messaging, app packaging dependencies, keyring, startup supervision, and remote viewing. [Environment files](https://docs.docker.com/ai/sandboxes/configuration/environment-files/), [release notes](https://docs.docker.com/ai/sandboxes/release-notes/).

A custom desktop inside a Docker microVM may eventually be a good solution. Until the actual app/browser combination works, treat it as a prototype. I found no basis for declaring it impossible, but also no basis for calling it a simpler drop-in replacement for this project's desktop VM. Passing a host display through would need separate analysis from providing an isolated guest desktop; the single display option does not establish equivalent isolation.

**The proposed architecture is one ordinary agent computer inside Incus.** Put the ChatGPT desktop app, its built-in browser, Chrome with the desired extensions, Claude Code CLI, optional Claude Desktop, projects, browser profiles, and guest automation tools together. Run app tasks locally within that guest; use the VM console to interact with it. The outer host remains responsible for VM lifecycle and network policy. Separate VMs are needed when credentials or trust should be separated, not simply because two agent products are installed.

This keeps the vendors' normal local integration paths intact. It also leaves room for another agent to install its supported software without requiring a new cross-environment bridge. This is a compatibility strategy, not a guarantee that every future agent or Linux feature will work.

Do not add Docker Sandboxes inside the desktop VM by default. It would add nested virtualization and another boundary to administer. It can be an optional execution backend later if a concrete workflow benefits from it. The immediate simplification should be one VM and one provisioning path, with reusable images deferred until needed.

A useful acceptance test for any proposed replacement must exercise the actual desired features:

1. The agent itself opens and operates a website through the official app browser or extension. A screenshot from a separately installed browser test tool does not pass this requirement.
2. The agent uses a deliberately selected signed-in browser profile, and the human can complete a login/CAPTCHA in that same browser.
3. A server built by the agent opens in that browser, with localhost/port forwarding accounted for.
4. A generated file can move through the workflow, with its upload/download location understood and the vendor's current feature limits respected.
5. Identify the OS that owns the app, shell, browser process, profile, and computer-use tools; verify they sit inside the intended boundary.
6. Close the viewer or controlling interface and check ongoing work. Test a host reboot separately; storage persistence, process survival, and task resumption are different properties.

For the clarified requirement, the decision does not need to wait for those experiments: a complete VM is the better baseline. Docker experiments would be evaluating whether they can replace it while preserving these capabilities, rather than asking the user to accept a different browser workflow.
