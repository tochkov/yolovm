# Set up yolo VMs on Atlas

Draft for review. This procedure has not yet been tested as a complete fresh installation.

Create a persistent Ubuntu 26.04 VM for coding agents. It runs in the background,
starts with Atlas and has a desktop available for app login and occasional use.

Each VM has `yolo` with passwordless sudo, ChatGPT, Chrome, Git, `gh` and agent
instructions. Projects go in `/home/yolo/proj`.

Prepare Atlas and the template once. Then create each VM with the command in
step 4. Run the commands on Atlas, including those that configure the guest.

## 1. Prepare Atlas

Assumes Ubuntu on an AMD or Intel workstation with hardware virtualization enabled.

Install Incus and the viewer for the VM's display:

```bash
sudo apt update
sudo apt install incus incus-client virt-viewer
sudo usermod -aG incus-admin "$USER"
sudo systemctl enable --now incus.socket incus-startup.service
```

Log out of Atlas and back in to activate the group membership. The `incus-admin`
group grants control over VMs and the host resources Incus can access.

Keep Atlas awake, with its screen locked and blank after ten minutes idle.
Run these as your desktop user, without sudo:

```bash
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.desktop.session idle-delay 600
gsettings set org.gnome.desktop.lockdown disable-lock-screen false
gsettings set org.gnome.desktop.screensaver lock-enabled true
gsettings set org.gnome.desktop.screensaver lock-delay 0
```

Super+L locks Atlas immediately. Locking Atlas leaves the VM running.

## 2. Define storage, networking and the VM profile

This uses Incus's standard YAML initialization. The `yolo` profile sets 12 CPUs,
32 GiB RAM, a disk that grows up to 300 GiB, and automatic startup.
The `dir` storage pool keeps VM files on Atlas's existing filesystem.

<details>
<summary>Create the storage pool, network and profile</summary>

```bash
incus admin init --preseed <<'YAML'
config: {}
storage_pools:
  - name: yolo
    driver: dir
    config: {}
networks:
  - name: yolobr0
    type: bridge
    config:
      ipv4.address: auto
      ipv4.nat: "true"
      ipv6.address: none
profiles:
  - name: yolo
    config:
      limits.cpu: "12"
      limits.memory: 32GiB
      boot.autostart: "true"
    devices:
      root:
        type: disk
        pool: yolo
        path: /
        size: 300GiB
      eth0:
        type: nic
        network: yolobr0
YAML
```

</details>

Apply the network restriction before creating a VM. It allows public IPv4
destinations and the bridge's required services, including DHCP and DNS.
It blocks new connections to private and local addresses, including Atlas and
the home LAN when they use those addresses.

<details>
<summary>Apply the network rules</summary>

```bash
incus network acl create yolo-internet
incus network acl edit yolo-internet <<'YAML'
description: Internet access with private and local destinations blocked
ingress:
  - action: allow
    state: enabled
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
    destination: "::/0"
  - action: allow
    state: enabled
YAML
incus network set yolobr0 security.acls=yolo-internet
```

The address groups identify networks to block. NAT alone does not provide this
restriction. These rules do not isolate VMs from each other on the same bridge.

</details>

## 3. Prepare the reusable image

