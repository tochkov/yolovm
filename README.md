# yolovm

Isolated Ubuntu desktop VMs where AI agents have complete power by default:
root, a real browser, no permission prompts, and no way into your host or your
network.

```bash
yolovm host init
yolovm create yolovm-dev-1
yolovm auth yolovm-dev-1
```

That's it. Pick `yolovm-dev-1` in the Claude app on your phone and tell it what
to build. The ChatGPT app and the Chrome extensions need one visit to the VM's
desktop to sign in.

## Why

Agents in yolo mode need a machine they can break, not your laptop. Each yolovm
is a persistent Ubuntu desktop VM that starts with the host, logs itself in and
keeps working in the background, while the host and the home network stay out
of its reach.

Two CLIs over SSH would be far simpler: Codex CLI and Claude Code in a headless
VM need no GNOME, no Chrome, no autologin and no console. The desktop is there
so the agents have what a person at the machine has: the ChatGPT app with its
own browser, and computer use when it reaches Linux; Claude Code driving a real
signed-in Chrome through its extension; and a complete computer they may
install anything on. The alternatives that were weighed are in
[docs/research](docs/research).

## 0. Prerequisites

**A host.** Ubuntu 26.04 with GNOME on a 64-bit AMD or Intel machine, with
virtualization (AMD SVM or Intel VT-x) enabled in the firmware.

**Accounts.** Tailscale; a GitHub account for the agents, ideally separate from
yours; a Claude subscription with Claude Remote Control, which is part of the
Pro, Max, Team and Enterprise plans; a ChatGPT account.

