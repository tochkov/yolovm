# Local agent sandbox ecosystem: evidence and competitive assessment

Research checked 2026-09-20. Primary sources: current project documentation, GitHub issue bodies/comments, and live GitHub API metadata. This is a qualitative evidence sample, not a representative survey or an estimate of active users. Issue authors' descriptions are reports, not independently reproduced tests. Maintainer roadmap items are explicitly separated from independent demand. No hands-on comparison was performed.

## Judgment

There is demonstrated demand for small, understandable, self-hosted agent environments on owned hardware. The clearest finding is not another sandbox author's pitch: independent E2B users explicitly ask for one Linux server, only a few sandboxes, and a much smaller operational footprint. There is also direct demand for persistent browser sessions and native/visible desktop access.

However, local execution, persistence, multiple machines, unrestricted agent permissions, templates and VM isolation are already widely available. A general-purpose “safe YOLO coding sandbox” enters a crowded category against increasingly capable free tools. yolovm's plausible niche is a dependable **personal computer for an agent**: a persistent desktop, its own signed-in browser and applications, clear host/network separation, easy human takeover, and a few machines on hardware the user owns. That is a workflow and packaging proposition, not a new isolation primitive.

The work worth defending is making this entire experience boringly reliable: creation, authenticating inside the guest, reopening after reboot, remote access, snapshots and rollback, updates without losing state, and diagnosing failures. More configurable backends are not automatically more useful. Cross-OS expansion multiplies precisely the compatibility work that users report below.

## Highest-value direct demand

