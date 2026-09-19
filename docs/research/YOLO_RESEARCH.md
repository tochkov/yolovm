Research checked on 17 September 2026, against `YOLO_SETUP.md` and the adjacent `ATLAS.md`, `yolo-dev.yaml`, and `network-acl.yaml`.

**Clarification after this comparison:** native desktop-app browsers and extensions are essential requirements. For that scope, the recommendation is a complete desktop VM. See [NATIVE_AGENT_RESEARCH.md](NATIVE_AGENT_RESEARCH.md) for the product-by-product follow-up; this document's Docker recommendation was conditional on a coding-first workflow and does not establish native browser parity over SSH.

**Recommendation: retain Incus if you want the complete desktop in the draft. If the real requirement is autonomous coding, first evaluate Docker Sandboxes (`sbx`), optionally controlled through the ChatGPT desktop app over SSH. Multipass is viable, but it does not remove the hardest parts of the desktop design.**

This is a documentation and source-code assessment, not an installation test on Atlas. Commands below illustrate candidate workflows; they do not constitute a validated replacement setup guide. No host configuration or existing setup files were changed.

The draft asks for several independent things: an environment agents may administer; protection for Atlas and the LAN; persistent projects and credentials; a desktop for browser/app interaction; background operation; and easy creation of additional environments. The particular hypervisor is only one part of that. Removing an unnecessary guest desktop or image-building workflow can save substantially more work than changing the VM launcher.

My comparison is:

| Approach | Best fit here | What still needs work | Assessment |
| --- | --- | --- | --- |
| Incus desktop VM | Complete guest desktop, persistent browser/app state, automatic VM startup | Guest setup, app startup, boundary verification | Best fit for the draft as written |
| Multipass desktop VM | Ubuntu VM plus a separately configured remote desktop | Desktop installation, display/session access, host firewall, startup policy | Possible; unlikely to be simpler overall |
| Multipass headless VM | Quick Ubuntu shell environments | Agent installation, LAN restrictions, unattended execution | Simple launcher, but less helpful for your network policy |
| Incus headless VM | General-purpose, always-on agent machines | Agent installation and execution lifecycle | Strong choice if persistence and host-enforced networking dominate |
| Docker Sandboxes | Coding agents with system access inside microVMs | Policy selection, workflow compatibility, disconnect/reboot tests | Most promising substantial simplification |
| virt-manager/libvirt | One or two manually administered desktop VMs | Guest installation, network restrictions, repeatable provisioning | Easier interactively for some people; less compelling for repeated automated creation |