**The Tailscale policy**, once per tailnet, before the first VM signs in: open
[Tailscale → Access controls](https://login.tailscale.com/admin/acls), select
**JSON editor**, replace the default policy with
[host/tailscale-policy.json](host/tailscale-policy.json), and save. It trusts
all tailnet members and blocks outgoing tailnet connections from tagged
devices; VMs enrol with `tag:yolovm`.

**This repository**, on the host:

```bash
git clone https://github.com/tochkov/yolovm && cd yolovm
```

Then put the command on your PATH:

```bash
mkdir -p ~/.local/bin && ln -sfn "$PWD/yolovm" ~/.local/bin/yolovm
export PATH="$HOME/.local/bin:$PATH"
```

The link makes it `yolovm` instead of `./yolovm` from here on; the `export`
makes that work in the current terminal, and Ubuntu adds `~/.local/bin` to your
PATH by itself at the next login. This is a workaround until yolovm has a proper
installer.

<details>
<summary>tailscale-policy.json</summary>

```json
{
  "tagOwners": {
    "tag:yolovm": ["autogroup:admin"]
  },
  "grants": [
    {
      "src": ["autogroup:member"],
      "dst": ["*"],
      "ip": ["*"]
    }
  ],
  "ssh": [
    {
      "action": "check",
      "src": ["autogroup:member"],
      "dst": ["autogroup:self"],
      "users": ["autogroup:nonroot", "root"]
    },
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:yolovm"],
      "users": ["ubuntu"]
    }
  ]
}
```

- `tagOwners`: administrators can assign `tag:yolovm`.
- `grants`: user-owned devices can start connections to any tailnet destination
  on any port. Tagged VMs do not match the source, so they cannot start any.
  Replies to incoming connections are allowed.
- `ssh`: keeps SSH between a user's own devices and lets tailnet members SSH into
  tagged VMs as `ubuntu`.

Tagged devices also have no key expiry. For a tailnet with custom rules, merge
these settings and remove any existing rules or grants that let tagged devices
start connections.

Both network policies matter: Incus restricts direct private-network access, and
Tailscale restricts access through its encrypted tunnel. See
[Tailscale grants](https://tailscale.com/docs/reference/syntax/grants).

</details>

## 1. Prepare the host

```bash
yolovm host init --keep-awake --lock-after 10
```

Then **log out of the host and back in** to activate your Incus access.
`--keep-awake` stops the host from
suspending on its own, which would stop the VMs. `--lock-after 10` blanks and
locks its screen after ten idle minutes, and `0` means never. Leave either out
to keep your own settings. **Super+L** locks the host at once; a locked host
keeps its VMs running.

<details>
<summary>What host init does</summary>

1. Checks that the host runs Ubuntu 26.04 and that `/dev/kvm` exists.
2. Installs Incus 7.0 LTS from [Zabbly](https://github.com/zabbly/incus#installation),
   whose package includes QEMU, plus `virt-viewer` for the VM screen, using
   [host/zabbly-incus.sources](host/zabbly-incus.sources).
3. Enables `incus.socket` and `incus-startup.service` and adds you to `incus-admin`.
4. Loads [host/incus-preseed.yaml](host/incus-preseed.yaml). Incus merges it
   into an existing setup; yolovm preserves the bridge's existing subnet on repeat runs.

```yaml
config: {} # Keep Incus's global defaults.

storage_pools:
  - name: yolovm-storage
    driver: dir # Store VM disks as files on the host.
    config: {}

networks:
  - name: yolovmbr0
    type: bridge
    config:
      ipv4.address: auto # Choose a private subnet automatically.
      ipv4.nat: "true" # Give VMs internet access through the host.
      ipv6.address: none # Use IPv4 only.

# CPU, memory and disk are not set here: `yolovm create` sets them per VM,
# because a change to the profile would apply to every existing VM.
profiles:
  - name: yolovm-dev
    config:
      boot.autostart: "true" # Start VMs when the host boots.
    devices:
      root:
        type: disk
        pool: yolovm-storage
        path: /
      eth0:
        type: nic
        network: yolovmbr0 # Connect each VM to this network.
        security.port_isolation: "true" # Block direct traffic between VMs using this profile.
```

5. Creates the `yolovm-internet` ACL from [host/network-acl.yaml](host/network-acl.yaml)
   and attaches it to the bridge. VMs reach the internet; the host, the home LAN
   and other private or local addresses are rejected. Incus still allows the
   bridge's own DHCP and DNS.

```yaml
description: Internet access with private and local destinations blocked

# Incus allows the bridge's DHCP and DNS services separately.
# VM-to-VM isolation is set on the NIC in incus-preseed.yaml.

# Traffic toward a VM. This does not forward ports from the internet.
ingress:
  - action: allow
    state: enabled # Activate this rule.

# Traffic leaving a VM. Rejection rules take priority over allow rules.
egress:
  - description: Private IPv4 networks
    action: reject
    state: enabled
    destination: 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
  - description: Shared and link-local addresses
    action: reject
    state: enabled
    destination: 100.64.0.0/10,169.254.0.0/16
  - description: Special-purpose IPv4 addresses
    action: reject
    state: enabled
    destination: 0.0.0.0/8,127.0.0.0/8,224.0.0.0/4,240.0.0.0/4
  - action: reject
    state: enabled
    destination: "::/0" # Block all IPv6 destinations.
  - action: allow # Allow destinations not rejected above.
    state: enabled
```

6. Copies the Ubuntu 26.04 Desktop image from the `images:` server into the
   local store as `yolovm-desktop`, with automatic updates. `create` launches
   from that copy, so it never waits on the image server.
7. With `--keep-awake`, sets `sleep-inactive-ac-type 'nothing'` for your
   desktop user, which prevents automatic suspend on AC power. With
   `--lock-after N`, sets `idle-delay` to N minutes and the lock settings so the
   desktop locks as soon as the screen blanks. Neither changes battery,
   lid-close or login-screen behaviour. If the host sleeps, the VMs stop working
   until it wakes.

</details>

## 2. Create a VM

```bash
yolovm create yolovm-dev-1 --cpu 4 --mem 16 --disk 100
```

This launches the VM from the local Ubuntu 26.04 Desktop image, waits for it,
provisions the `dev` role and restarts it. It takes a few minutes. Memory and
disk are in GiB, and all three options can be left out (defaults: 4 CPUs,
8 GiB memory, 50 GiB disk, which uses space only as data is written).

<details>
<summary>What provisioning does</summary>

The image already provides GNOME, the `ubuntu` account with passwordless sudo,
automatic login, and a session that never locks. `create` copies the
[guest](guest) directory into the VM and runs `yolovm-guest provision`, which
is safe to run again at any time with `yolovm provision NAME`; it changes only
what differs.

**Base, for every role**

| Part | What it does |
| --- | --- |
| System | Disables networkd's unused wait-online service, which otherwise delays boot; sets GNOME to never blank or suspend, marks its first-login wizards as done, and hides Ubuntu's crash-report pop-ups, which `doctor` lists instead; applies pending package updates; installs Git and `gh`. |
| Keyring | Creates the desktop keyring without a password. With automatic login nothing can unlock one, so the first app that needs it, Chrome or the ChatGPT app, would ask you to invent a password. Secrets in it are unencrypted on disk, like everything else on a VM whose login has no password. |
| Remote desktop | Enables GNOME's Desktop Sharing over RDP with remote control and a self-signed certificate, so the service starts with every session. `auth` sets a random password the first time, and `auth` and `desktop` print the login. |
| Tailscale | Installs Tailscale and enables its service. |
| Instructions | Writes [guest/base/instructions.md](guest/base/instructions.md) to `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` and creates `~/proj`. |
| Claude Code | Installs the CLI on the stable channel; merges [guest/base/claude-settings.json](guest/base/claude-settings.json) into `~/.claude/settings.json`; pre-answers the three first-run dialogs in `~/.claude.json` so only the login remains; installs the Claude Remote Control service. |

```json
{
  "permissions": { "defaultMode": "bypassPermissions" },
  "skipDangerousModePermissionPrompt": true,
  "autoUpdatesChannel": "stable",
  "theme": "dark",
  "tui": "fullscreen"
}
```

**Role dev**

| Part | What it does |
| --- | --- |
| Apps | Installs the ChatGPT app and Chrome from their official packages, which also register their update repositories. |
| Chrome | Makes Chrome the default browser, marks its first run as done so the terms dialog and welcome page never appear, and installs two policy files under `/etc/opt/chrome/policies/managed`. [chrome-extensions.json](guest/roles/dev/chrome-extensions.json) adds the [ChatGPT](https://chromewebstore.google.com/detail/chatgpt/hehggadaopoacecdllhhajmbjkdcmajg) and [Claude](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn) extensions when Chrome starts; `normal_installed` lets you disable them. [chrome-settings.json](guest/roles/dev/chrome-settings.json) makes Google the search engine, which also skips the search-engine choice screen; turns off browser sign-in and its prompt, the welcome tabs, the default-browser nag, the ad-privacy prompt and usage reporting; blocks notification and location requests from sites and never offers to save passwords; restores the last session at start; and keeps Chrome running when its windows close so the extensions stay available. Edit that file and run `yolovm provision NAME` to change any of it. |
| Codex | Sets `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` in `~/.codex/config.toml`, keeping whatever the app adds. The app's permission selector can still override them. |
| Boot | Adds autostart entries so the ChatGPT app and Chrome open with the desktop session. |

**What starts at boot**

The VM starts with the host (`boot.autostart`), logs into GNOME, and the
session starts the ChatGPT app, Chrome, remote desktop sharing on port 3389,
and Claude Remote Control, the part of Claude Code that lets claude.ai/code and
the Claude mobile app drive sessions on this VM, run by the service below.
Tailscale reconnects on its own and, being tagged, never expires. Nothing needs
a hand after a reboot.

```ini
[Unit]
Description=Claude Remote Control
After=graphical-session.target
PartOf=graphical-session.target

[Service]
WorkingDirectory=%h/proj
ExecStart=%h/.local/bin/claude remote-control --name %H --permission-mode bypassPermissions
StandardOutput=null
Restart=always
RestartSec=10

[Install]
WantedBy=graphical-session.target
```

Its status display redraws every second, so stdout is discarded; errors still
reach the journal. Until the Claude login exists it retries every ten seconds.

</details>

## 3. Sign in

```bash
yolovm auth yolovm-dev-1
```

Each service that is not yet signed in prints a link. Open it on any device,
enter the code if asked, and the credentials stay inside the VM:

- **Tailscale** joins the tailnet with `tag:yolovm` and SSH enabled. Confirm the
  tag in [Tailscale → Machines](https://login.tailscale.com/admin/machines); an
  untagged VM inherits its user's access instead of the restriction.
- **GitHub** signs `gh` in over HTTPS and configures Git to use it. The GitHub
  login becomes the commit name, and the account's GitHub noreply address the
  commit email, so commits count as its own.
- **Claude** signs the CLI in; paste the code the page shows. Claude Remote
  Control connects within ten seconds.

It ends with the remote desktop login: the user `ubuntu` and a random password
set once per VM, which `yolovm desktop NAME` prints again. `--no-tailscale`,
`--no-gh` and `--no-claude` skip a service you do not want.

Then open the desktop for the two sign-ins that only work there:

```bash
yolovm desktop yolovm-dev-1
```

1. **ChatGPT:** sign in, open `/home/ubuntu/proj` in Codex, and check that its
   permission selector shows Full access.
2. **Chrome:** sign into the ChatGPT and Claude extensions, then finish ChatGPT's
   [browser connection setup](https://learn.chatgpt.com/docs/chrome-extension).

## 4. Get in

|         | From the host          | From anywhere on your tailnet |
| ------- | ---------------------- | ----------------------------- |
| Shell   | `yolovm sh yolovm-dev-1` | `ssh ubuntu@yolovm-dev-1` |
| Desktop | `yolovm desktop yolovm-dev-1` | any RDP client to `yolovm-dev-1`, see below |
| Claude  | | [claude.ai/code](https://claude.ai/code) and the Claude mobile app |

Shell and desktop from the host go through Incus and need no network. SSH goes
through Tailscale SSH, so no keys are needed. `yolovm sh NAME 'command'` runs
one command. Closing the viewer, the shell or the host terminal leaves the VM
and its applications running.

Remote desktop is GNOME's own Desktop Sharing over RDP, which provisioning
enables with remote control and a self-signed certificate, so the client warns
about it once. `yolovm desktop NAME` prints the login and, from the host's own
desktop, also opens the VM's screen through Incus. Any RDP client on your
tailnet, such as Windows App on macOS or Remmina on Linux, connects to the VM's
name on port 3389 with that login.

## 5. Check a VM

```bash
yolovm doctor yolovm-dev-1
```

The report is grouped into apps, boot, sign-in, settings and network, and ends
with counts of passed, failed and skipped checks. `!!` means a failure; `--`
means a check could not be attempted. Ping probes expect the internet to answer
and the host's bridge address and an online personal tailnet device not to
answer. No reply is the expected result, but does not prove firewall isolation;
probe errors are failures, and a missing tailnet peer is a skip. Expired sign-ins
show up here too; `yolovm auth NAME` repairs them. `yolovm doctor` alone checks
the host.

## Day to day

```text
yolovm host init [--keep-awake] [--lock-after MIN]
                               install Incus; define storage, network, ACL, profile and image;
                               never suspend the host; blank and lock its screen after MIN idle minutes
yolovm create NAME [--role dev] [--cpu 4] [--mem 8] [--disk 50]
                               launch a VM, provision it, restart it; sizes in GiB
yolovm provision NAME [ROLE]   push the guest bundle and run it; safe to repeat
yolovm auth NAME [--no-tailscale] [--no-gh] [--no-claude]
                               sign in to Tailscale, GitHub and Claude where missing, or skip some;
                               print the desktop login
yolovm doctor [NAME]           check this host, or a VM
yolovm desktop NAME            print the remote desktop login; open the VM's screen when this host has one
yolovm sh NAME [CMD...]        shell in the VM as ubuntu
yolovm ls | start | stop | restart | snapshot | delete NAME
                               stop and restart take --force to cut the power;
                               delete attempts Tailscale logout, then removes the VM
yolovm version                 print the version
```

`stop` and `restart` first let the desktop apps close, then power the VM off
from inside, ignoring the desktop's shutdown inhibitors. A plain power-off kills
a browser and its helper processes at once, which Chrome and the ChatGPT app
report as a crash after the next boot. With `--force` they cut the power
instead. `snapshot` before something risky; `provision`, then `restart`, after
editing anything under `guest/`.

`delete` attempts Tailscale logout if the VM is running, then removes the VM.
It reports whether logout succeeded or was skipped or failed. Remove the machine
in [Tailscale → Machines](https://login.tailscale.com/admin/machines) before
reusing its name, or the next VM gets a numbered name such as `yolovm-dev-1-1`.

Repeat steps 2 and 3 for more VMs. VMs on the `yolovm-dev` profile cannot talk
to each other on the bridge, and with the Tailscale policy they cannot start
connections to each other through the tailnet either.

## Layout

```text
yolovm                 host command
host/                  Zabbly source, Incus preseed, network ACL, Tailscale policy
guest/yolovm-guest     runs inside a VM: provision | auth | desktop | status | poweroff
guest/base/            instructions, GNOME settings, Claude settings, Claude Remote Control unit
guest/roles/dev/       ChatGPT and Chrome autostart, Chrome policies, Codex config
docs/                  research and earlier drafts
```

A new role is a `provision_NAME` function in `guest/yolovm-guest` with matching
`status_NAME_apps`, `status_NAME_boot` and `status_NAME_settings` functions,
plus its files under `guest/roles/NAME/`.

## Versions

`yolovm version` prints the version. Versions follow SemVer from 0.1.0: the
middle number moves when a command or the file layout changes, the last number
for fixes. Each version is a git tag, such as `v0.1.0`.