Start with `images:ubuntu/26.04/desktop`. Ubuntu and GNOME are already installed.
This is the `resolute`, `amd64`, `desktop` entry in the
[Linux Containers catalogue](https://images.linuxcontainers.org/).

```bash
incus launch images:ubuntu/26.04/desktop yolo-template-build --vm --profile yolo -c boot.autostart=false
```

Wait for the guest helper that runs commands inside the VM:

```bash
timeout 180 bash -c '
  until incus exec yolo-template-build -- true 2>/dev/null; do
    sleep 2
  done
'
```

Apply the customization below. It runs as root inside the temporary VM and stops
on an error. Package configuration uses default answers.

<details>
<summary>Create yolo, install the apps and configure the session</summary>

```bash
incus exec yolo-template-build -- bash -e <<'SETUP'
export DEBIAN_FRONTEND=noninteractive

# Create the account and grant passwordless sudo.
useradd --create-home --user-group --shell /bin/bash --groups sudo yolo
echo 'yolo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/yolo
chmod 0440 /etc/sudoers.d/yolo
visudo -cf /etc/sudoers.d/yolo

# Install the apps and GitHub tools.
apt-get update
apt-get install -y curl ca-certificates git gh
curl -fL --retry 3 https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb -o /var/tmp/chatgpt.deb
curl -fL --retry 3 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /var/tmp/chrome.deb
apt-get install -y /var/tmp/chatgpt.deb /var/tmp/chrome.deb
rm /var/tmp/chatgpt.deb /var/tmp/chrome.deb

# Create the project directory and agent instructions.
mkdir -p /home/yolo/proj /home/yolo/.codex /home/yolo/.claude
cat > /home/yolo/.codex/AGENTS.md <<'INSTRUCTIONS'
You are working as yolo inside a persistent development VM.
Keep projects in /home/yolo/proj.
You have passwordless sudo. Install dependencies and configure this VM as
needed for assigned work without routine permission questions.
Use this VM's files, applications and browsers. Preserve existing work and
credentials. Keep changes inside the VM and preserve the host's network rules.
INSTRUCTIONS
cp /home/yolo/.codex/AGENTS.md /home/yolo/.claude/CLAUDE.md
chown -R yolo:yolo /home/yolo/proj /home/yolo/.codex /home/yolo/.claude

# Enter the desktop as yolo after boot.
cat > /etc/gdm3/custom.conf <<'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=yolo
GDM

# Keep the VM's session awake and unlocked.
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
cat > /etc/dconf/profile/user <<'PROFILE'
user-db:user
system-db:local
PROFILE
cat > /etc/dconf/db/local.d/00-yolo <<'DCONF'
[org/gnome/desktop/session]
idle-delay=uint32 0
[org/gnome/desktop/screensaver]
lock-enabled=false
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
[org/gnome/shell]
welcome-dialog-last-shown-version='4294967295'
DCONF
dconf update
systemctl set-default graphical.target

# Verify the installed programs, instructions and sudo access.
for app in chatgpt google-chrome-stable git gh; do
  command -v "$app"
done
runuser -u yolo -- sudo -kn true
test -s /home/yolo/.codex/AGENTS.md
test -s /home/yolo/.claude/CLAUDE.md
SETUP
```

</details>

Save the prepared VM as a local image. Reset its machine identity so new VMs
generate their own. **Sign in to apps only after creating a working VM in step 4.**

```bash
incus exec yolo-template-build -- bash -e <<'CLEAN'
printf 'uninitialized\n' > /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
CLEAN
incus stop yolo-template-build
incus publish yolo-template-build --alias yolo-template
```

`publish` saves an image locally. It does not upload it or make it public.
The image contains the installed software and configuration. The profile
contains the hardware, network attachment and startup settings.

The template is a saved starting point. Its software versions stay as built
until you rebuild it. Each working VM can update its own packages normally.

## 4. Create and use a VM

Create a configured VM with one standard Incus command:

```bash
incus launch yolo-template yolo-dev-1 --vm --profile yolo
```

The VM boots with its software already installed. Use another name to create
another VM. An existing VM with that name is not overwritten.

Open its display when needed:

```bash
incus console yolo-dev-1 --type vga
```

In the VM, open ChatGPT and sign in. Open `/home/yolo/proj` in Codex and choose
Full Access. For Chrome integration, follow the
[browser extension setup](https://learn.chatgpt.com/docs/chrome-extension).

Closing the display window leaves the VM and its applications running. To run
a command from Atlas:

```bash
incus exec yolo-dev-1 -- whoami
```

This returns `root`. The desktop and its apps run as `yolo`.

## Draft validation

Before adopting this guide, verify a fresh template and a new VM created from it.
Check automatic login, app launch, passwordless sudo, distinct machine IDs,
startup after an Atlas reboot, internet access and blocking against a known
listening service on Atlas and the LAN. Existing host firewalls may need rules
for the new bridge.

The ChatGPT Linux app currently supports browser workflows. Whole-desktop
Computer Use is not yet available in the Linux preview, according to
[OpenAI's Linux app documentation](https://learn.chatgpt.com/docs/linux/linux-app#compatibility-and-limitations).

Image contents are defined in the project's
[Ubuntu image recipe](https://github.com/lxc/lxc-ci/blob/main/images/ubuntu.yaml).
The reusable-image workflow follows
[Incus image publishing](https://linuxcontainers.org/incus/docs/main/howto/images_create/).
Network behavior follows
[Incus bridge ACL documentation](https://linuxcontainers.org/incus/docs/main/howto/network_acls/#bridge-limitations).