**Multipass can do the VM job.** It provides cloud-style Ubuntu instances and cloud-init provisioning. CPUs, RAM, and disk capacity can be specified at launch. Its customization mechanism can create users, install packages, and write agent instructions. That moves the customization into a cloud-init file; it does not eliminate it. [Canonical overview](https://canonical.com/multipass/docs/latest/), [cloud-init customization](https://documentation.ubuntu.com/multipass/latest/how-to-guides/manage-instances/launch-customized-instances-with-multipass-and-cloud-init/).

Reusable environments are supported. `multipass clone` has existed since 1.15 and makes an independent copy of a stopped instance. Multipass also supports snapshots, currently taken while the instance is stopped. Claims that it has neither feature are outdated. These features help with reuse and rollback, but cloning still copies guest data, so prepare a credential-free source. [Clone reference](https://canonical.com/multipass/docs/latest/reference/command-line-interface/clone/), [snapshot reference](https://canonical.com/multipass/docs/latest/reference/command-line-interface/snapshot/).

The desktop is where Multipass becomes less attractive. Canonical's documented route installs a desktop environment and an RDP server, then connects using an RDP client. The Multipass management GUI is not the guest's graphical console. Incus already exposes the guest display through `incus console NAME --type vga`, using a SPICE viewer, including when the guest agent is unavailable. For occasional access to the actual autologged-in desktop, that is a useful simplification. [Multipass graphical interface](https://documentation.ubuntu.com/multipass/latest/how-to-guides/customise-multipass/set-up-a-graphical-interface/), [Incus console](https://linuxcontainers.org/incus/docs/main/howto/instances_console/).

There is a specific release mismatch to avoid: Ubuntu 26.04's standard GNOME session is Wayland-only, while the familiar Multipass desktop instructions use xrdp and an Xorg session. Do not assume that older recipe works unchanged. A suitable alternative desktop, such as Xfce, or a GNOME-native remote-desktop configuration needs evaluation. XWayland compatibility for individual applications does not restore a GNOME Xorg session. Ubuntu also documents persistent remote-login sessions in newer GNOME, so it would be wrong to claim every RDP disconnect necessarily kills work. The exact chosen session must be tested. [Ubuntu 26.04 release notes](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/).

**Multipass does not make the LAN policy disappear.** Its documented networking interface deals with interfaces, bridging, routes, and DNS. I did not find an Incus-style declarative network ACL facility in the current CLI/settings documentation. To preserve the draft's boundary, plan host-enforced firewall rules and test traffic to Atlas, the LAN, and sibling VMs. A guest firewall is insufficient when the agent can become root. A NAT network is not an outbound LAN block; adding a direct LAN bridge is not a substitute. Host-input and forwarded traffic both matter, along with management connections, DNS/DHCP, and IPv6. [Multipass networking](https://canonical.com/multipass/docs/latest/how-to-guides/manage-instances/set-up-custom-networking/).

Incus's bridge ACLs fit this requirement more directly. The draft correctly notes that attaching the ACL to the bridge does not isolate guests sharing that bridge. Current Incus documentation distinguishes NIC-attached ACLs for intra-bridge filtering; check the version packaged on Atlas before choosing that feature. Baseline network-service exceptions also precede ACL rules. Retain a concrete test against a known listening host service, rather than treating an unsuccessful ping as proof. [Incus bridge ACL behavior](https://linuxcontainers.org/incus/docs/main/howto/network_acls/#bridge-limitations).

One Multipass default is particularly relevant: creating its **primary** instance automatically mounts the host user's home directory into the guest. Use a separately named instance and verify its mounts, or disable mounts as appropriate. An agent development sandbox should not accidentally acquire the user's home through a convenience default. [Primary-instance behavior](https://canonical.com/multipass/docs/latest/how-to-guides/manage-instances/use-the-primary-instance/).

**Startup needs a precise definition.** Incus exposes `boot.autostart=true` to start a designated instance when its daemon starts. Multipass's GUI-autostart option concerns the management application. However, it would also be inaccurate to say Multipass never restarts guests automatically: the 1.16.4 daemon source restarts/synchronizes instances whose saved state was running. That is evidence of state restoration, not an explicit per-instance always-start policy equivalent to Incus's setting. Test real host shutdown/reboot behavior; if unconditional startup is required, a host service can start a named working VM. Avoid starting every VM indiscriminately if a template should remain stopped. [Incus boot options](https://linuxcontainers.org/incus/docs/main/reference/instance_options/#boot-related-options), [Multipass GUI autostart](https://canonical.com/multipass/docs/latest/reference/settings/client-gui-autostart/), [Multipass 1.16.4 source](https://raw.githubusercontent.com/canonical/multipass/v1.16.4/src/daemon/daemon.cpp).

Neither starting the VM nor logging into GNOME establishes that ChatGPT launches, a browser profile unlocks, or interrupted agent work resumes. The current draft installs the app and opens it manually. An unattended design needs a separate decision about application startup and recovery after reboot.

**Headless operation removes a large part of the setup.** For repository work, builds, tests, GitHub operations, and package installation, a guest desktop is often unnecessary. Codex supports device-code login for headless environments; the browser used to complete that authentication can be elsewhere. Browser testing can run inside the environment with headless Playwright. This avoids installing GNOME, configuring GDM/dconf, maintaining an unlocked session, and arranging a remote desktop just to log in. [Codex headless authentication](https://learn.chatgpt.com/docs/auth#login-on-headless-devices), [Playwright browser testing](https://playwright.dev/docs/running-tests).

This changes the workflow: headless testing is not identical to letting the app operate a persistent, manually signed-in Chrome profile. Keep a desktop where that browser interaction is a real requirement. There is also a middle option: OpenAI documents connecting the desktop app to a remote filesystem and shell over SSH, with Codex installed remotely. That permits a local graphical interface and remote execution without a guest graphical session. Verify the connection workflow in the actual Linux app build. Do not assume browser/plugin tools are relocated by the shell connection; browser work intended to stay isolated must execute inside the guest/sandbox too. [OpenAI SSH connections](https://learn.chatgpt.com/docs/remote-connections#connect-to-an-ssh-host).

**Docker Sandboxes deserves a trial before building more VM machinery.** Current installation documentation supports Ubuntu 24.04 or later with KVM on x86-64 or ARM64. The standalone `sbx` package does not require Docker Desktop or a host Docker Engine. This differs from early 2026 articles describing Linux support as forthcoming. Use the current documentation and installed version when evaluating it. [Installation requirements](https://docs.docker.com/ai/sandboxes/install/).

Docker describes a separate Linux kernel per sandbox, agent sudo access, and a separate Docker daemon inside the environment. Those characteristics match the desire to let an agent install packages and use Docker without administering Atlas. This is a materially different isolation model from an ordinary container sharing the host kernel or host Docker socket. [Isolation model](https://docs.docker.com/ai/sandboxes/security/isolation/).

Its filesystem and installed environment persist across stops/restarts. You can choose a directly shared project, a private clone backed by a read-only host source, or an environment without a host workspace mount. For the original “projects live inside the VM” idea, the last option is the closest match. Export or push work before deleting an environment. [Sandbox architecture and persistence](https://docs.docker.com/ai/sandboxes/architecture/).

After installing a current `sbx`, this is an illustrative small trial with no host project directory mounted:

```bash
sbx login
sbx secret set openai --oauth
sbx policy init balanced
sbx create --name yolo-trial --skills=off codex
sbx run --name yolo-trial
```

The OpenAI OAuth flow runs on the host, with the provider credential handled by the host-side mechanism. The Codex template already includes the CLI and defaults to bypassing its internal approval/sandbox prompts. Authentication and agent configuration still need to be checked for your account. [Codex integration](https://docs.docker.com/ai/sandboxes/agents/codex/).

Do not replace `create` with an unqualified `sbx run codex` and assume the same filesystem behavior: `run` defaults to mounting the current directory read-write. `--clone` protects the host checkout from writes but its read-only source includes ignored and untracked files. The mountless example avoids sharing a project directory; `--skills=off` also omits the optional shared skill store. Other explicitly configured integrations remain separate access paths. [Workspace modes](https://docs.docker.com/ai/sandboxes/usage/), [creation options](https://docs.docker.com/reference/cli/sbx/create/).

Docker also documents **ChatGPT desktop app integration over SSH**. Run `sbx setup ssh`, then add `yolo-trial.sbx` manually in the app's SSH connections and select the remote project folder. Its Codex template includes the remote executable. Full Access is a per-chat setting and is distinct from Docker's boundary. This is the most interesting middle ground: retain the app interface while removing the full guest desktop. It is a documented integration, but has not been validated on this Atlas/Linux app combination. [Docker's ChatGPT integration](https://docs.docker.com/ai/sandboxes/integrations/chatgpt/).

The SSH integration does not require a guest SSH server or an exposed TCP port; it reaches the sandbox through the local daemon. A connection can start a stopped sandbox. That removes some IP-address and SSH-server administration from a headless setup. [Editor/app SSH integration](https://docs.docker.com/ai/sandboxes/integrations/).

The main tradeoffs to evaluate are concrete:

- **Network behavior differs.** Outbound TCP is policy-controlled through a host proxy; external UDP and ICMP are blocked. The Balanced preset permits common development destinations, not arbitrary Internet access. General research, unusual dependencies, and nonstandard network applications may need policy changes or a general-purpose VM. CIDR rules are supported, so add explicit restrictions for the actual protected destinations and test them; do not assume a preset exactly matches the draft. [Local network policy](https://docs.docker.com/ai/sandboxes/governance/access-controls/local/), [rule syntax](https://docs.docker.com/ai/sandboxes/governance/concepts/).
- **Persistent storage is not an always-running process.** Version 0.43.0, released September 15, explicitly introduced automatic stopping of idle `sbx create` environments. Detached execution exists, but disconnect behavior, app-server lifetime, and reboot recovery need a real workload test before replacing an always-on VM. [Release notes](https://docs.docker.com/ai/sandboxes/release-notes/), [detached execution](https://docs.docker.com/reference/cli/sbx/exec/).
- **It introduces a Docker login/dependency.** The local CLI is currently free, including commercial use; central organization governance is separately paid. Basic CLI telemetry has an opt-out. This may still be preferable to owning more custom provisioning, but it is an explicit tradeoff. [Docker FAQ](https://docs.docker.com/ai/sandboxes/faq/).
- **It is not an established replacement for this GNOME desktop recipe.** Display-related options exist in experimental environment configuration, but I did not establish a turnkey, reboot-persistent GNOME/ChatGPT/Chrome setup equivalent to the draft. Evaluate it first as a coding environment. [Environment configuration](https://docs.docker.com/ai/sandboxes/configuration/environment-files/).

Host-side tool bridges deserve deliberate configuration with any hybrid approach. For example, Docker's local stdio MCP servers run on the host, outside the microVM. Connecting a powerful host tool or personal browser can expand what an otherwise isolated agent can affect. “Shell runs in the sandbox” alone does not describe the whole tool boundary. [MCP placement](https://docs.docker.com/ai/sandboxes/architecture/#mcp-gateway).

**The existing Incus design can be substantially shorter without changing technology.** For one or a few persistent environments, omit the reusable-image build/publish/cleanup stage initially. Use either the prebuilt desktop image plus a guest bootstrap script, or a cloud image plus cloud-init. Do not maintain both as parallel installation paths. The image catalogue currently contains the resolute/amd64 desktop VM image, and Incus documents provisioning through cloud-init. [Image catalogue](https://images.linuxcontainers.org/), [Incus cloud-init](https://linuxcontainers.org/incus/docs/main/cloud-init/).

`ATLAS.md` plus `yolo-dev.yaml` already sketches the second route. That is structurally simpler than `YOLO_SETUP.md`'s separate golden-image workflow, though the files themselves still call out fresh-install verification. Cloud-init trades slower first creation and dependence on live package/download services for fewer image lifecycle tasks. If repeated creation later makes startup time painful, build a template from the proven provisioning procedure.

For the desktop route, I would make these changes:

1. Start with one persistent Incus VM and one authoritative provisioning method.
2. Keep the host network policy outside the guest. Keep the known-listening-service test.
3. Put the repeatable work in small setup/create scripts, leaving a short operator guide. Automation reduces repeated manual work; merely moving text to scripts does not eliminate maintenance.
4. Make external Chrome optional if the app's built-in browser meets the use case. Add the extension only for workflows that need that profile. [Built-in versus external browser](https://learn.chatgpt.com/docs/chrome-extension).
5. Treat VM boot, desktop login, app launch, and task recovery as separate checks.
6. Create additional VMs for separate trust, credentials, or incompatible environments. Multiple ordinary tasks can share a VM with separate repositories/worktrees, accepting that those tasks share the same security boundary.
7. Choose CPU/RAM/disk from actual workloads. The draft's 12 CPUs, 32 GiB, and 300 GiB are choices, not prerequisites. Multiple copies multiply memory and eventual storage needs.

The Linux app remains a preview with experimental native Wayland support, and general desktop Computer Use is not yet available there. A desktop VM does not remove those product limitations. Browser integration is a separate capability. [Linux app requirements and limitations](https://learn.chatgpt.com/docs/linux/linux-app).

**Other alternatives do not obviously remove more work.** virt-manager is a reasonable choice for a manually installed desktop VM, with graphical VNC/SPICE console access. If the real goal were simply one desktop to configure interactively, it could be the easiest experience. It still leaves guest provisioning and the outbound network boundary to solve. [virt-manager](https://virt-manager.org/).

I would not add Vagrant/Packer/Terraform merely to shorten this guide; that introduces another lifecycle/configuration layer. Plain containers or another host user change the isolation assumptions. A cloud VM can move hardware administration elsewhere but introduces remote access and recurring compute/storage considerations. If Atlas is entirely disposable and dedicated to agents, using the whole machine on a separately restricted network is another architectural simplification—but it gives up the current VM separation and is a different requirement set.

**The next useful step is a small comparison with a real project.** Try one mountless or clone-mode `sbx` environment, including the app-over-SSH path if desired, and compare it with one simplified Incus VM. Check:

- Authentication, package installation, Git operations, and the project's real build/test workload.
- Browser needs: headless tests, human preview, signed-in websites, and which machine each tool actually uses.
- Access to a known listening service on Atlas, another LAN machine, and a sibling environment; verify Internet/DNS still work.
- Closing the viewer/terminal, disconnecting the app, locking or logging out of Atlas, and a host reboot, as separate events.
- Files and credentials after restarting; deliberate recovery of the interrupted agent task.
- Getting work out and rebuilding the environment. A rollback snapshot is not an independent backup.

The choice then becomes straightforward: keep Incus for a full persistent computer or strict always-on general-purpose services; use Docker Sandboxes if the coding workflow passes and the reduced administration is valuable; choose Multipass when the priority is a simple Ubuntu shell VM and you accept separately owning network and lifecycle policy.
