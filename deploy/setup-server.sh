#!/usr/bin/env bash
# One-time server preparation for landing deploys. Run as root; safe to run again.
#
#   setup-server.sh DEPLOY_PUBLIC_KEY_FILE
#
# - user "landing" owns the site folder /var/www/percrm.ru: no password, no sudo, no docker
# - CI logs in with its SSH key and can only rsync into that folder (rrsync)
# - nginx already serves percrm.ru from that folder, so its config is not touched
# Nothing else on the server (other users, sites, keys) is changed.
set -euo pipefail

key_file="${1:?usage: setup-server.sh DEPLOY_PUBLIC_KEY_FILE}"
site_dir=/var/www/percrm.ru

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)"; exit 1; }

echo "==> rsync"
command -v rsync >/dev/null || { apt-get update; apt-get install -y rsync; }
rrsync="$(command -v rrsync)" || { echo "rrsync not found (it ships with the rsync package)"; exit 1; }
# sed reads the whole output: with head, rsync can get SIGPIPE and pipefail stops the script
rsync --version | sed -n 1p

echo "==> User landing (no password, no sudo, no docker)"
id landing >/dev/null 2>&1 || useradd --create-home --shell /bin/bash landing
id landing

echo "==> SSH key for GitHub Actions"
install -d -m 700 -o landing -g landing /home/landing/.ssh
# restrict: no forwarding and no terminal; the only allowed command is rsync writing into the site folder
printf 'command="%s -wo %s",restrict %s\n' "$rrsync" "$site_dir" "$(cat "$key_file")" > /home/landing/.ssh/authorized_keys
chown landing:landing /home/landing/.ssh/authorized_keys
chmod 600 /home/landing/.ssh/authorized_keys
ssh-keygen -l -f /home/landing/.ssh/authorized_keys

echo "==> Site folder $site_dir (owned by landing, readable by nginx)"
install -d "$site_dir"
chown -R landing:landing "$site_dir"
chmod 755 "$site_dir"
ls -la "$site_dir"

echo "==> Done"
