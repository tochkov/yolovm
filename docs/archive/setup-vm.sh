#!/bin/bash
# Run inside the Incus Ubuntu Desktop image, as shown in README.md.
set -e -o pipefail

# Shared instructions for Codex (AGENTS.md) and Claude Code (CLAUDE.md).
# Edit the Markdown below to change both.
AGENT_INSTRUCTIONS=$(cat <<'INSTRUCTIONS'
# This machine is all YOURS.

You have unrestricted passwordless sudo. Install dependencies and configure this
Ubuntu system as needed for assigned work without routine permission questions.
Use this machine's files, applications, browsers, etc. Do not stop to ask for
permissions.

Preserve existing projects, credentials, and ongoing work.

Report changes that affect future sessions.
INSTRUCTIONS
)
readonly AGENT_INSTRUCTIONS

id ubuntu >/dev/null

# NetworkManager handles networking; skip networkd's unused boot check.
systemctl disable --now systemd-networkd-wait-online.service

# The image provides ubuntu, passwordless sudo and automatic desktop login.
# Disable idle blanking and automatic suspend.
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
cat > /etc/dconf/profile/user <<'PROFILE'
user-db:user
system-db:local
PROFILE
cat > /etc/dconf/db/local.d/00-yolovm <<'DCONF'
[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
DCONF
dconf update

# Install download tools, Git and the GitHub CLI.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates git gh

# ChatGPT.
curl -fL https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb -o /var/tmp/chatgpt.deb
apt-get install -y /var/tmp/chatgpt.deb
rm /var/tmp/chatgpt.deb

# Google Chrome.
curl -fL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /var/tmp/chrome.deb
apt-get install -y /var/tmp/chrome.deb
rm /var/tmp/chrome.deb

# Chrome extensions: ChatGPT (OpenAI) and Claude (Anthropic).
# https://chromewebstore.google.com/detail/chatgpt/hehggadaopoacecdllhhajmbjkdcmajg
# https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn
mkdir -p /etc/opt/chrome/policies/managed
cat > /etc/opt/chrome/policies/managed/yolovm-extensions.json <<'EXTENSIONS'
{
  "ExtensionSettings": {
    "hehggadaopoacecdllhhajmbjkdcmajg": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "fcoeoabgfenejglbffodgkkbkcdhcgfn": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    }
  }
}
EXTENSIONS

# Claude Code (stable), installed for ubuntu.
curl -fsSL https://claude.ai/install.sh | runuser -l ubuntu -c 'bash -s stable'

# Tailscale.
curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled

# Create the project directory and agent instructions.
mkdir -p /home/ubuntu/proj /home/ubuntu/.codex /home/ubuntu/.claude
printf '%s\n' "$AGENT_INSTRUCTIONS" > /home/ubuntu/.codex/AGENTS.md
printf '%s\n' "$AGENT_INSTRUCTIONS" > /home/ubuntu/.claude/CLAUDE.md

# Set permission defaults for ubuntu's Codex and Claude Code sessions.
cat > /home/ubuntu/.codex/config.toml <<'CODEX'
approval_policy = "never"
sandbox_mode = "danger-full-access"
CODEX
cat > /home/ubuntu/.claude/settings.json <<'CLAUDE'
{
  "autoUpdatesChannel": "stable",
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "skipDangerousModePermissionPrompt": true,
  "theme": "dark",
  "tui": "fullscreen"
}
CLAUDE

# Skip Claude's onboarding wizard; account login is still required.
python3 - <<'PYTHON'
import json
from pathlib import Path

path = Path('/home/ubuntu/.claude.json')
config = json.loads(path.read_text()) if path.exists() else {}
config['hasCompletedOnboarding'] = True
path.write_text(json.dumps(config, indent=2) + '\n')
PYTHON

# Use Chrome for web links and HTML files.
mkdir -p /home/ubuntu/.config
cat > /home/ubuntu/.config/mimeapps.list <<'BROWSER'
[Default Applications]
x-scheme-handler/http=google-chrome.desktop;
x-scheme-handler/https=google-chrome.desktop;
text/html=google-chrome.desktop;
application/xhtml+xml=google-chrome.desktop;
BROWSER

# Give ubuntu ownership of its home, including files created as root above.
chown -R ubuntu:ubuntu /home/ubuntu

# Verify the installed programs, instructions and sudo access.
for app in chatgpt google-chrome-stable git gh tailscale; do
  command -v "$app"
done
runuser -l ubuntu -c 'claude --version'
runuser -u ubuntu -- sudo -kn true
test -s /home/ubuntu/.codex/AGENTS.md
test -s /home/ubuntu/.claude/CLAUDE.md

echo 'VM setup complete. Restart this VM from the host.'