**E2B's local/small-host discussion is exceptionally close to the user's situation.** [Issue #2270](https://github.com/e2b-dev/runtime/issues/2270), opened 2026-03-31, asks for local bare metal. On April 1, independent user SentimentalK asks for “one Linux server” and “maybe 3–10 sandboxes max,” plus templates, command/file operations, Git, authentication and optional network restrictions. Another participant wants fewer than ten sandboxes on a private/offline server. On April 15, maintainer sitole says local Linux is already possible without Nomad or cloud services; a unified setup is difficult because installations vary. This demonstrates a simplification opportunity, not an absent technical capability. [Detailed user comment](https://github.com/e2b-dev/runtime/issues/2270#issuecomment-4166556337), [maintainer answer](https://github.com/e2b-dev/runtime/issues/2270#issuecomment-4250870917).

Current [E2B local-development instructions](https://github.com/e2b-dev/runtime/blob/main/DEV-LOCAL.md) involve building components and running Postgres, ClickHouse, Redis and additional services. These are reasonable platform-development requirements, but a meaningful mismatch for someone wanting two personal agent machines.

## Fifteen concrete user reports and requests

Dates are creation dates unless otherwise noted. “Open” is the status seen in the research, not a promise that the defect remains present in every current release. Some older issues remain open after related capabilities improve.

| Date | Primary source / author | What the person actually wanted or experienced | Implication and qualification |
|---|---|---|---|
| 2026-03-31; detailed follow-up 04-01 | [E2B #2270](https://github.com/e2b-dev/runtime/issues/2270), whz1106 and SentimentalK | A small number of sandboxes on a single owned Linux server, avoiding a full cloud-scale setup. | Strong direct evidence for small-host simplicity. Maintainer confirms possible today, though setup remains involved. |
| 2026-04-10 | [NanoClaw #1732](https://github.com/nanocoai/nanoclaw/issues/1732), stevengonsalvez | Native runner for headed browsers, tmux, macOS APIs, and desktop integration. | Strong evidence that users hit the desktop boundary of an existing container-oriented assistant. Their proposed solution sacrifices isolation; a guest desktop offers a different tradeoff. The issue's claims about Xvfb/VNC are overbroad: this is not proof that containers cannot run GUIs. |
| 2026-04-18 | [NanoClaw #1829](https://github.com/nanocoai/nanoclaw/issues/1829), shakhruz | Browser session files disappear when containers restart; proposes a persistent sessions mount and browser-version pinning. | Real demand for durable browser identity. Persistent storage solves much of this; a full VM is not required. Open; author links an implementation in their fork. |
| 2026-03-10 | [Code on Incus #199](https://github.com/mensfeld/code-on-incus/issues/199), johnnypea | A client able to connect to local or multiple remote Incus servers and run agents there. | Strong owned-server/remote-client fit. Maintainer discusses remote supervisor and a separate web workflow tool. Open. |
| 2026-06-11 | [microsandbox #970](https://github.com/superradcompany/microsandbox/issues/970), huapox | A Compose-like YAML describing multiple VMs and dependencies, with convenient lifecycle commands. | Evidence for declarative small-fleet management; not specific to desktop users. Open. |
| 2025-05-31 | [microsandbox #250](https://github.com/superradcompany/microsandbox/issues/250), gitizenss | Clone live machines and fork agents mid-conversation, with frustration at dependence on a proprietary service. | Strong desired workflow, but **now closed** through #1542; current microsandbox documents live branches and full snapshots. Do not count this as an unfilled market gap. |
| 2026-09-10 | [Docker SBX #577](https://github.com/docker/sbx-releases/issues/577), rhcarvalho | Ability to disable guest-triggered opening of the host browser. | User wants fewer surprising host integrations. Docker member acknowledges the suggestion. A useful isolation-default lesson; keep user browser sessions inside the agent machine unless explicitly shared. |
| 2026-08-06 | [Docker SBX #406](https://github.com/docker/sbx-releases/issues/406), alexander-turner | A noninteractive/no-input mode because required Docker sign-in opens a browser or hangs automation. | Account dependencies create practical friction for local/background tools. Open; specific to v0.37.1 report. |
| 2026-08-20 | [Docker SBX #478](https://github.com/docker/sbx-releases/issues/478), kinudev | MCP gateway fails after daemon reboot; user reports unnecessarily recreating sandboxes before finding a non-destructive workaround. | Persistent storage is insufficient without lifecycle recovery. Open report against v0.39.0, not a verified claim about latest release. |
| 2026-03-19 | [Docker Desktop #214](https://github.com/docker/desktop-feedback/issues/214), b-mendoza | WSL path remapping breaks symlinks and consequently pnpm/corepack. | Cross-platform filesystem compatibility is a major support burden. Historical report against Docker Desktop 4.65.0, not necessarily current standalone SBX. |
| 2026-03-14 | [NanoClaw #1067](https://github.com/nanocoai/nanoclaw/issues/1067), spencer-whitman | Autostart races with the Apple Container runtime after reboot and crash-loops. | Always-on agents need dependency readiness, backoff and recovery. **Closed** via #1128, so evidence of a recurring problem class, not current missing functionality. |
| 2026-05-22 | [NanoClaw #2589](https://github.com/nanocoai/nanoclaw/issues/2589), snymanpaul | An Apple Container conversion leaves proxy hostname resolution broken and agents silently stop replying. | More runtime choices add integration debt. A VM wrapper would have comparable responsibilities. Open. |
| 2026-03-02 | [Matchlock #82](https://github.com/jingkaihe/matchlock/issues/82), janost | Mount credentials/configuration at fixed guest paths outside the workspace; offers an implementation. | Users need existing workflows to function, and may request sharing that weakens isolation. A guest-owned identity can be easier to explain than a proliferation of exceptions. Open. |
| 2026-08-15 | [nono #1646](https://github.com/nolabs-ai/nono/issues/1646), nielsmadan | Permission-error guidance repeatedly prescribes ineffective path grants for nested-sandbox failures affecting Codex, SwiftPM, Chrome and others. | Broad compatibility and helpful diagnostics matter more than merely enforcing a boundary. Open; some errors require changing inner sandbox behavior. |
| 2026-05-03 | [container-use #346](https://github.com/dagger/container-use/issues/346), marcindulak | Asks maintainers to archive an apparently inactive project so newcomers do not waste time. | Maintenance credibility matters in a wrapper-heavy category. **Do not call it abandoned:** current main has substantial August 12 commits, including a security fix; latest release is still v0.4.2, dated 2025-08-19. |

This is a useful set of independent pain signals. It does not establish how many people would install yolovm, and a defect in a competitor is often fixable faster than users will adopt an entirely different runtime.

## Competitive map, prioritized by substitution risk

### Docker Sandboxes: strongest general coding-sandbox substitute

Current [installation documentation](https://docs.docker.com/ai/sandboxes/install/) says standalone `sbx` needs neither Docker Desktop nor Docker Engine. Hosts include Apple Silicon macOS 14+, Windows 11 x64 with Windows Hypervisor Platform, and Ubuntu 24.04+ on x64/ARM64 with KVM. Do not repeat older descriptions that exclude Linux or require Docker Desktop.

The [usage guide](https://docs.docker.com/ai/sandboxes/usage/) explicitly preserves installed packages, Docker images, configuration, command history, and mountless workspaces across stop/restart. Removing a sandbox deletes guest state. It supports port publishing and copying files. This is not just an ephemeral container launcher.

The [FAQ](https://docs.docker.com/ai/sandboxes/faq/) says local CLI use is free, including commercial work; organization governance costs extra. A Docker login is required. Telemetry is documented and can be disabled. The [release repository](https://github.com/docker/sbx-releases) explicitly labels the license proprietary. Therefore “free” is not yolovm's distinction, but no mandatory account and genuinely open source can matter to some users.

Desktop boundary: Docker's [community Playwright kit](https://github.com/docker/sbx-kits-contrib/blob/main/playwright/README.md) provides Chromium and browser automation, but explicitly has no display server and supports headless work; headed/UI/codegen modes are excluded. That is a concrete distinction from a ready-to-use guest desktop. It does not establish that a custom desktop kit would be impossible. Recent [SBX releases](https://github.com/docker/sbx-releases/releases) also mention a host management GUI; a management GUI is not a guest desktop. Stable v0.43.0 was released September 15, making old feature comparisons particularly unreliable.

Verdict: most users who only want CLI coding isolation should evaluate SBX before yolovm. Competing on generic lifecycle, agent presets, secrets and networking would be costly and weakly differentiated.

### Code on Incus: closest existing Incus tool

[Code on Incus](https://github.com/mensfeld/code-on-incus) already packages Incus system containers with root, systemd, nested Docker, persistence, parallel sessions, profiles, network controls and optional security monitoring. It is MIT-licensed, active, and describes itself as a tool rather than a startup. Live repository metadata showed 727 stars on September 20; that measures attention, not active users. Its documentation includes macOS through a Linux VM.

Most consequentially, the owner opened [#791 on September 10](https://github.com/mensfeld/code-on-incus/issues/791), proposing an Incus VM backend retaining existing ergonomics. The issue lists image, mounting, networking and monitoring changes and explicitly treats it as substantial work. This is **maintainer roadmap evidence**, not independent demand, and no shipping VM mode was verified here.

Other nearby tools include [sandbox-claude](https://github.com/pvillega/sandbox-claude) (MIT; persistent Incus containers, golden stacks, deploy keys, filtering, port forwarding; macOS through OrbStack) and [vibebin](https://github.com/jgbrwn/vibebin) (persistent Incus sandboxes and web/SSH access on an owned server). These are substantive overlaps with a “scripts around Incus” proposition, though their documented emphasis is coding/server environments rather than a full personal GUI computer.

Verdict: investigate extending or integrating with existing Incus tooling before rebuilding all of its lifecycle and configuration features. A polished desktop workflow can still justify a separate narrow tool.

### microsandbox and Matchlock: local microVM tools are already real

Current [microsandbox](https://github.com/superradcompany/microsandbox) is Apache-2.0, supports Linux/macOS/Windows hosts, named and detached long-running sandboxes, OCI images, live branching and full snapshot/restore. It remains beta. Its SDK/MCP orientation makes it especially relevant as a substrate or competitor for any future generic sandbox API. Do not claim persistence or cloning uniquely requires a traditional VM.

[msb-omarchy](https://github.com/ya-luotao/msb-omarchy) is a small MIT desktop wrapper using microsandbox on Apple Silicon: persistent Arch/Omarchy desktop, Chromium, native window, named machines, shared files and VNC. It is experimental, uses a pinned graphics build, and uses software rendering; the README documents September 13 validation and only seven stars. It is not a proven drop-in yolovm replacement or broad demand signal, but shows that a microVM desktop is feasible and that the packaging space is already being explored.

[Matchlock](https://github.com/jingkaihe/matchlock) is MIT, experimental, Linux/macOS, and explicitly emphasizes disposable microVMs, network allowlisting and host-side secret injection. It is a better comparison for an agent's controlled execution environment than for a persistent personal desktop. It still illustrates how much security and lifecycle plumbing is available without inventing another hypervisor layer.

### NanoClaw and OpenHands: different layers, potentially complementary

[NanoClaw](https://github.com/nanocoai/nanoclaw) is an assistant/agent harness: messaging channels, memory, scheduling, per-group agents, container execution and OneCLI credential handling. Current main supports alternate providers including Codex; it is not accurately described as Claude-only. Its customization model deliberately involves modifying a small fork and installing skills. It is not a general-purpose personal VM manager. Someone satisfied with an autonomous messaging assistant may choose it instead, while a user wanting an ordinary agent application and browser inside an isolated desktop has a different need.

Current [OpenHands](https://github.com/OpenHands/OpenHands) main describes Agent Canvas, a self-hosted control center for agents and automations with local, Docker, VM and remote backends and multiple agent types. The README specifically mentions dedicated computers such as Mac Minis. This overlaps strongly with ambitions for dashboards, multi-agent coordination and always-on workloads. It can also sit above machines provisioned by yolovm. Avoid casually evolving yolovm into another orchestration frontend without demonstrated demand.

[Dagger container-use](https://github.com/dagger/container-use) covers coding agents operating in independent container development environments. Its release/maintenance history deserves evaluation, but the May “archive” request alone is not enough to dismiss it. Current repository is not archived; August commits include a path traversal fix and Copilot configuration support. Prefer a narrow functional comparison to a popularity ranking.

[nono](https://github.com/nolabs-ai/nono) targets local process/tool-level restriction and credential/policy brokerage. Its distinctive benefit is reusing existing host workflows without provisioning a separate OS; its issue history shows corresponding compatibility friction. It is not a substitute for a Windows/macOS guest desktop, but may be sufficient for users whose entire requirement is restricting an existing CLI.

### Hosted desktop sandboxes: capable, with a different ownership model

[E2B Desktop](https://github.com/e2b-dev/desktop) already supplies Linux/Xfce computer-use desktops, Chrome/Firefox/application launch, display streaming, keyboard/mouse and file operations. Its default getting-started path uses an E2B account/API; self-hosting is possible, with the operational mismatch discussed above. “There is no desktop sandbox” is therefore false.

[Daytona's computer-use documentation](https://www.daytona.io/docs/en/computer-use/) covers Linux and Windows, GUI automation and VNC, and points to use.computer for macOS. More importantly for an **open source free tool** comparison, the current [daytonaio/daytona README](https://github.com/daytonaio/daytona) states that core development moved private in June 2026 and the public repository will receive no further updates, fixes or releases. Existing public code remains usable/forkable under its license. Do not describe the actively developed service as a straightforward maintained OSS replacement.

## What this evidence suggests building, and what it does not

The strongest initial promise is “a persistent, separate computer for your agent on your own Linux machine.” Validate the complete desktop/authentication/remote-recovery experience against direct alternatives before investing in a modular platform. Incus is an implementation choice; users' unmet jobs are continuity, confidence and convenient access.

Prioritize reversible machine management and comprehensible defaults: create/start/stop/list; attach to the existing desktop; a snapshot before risky work; clone a clean provisioned base; backup/export/import; resource limits; reboot recovery; useful diagnostics; and an explicit account/network/sharing boundary. A few reusable profiles can be valuable without a general plugin architecture. These priorities are inferences from the issue patterns, not a vote count for a predetermined roadmap.

Do not treat egress restrictions as sufficient protection for signed-in browser accounts. A separate machine limits host damage, while actions taken inside the guest using its logged-in services remain real actions. This is a product-boundary distinction to communicate clearly, not an argument against the use case.

The evidence does **not** justify assuming broad consumer demand, large fleets, a multi-tenant cloud control plane, or a generic agent orchestration framework. It also does not establish that cross-OS support is the first feature users need. The plausible early audience is technical individuals and small teams already doing some of this manually, who would prefer a maintained recipe/tool. Enough demand for useful OSS is a lower threshold than enough demand for a business; neither is proven by stars alone.

## Remaining verification limits

- No alternatives were installed or benchmarked. Documentation-supported capability is distinguished from demonstrated quality.
- Historical bugs are used as evidence of recurring workflow friction, not claimed as universal current competitor failures.
- GitHub issues overrepresent technical and dissatisfied users. Several desired features are already implemented elsewhere.
- Browser profile persistence is not a guarantee that every site will accept login/session reuse or that account authentication survives cloning.
- Other researchers are covering dedicated desktop virtualization projects and cross-OS host/guest limitations; this note should be combined with those findings before drawing a final feasibility conclusion.
