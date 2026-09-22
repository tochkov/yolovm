# Community demand evidence: isolated local agent computers

Researched 2026-09-20. This is qualitative discovery, not a survey or a market-size estimate. Primary discussion pages were opened and read. Hacker News timestamps were checked with its public Firebase API where stated. Reddit JSON requests returned 403; exact Reddit dates below come from search-index versions of the same primary threads, while some pages expose only relative dates. Upvotes are noisy snapshots, not users, installations, or votes for yolovm specifically. No post after the research cutoff is used.

## Assessment

There is recurring, independent demand for letting an agent work autonomously without granting it the user's whole computer. There is narrower but concrete demand for a **separate graphical computer**, native operating-system support, and a persistent machine reachable from several devices. A useful open-source tool can serve that niche. The evidence does **not** establish mass demand for an Incus wrapper, nor for one Mac simultaneously hosting Windows, macOS, and Linux agent desktops.

The most promising opening is the operational integration: provision a working desktop, log into the intended agent/browser, retain state, observe or take over, move files deliberately, recover, and know which machine the agent controls. Demand is much stronger for those outcomes than for a particular hypervisor. Several users already solved their problem with Docker, a spare mini-PC, cloud agent sessions, or a few scripts. Others explicitly avoid VMs because duplication and maintenance disrupt their existing workflow. A broad “sandbox any coding agent” pitch would face many satisfactory substitutes.

## Evidence ledger

### 1. Tried sandboxing, abandoned it because integrations broke

