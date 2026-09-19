# Set up Atlas and yolo-dev-1

Create an Ubuntu desktop VM with ChatGPT, Chrome, Git, and `gh`. Its user,
`yolo`, has passwordless sudo. Projects go in `/home/yolo/proj`.

This guide assumes Ubuntu 26.04 on an AMD or Intel workstation, an unencrypted
disk, a fresh Incus installation, and inactive UFW.

Put this guide, [yolo-dev.yaml](yolo-dev.yaml), and
[network-acl.yaml](network-acl.yaml) in `~/yolo-dev-setup` on Atlas.
Run commands on Atlas until step 5.

## 1. Install Incus

```bash
ls -l /dev/kvm
```

`/dev/kvm` gives the VM access to hardware virtualization. If it is missing,
enable SVM or VT-x in the firmware settings and reboot.

```bash
sudo apt update
sudo apt upgrade
sudo apt install incus incus-client virt-viewer curl
```

`update` refreshes package lists. `upgrade` updates installed software.

| Package | What it does |
|---|---|
| `incus` | Manages VMs, storage, and networking |
| `incus-client` | Provides the `incus` command |
| `virt-viewer` | Opens the VM's screen in a window |
| `curl` | Downloads files and checks network access |

Ubuntu also installs QEMU, which runs the VM, and OVMF, its boot firmware,
through APT dependencies and default recommendations.

Give your account permission to manage Incus and enable startup at boot:

```bash
sudo usermod -aG incus-admin "$USER"
sudo systemctl enable --now incus.socket incus-startup.service
```

`-aG` adds a group without removing existing memberships. `"$USER"` is your
username. Membership in `incus-admin` grants full Incus control, including access
to host resources.

## 2. Set screen and sleep behavior

Run these as your normal desktop user, without sudo:

```bash
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.desktop.session idle-delay 600
gsettings set org.gnome.desktop.lockdown disable-lock-screen false
gsettings set org.gnome.desktop.screensaver lock-enabled true
gsettings set org.gnome.desktop.screensaver lock-delay 0
```

These commands also clear any existing setting that forbids screen locking.
Atlas stays awake while you are logged in. After ten minutes idle, the monitors
go dark and the desktop locks. Press Super+L to lock it when leaving.
Your applications and the VM keep running while locked.

Reboot Atlas to finish updates and activate your Incus group membership.

## 3. Create storage and networking

Run this initialization once:

```bash
cd ~/yolo-dev-setup
incus admin init --auto --storage-backend=dir
incus network set incusbr0 ipv6.address=none
```

Incus stores the VM on Atlas's existing filesystem and creates `incusbr0`,
a private network with IPv4 internet access.

Apply the network rules:

```bash
incus network acl create yolo-boundary
incus network acl edit yolo-boundary < network-acl.yaml
incus network set incusbr0 security.acls=yolo-boundary
```

The rules block new connections from the VM to private and local addresses,
including Atlas and a typical home LAN. They allow public IPv4 destinations and
required network services such as DNS. Atlas can connect to the VM.

## 4. Create the VM

The profile assigns 12 virtual CPUs, 32 GiB RAM, and a 300 GiB virtual disk.
Change those values in `yolo-dev.yaml` before creating the VM if needed.
The disk grows as used. The VM starts when Atlas boots.

The profile disables the cloud image's unused network wait during installation.
The desktop uses NetworkManager's readiness check, avoiding the two-minute timeout.

```bash
incus profile create yolo-dev
incus profile edit yolo-dev < yolo-dev.yaml
incus launch images:ubuntu/26.04/cloud yolo-dev-1 --vm --profile yolo-dev
```

Wait for installation and check that the apps and project folder exist:

```bash
incus exec yolo-dev-1 -- sh -ec '
  cloud-init status --wait
  command -v chatgpt
  command -v google-chrome-stable
  command -v gh
  test -d /home/yolo/proj
'
```

Continue when the command reports `status: done`, prints all three app paths,
and finishes without errors. See the installation notes below if it fails.

Restart the VM and open its desktop:

```bash
incus restart yolo-dev-1
incus console yolo-dev-1 --type vga
```

## 5. Sign in inside the VM

The VM logs in as `yolo` and stays unlocked and awake.

1. Open ChatGPT and sign in.
2. Select Codex, open `/home/yolo/proj`, and choose Full Access.
3. Ask it to run `whoami`, `sudo -kn whoami`, and `pwd`. Expect `yolo`, `root`, and `/home/yolo/proj`.
4. Ask it to open `https://example.com` in its built-in browser and report the title.

The profile puts agent instructions in `~/.codex/AGENTS.md` and
`~/.claude/CLAUDE.md`.

To let ChatGPT control Chrome, follow the
[browser extension setup](https://learn.chatgpt.com/docs/chrome-extension) inside
the VM. The Linux app supports browser workflows. General desktop Computer Use
is [not yet available on Linux](https://learn.chatgpt.com/docs/linux/linux-app#compatibility-and-limitations).

<details>
<summary>Installation notes</summary>

An unavailable guest agent immediately after launch usually means the VM is
still booting. Wait and retry the installation check. The first boot may restart
once. Retry after that restart if `done` appears before the apps exist.

To inspect an installation failure:

```bash
incus exec yolo-dev-1 -- cloud-init status --long
incus exec yolo-dev-1 -- tail -n 80 /var/log/cloud-init-output.log
```

Editing the cloud-init source after creation does not reconfigure an existing VM.

</details>

<details>
<summary>Check network blocking before unattended work</summary>

Start a temporary web server on Atlas's VM network:

```bash
YOLO_GATEWAY=$(incus network get incusbr0 ipv4.address | cut -d/ -f1)
mkdir -p /tmp/yolo-network-check
python3 -m http.server 8765 --bind "$YOLO_GATEWAY" --directory /tmp/yolo-network-check
```

In another Atlas terminal, test it from the host and from the VM, then test a
public website:

```bash
YOLO_GATEWAY=$(incus network get incusbr0 ipv4.address | cut -d/ -f1)
curl --noproxy '*' --connect-timeout 3 --max-time 5 "http://$YOLO_GATEWAY:8765/"
incus exec yolo-dev-1 -- curl --noproxy '*' --connect-timeout 3 --max-time 5 "http://$YOLO_GATEWAY:8765/"
incus exec yolo-dev-1 -- curl -I --max-time 15 https://example.com/
```

The first request must succeed, the second must fail, and the third must succeed.
Stop the web server afterward. This verifies blocking against a service that
you know is running.

</details>

<details>
<summary>Sources and validation</summary>

References: [Incus](https://linuxcontainers.org/incus/docs/main/installing/),
[network rules](https://linuxcontainers.org/incus/docs/main/howto/network_acls/),
[cloud-init](https://linuxcontainers.org/incus/docs/main/cloud-init/),
[ChatGPT](https://learn.chatgpt.com/docs/linux/linux-app),
[Chrome](https://support.google.com/chrome/answer/95346?hl=en).

Local checks cover YAML, cloud-init schema, and shell syntax. The network wait
correction still needs verification on a fresh VM.

</details>