- **Source:** [Are you isolating your Claude Code agents?](https://www.reddit.com/r/ClaudeCode/comments/1vnb9a8/are_you_isolating_your_claude_code_agents_whywhy/)
- **Date / provenance:** August 13, 2026, corroborated by identical dated crossposts; organic question by `aj_kt`. Crossposts in r/AI_Agents and r/ChatGPTCoding are **one originating demand**, not three.
- OP tried Docker Sandbox on Windows and native sandboxing on Mac. Git/GitHub, package installation, document/PDF tools, and session state after updates created confusing failures. OP reverted to unsandboxed use but wanted another solution and disliked headless access.
- Independent `rditorx` preferred the desktop app's rich rendering and screenshots but found it harder to isolate than CLI. Other respondents were satisfied with containers or unrestricted auto mode.
- **Read:** Strong evidence for reliability and desktop integration; not proof users want full VMs.

### 2. VM environment duplication is a real adoption barrier

- **Source:** [What is the best sandbox for Claude Code?](https://www.reddit.com/r/ClaudeCode/comments/1qcd9zj/what_is_the_best_sandbox_for_claude_code/)
- **Date / provenance:** Page displays “8mo ago” for OP and “7mo ago” for key reply; exact date not recovered. Organic question by `crazyneverst`.
- OP wanted unattended, longer tasks. `Toastti` suggested Docker or a UTM macOS VM. Independent `amenhallo` objected to reinstalling Docker, Kubernetes, VS Code, brew tools, and keybindings, plus syncing changes while working alongside the agent: “It's probably the safest approach, but a bit of a hassle.”
- `accelas` reported using Incus system containers; `mencio` promoted their own `claude-on-incus`, explicitly an author response.
- **Read:** Excellent fit for reusable profiles and human/agent file handoff; equally strong evidence against assuming VM setup alone is enough.

### 3. Near-exact Linux desktop VM workflow, built independently

- **Source:** [Giving My Linux AI Agent Its Own Desktop](https://yexuhang.com/2026-09-08-linux-computer-use-isolated-desktop/)
- **Date / provenance:** September 8, 2026; personal implementation report by Xuhang Ye, not a sandbox vendor launch.
- Motivating problem: computer-use actions stole host pointer/focus. The author built an Ubuntu/XFCE QEMU/KVM guest with MCP over SSH, VNC viewing, separate input/output directories, persistent state, and explicit manual takeover. This closely resembles the desired end-user job.
- Author describes host-specific paths, patched input tooling, untested applications, and ongoing update work; it is explicitly not a portable package.
- **Read:** High relevance, one person's tested workflow. Demonstrates both a packaging opportunity and the maintenance burden. It does not prove VM superiority over a separate desktop session, which was not compared head-to-head.

### 4. Simplicity is requested explicitly

- **Source:** [CC Isolation on daily driver machine](https://www.reddit.com/r/ClaudeCode/comments/1tpd4hi/cc_isolation_on_daily_driver_machine/)
- **Date / provenance:** May 27, 2026; organic question by `Mr_Bilbo_Swaggins`; search snapshot +1.
- OP compared native sandbox, Docker, combinations, and UTM: “I want a higher level of isolation without creating a headache for myself.” Limited virtualization experience was explicit.
- Responses offered a Tailscale-connected VPS, VM-specific identities, and simply using the personal PC.
- **Read:** Good evidence for an approachable installer and clear defaults, weak evidence for one backend. A free tool competes with a cheap remote machine as well as containers.

### 5. Isolation on owned hardware is already practiced

- **Source:** [(Discussion/Advice) Your approach for isolating claude from own computer](https://www.reddit.com/r/ClaudeCode/comments/1uz1ajm/discussionadvice_your_approach_for_isolating/)
- **Date / provenance:** Page displays “2mo ago”; exact date not recovered. Organic question by `nearlynarik`.
- OP wanted more auto-mode use without risking the main Mac. Independent `One-Spaghetti` described Proxmox VMs, VS Code SSH, backups, and Tailscale. `Its_me_Snitches` used a second Mac mini with screen sharing. Another respondent used a dedicated Linux server for Claude and Codex.
- Counterpoint: other users wanted the agent to configure their actual system, including services, DNS, and networking; isolation removes that use case.
- **Read:** Strong owned-hardware and remote-access fit, but substantial existing DIY competence and substitutes.

### 6. Explicit rejection of containers/VMs; integration consumes the work

- **Source:** [Sandboxing Pi?](https://www.reddit.com/r/PiCodingAgent/comments/1wj1lsm/sandboxing_pi/)
- **Date / provenance:** September 17, 2026 in indexed primary thread; page relative age was stale/inconsistent. Organic question by `CevicheMixto`; search snapshot +26.
- OP wanted secure, convenient Linux sandboxing and explicitly excluded containers/VMs. Independent replies reported satisfaction with bubblewrap, plain Docker, and smolvm.
- `ZeroTronix`, describing a personal microsandbox setup, said “90% of my effort” went to status streaming, clipboard, and authentication; they wanted their existing OpenAI subscription without exposing tokens in the guest.
- **Read:** Strong counterevidence for universal VM demand, strong evidence the valuable wrapper work is lifecycle/visibility/authentication. Subscription proxy security claims were not independently tested.

### 7. Resource overhead motivates people to leave VMs

- **Source:** [Ask HN: How are you sandboxing your coding agents?](https://news.ycombinator.com/item?id=46700628)
- **Date / provenance:** January 21, 2026, verified by HN API; 3 points, 7 comments. Organic question by `kwar13`.
- OP already used a headless VM but found it resource intensive and asked for alternatives. A commenter reported Dockerized worktrees with authentication trouble when Mac login invalidated Linux tokens. Other answers included OrbStack and a separate physical system.
- **Read:** Direct negative demand against VM overhead, plus evidence for authentication and project workflow friction. Very small discussion; do not present as a broad consensus.

### 8. Native apps matter, but even a VM-tool author prefers lighter isolation

- **Source:** [Ask HN: How are you sandboxing coding agents?](https://news.ycombinator.com/item?id=46400129), particularly [netcoyote's reply](https://news.ycombinator.com/item?id=46400151)
- **Date / provenance:** December 27, 2025, HN API; 46 points, 32 comments. Organic question; the quoted reply is by the author of SandVault and ClodPod.
- The author built both a low-privilege account solution and macOS VMs to retain Xcode/iOS simulator use. They used the account approach more because setup was easier and VM overhead disappeared.
- Independent respondents already used Proxmox LXC, containers, cloud-style homelab sessions, or ordinary users. One Catnip user specifically wanted network restrictions.
- **Read:** Concrete native-OS need plus unusually credible counterevidence from someone who built both approaches. Count the author experience separately from independent adoption.

### 9. Linux power users reproduce the script collection pattern

- **Source:** [HN sandboxing survey subthread](https://news.ycombinator.com/item?id=47185250)
- **Date / provenance:** February 27, 2026, HN API; organic subthread under “Let's discuss sandbox isolation.”
- Independent `stephen_cagle` already used KVM/QEMU scripts that created Debian project VMs, pushed/pulled Git state, and started Claude plus their customized editor inside the guest. Others reported Docker Sandboxes or dedicated users.
- Simon Willison preferred Claude Code on the web, placing infrastructure containment with the provider and accepting broad network access for his open-source work.
- **Read:** Confirms yolovm's “article converted to scripts” pattern is independently useful. Also shows why cloud and lightweight solutions can win on effort.

### 10. Explicit need for native cross-platform isolation

- **Source:** [akazantsev's HN comment](https://news.ycombinator.com/item?id=48917523)
- **Date / provenance:** July 15, 2026, HN API; independent comment beneath a security discussion.
- The commenter found their existing wrapper exposed their home folder and wanted a fake home, network restrictions, and an easy cross-platform solution. Their specific reason: “I develop a cross-platform native app and want the agent to compile and fix the platform-specific errors.”
- Replies included the yoloAI author's solution and arguments that simpler systems suffice.
- **Read:** Strong qualitative signal for Windows/macOS guests, but one developer, not evidence of demand for a heterogeneous three-VM fleet or a particular GUI.

### 11. A desktop-tool user asks directly about local VM execution

- **Source:** [Show HN: Agent-desktop](https://news.ycombinator.com/item?id=47982708)
- **Date / provenance:** May 2, 2026, HN API; 99 points, 44 comments for the launch overall. Use the independent commenter `dorianzheng`, not the creator's pitch.
- Comment: “is it possible to run it inside local micro-VM, such as boxlite?” Other commenters discussed native-app accessibility, mobile simulators, and requested demonstrable workflows.
- **Read:** Direct request connecting desktop automation with local isolation. Only one comment and not validation of full-VM packaging; launch popularity belongs to the desktop tool, not the isolation request.

### 12. Cross-OS GUI adoption requirement from an internal team

- **Source:** [Notes on Cross-Platform Computer Use Agents for macOS and Windows](https://codenote.net/en/posts/computer-use-agents-macos-windows-selection-notes-2026/)
- **Date / provenance:** September 3, 2026; named personal author Tadashi Shigeoka.
- The author reports a colleague requiring both Windows and macOS before an internal desktop-agent rollout. This led to comparing native-app automation options. The article explicitly says the comparison is documentation-based rather than a full hands-on evaluation.
- **Read:** Relevant cross-OS demand signal, weaker than a deployed workflow. Do not treat its product feature matrix as verified here. It does not request running both guests on one Mac host.

### 13. Several persistent agent machines on a home lab

- **Source:** [Gemma4-31B's reaction to getting a web browser](https://www.reddit.com/r/claudexplorers/comments/1u7hlx0/only_claudeadjacent_gemma431bs_reaction_to/)
- **Date / provenance:** June 16, 2026 in indexed thread; author `MiddleLtSocks`, search snapshot +39. Personal hobby deployment, no product promotion seen in inspected portion.
- OP describes multiple long-running agents on dedicated NUCs, each with a container within its own VM; some use local models and others frontier APIs. Guests have build tools, sudo, persistent files, and browser MCP.
- **Read:** Evidence that persistent multi-agent computers on owned hardware are real. It is an enthusiast experiment and uses headless browsers, not evidence of mainstream graphical-desktop demand.

### 14. Resettable workspace desired; environment maintenance rejected

- **Source:** [Sandboxing AI Agents in Linux discussion](https://news.ycombinator.com/item?id=46874139), [aflag's request](https://news.ycombinator.com/item?id=46876761), [jauntywundrkind's reply](https://news.ycombinator.com/item?id=46876406)
- **Date / provenance:** February 3, 2026, HN API; 119 points, 68 comments for the article discussion. Independent replies.
- `aflag` wanted to snapshot the existing workspace into a VM, let the agent work, then destroy it. Session/project syncing was their remaining concern. `jauntywundrkind` found maintaining images with their existing tools onerous and wanted visibility into filesystem changes.
- **Read:** Useful demand for snapshots, repeatable environments and inspectable results; not necessarily persistent full desktops. Some users want their current environment wrapped, not another computer to maintain.

### 15. Apparent grassroots demand was actually a creator post

- **Source:** [Don't let Claude use your actual computer from the CLI](https://www.reddit.com/r/ClaudeAI/comments/1s839hp/dont_let_claude_use_your_actual_computer_from_the/)
- **Date / provenance:** March 30, 2026; search snapshot +435. OP `aniketmaurya` discloses downthread that they created SmolVM and planned a paid hosted version.
- The original post argues for disposable graphical computers. Do **not** count it as independent unmet demand. Independent replies include a Tart user, users content with permissions/backups, and someone whose tightly firewalled home setup could no longer reach anything useful.
- **Read:** Illustrates genuine tradeoffs and heavy supplier promotion. Popularity of security advice should not be converted into projected users for yolovm.

### 16. Continuity across devices is distinct from parallel VM demand

- **Source:** [Anyone running Claude Code across multiple machines?](https://www.reddit.com/r/ClaudeAI/comments/1r5zpyn/anyone_running_claude_code_across_multiple/)
- **Date / provenance:** Page shows “7mo ago”; exact date not recovered. Organic question by `Keith_Kak_Solo`.
- OP wanted context continuity between three Windows PCs. Replies offered remote access or synchronizing agent state, with path consistency and simultaneous-write caveats. A tool author promoted their session UI.
- **Read:** Supports a stable remote workstation as an alternative to machine-to-machine state copying. It is **not** evidence that the user wants three parallel isolated computers; those are different jobs.

## What the evidence justifies building

These are hypotheses derived from the ledger, not measured preference rankings:

1. **A repeatable personal agent desktop:** one install, boot, open viewer, start the existing native agent app, keep intentional logins/state. Sources 1–5 are the strongest basis.
2. **Clear daily lifecycle and recovery:** status, start/stop, snapshot/restore/clone, understandable resource use, and update diagnostics. Sources 3, 6, 7, and 14 support this.
3. **A deliberate host/guest handoff:** visible selected computer, predictable file import/export, clipboard controls, manual takeover, and no silent fallback onto the personal desktop. Sources 2, 3, 6, and 16 support these needs.
4. **Owned-hardware remote access:** provide or document a reliable always-on pattern. Sources 1, 5, 9, and 13 support this, though physical machines and Proxmox already satisfy many users.
5. **Native OS backends only after real users request them:** sources 8, 10–12 show a plausible Windows/macOS direction. They do not validate building all combinations before proving the Linux desktop experience.

## Reasons this could remain a small project

- Enthusiasts comfortable enough to adopt Incus can often assemble the setup themselves. Several ledger entries are exactly that behavior. A wrapper must remove recurring work, not merely the first installation.
- Many coding tasks need a shell, not a desktop. Existing containers, native sandboxes, and hosted execution are adequate for respondents in sources 1, 6–9, and 14.
- “My machine, but safer” and “a separate agent computer” are different desires. Sources 2 and 14 expose the cost of rebuilding and synchronizing an environment; source 5 includes people who positively want system-wide agent control.
- Isolation is not the user's whole workflow. Identity setup, browser login, output transfer, context continuity, and recovery remain. A VM with root permission does not undo actions made through credentials intentionally placed inside it.
- Exact heterogeneous Windows/macOS/Linux orchestration demand was not found in the organic discussions reviewed. That remains a reasonable future hypothesis, not a validated first release.

## Confidence and limits

**High confidence:** isolation/autonomy tension is real; setup friction and compatibility are recurring; users have very different threat models and acceptable overhead.

**Moderate confidence:** there is a useful OSS niche for a maintained, persistent, local agent desktop with good daily operations. Several independent real workflows support it, but no adoption experiment was conducted.

**Low confidence:** audience size, conversion from interest to installation, retention, willingness to migrate existing setups, and demand for three heterogeneous VMs on a Mac mini. Search results cannot estimate those.

The sample deliberately searched for this problem and therefore overrepresents concerned users. Reddit threads contain self-promotion, uncertain advice, and automated summaries; those summaries were not used as evidence. HN relative timestamps differed across cache snapshots, hence API dates were preferred. Statements about product capabilities in comments remain reports of user experience, not security verification. Most useful validation next would be observing a handful of strangers install yolovm and return to it for real work, including people already using a competing method.
