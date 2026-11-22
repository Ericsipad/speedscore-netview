#!/usr/bin/env bash
# Speedscore Netview for Linux: install on Ubuntu (24.04 LTS or newer; x86_64 or arm64).
#
#   curl -fsSL https://raw.githubusercontent.com/Ericsipad/speedscore-netview/main/install.sh | sudo bash
#
# Then open the setup page it prints (https://<this server's IP>:8443), sign in with admin / speedscore, choose your own
# password and type the link key it shows on speedscore.net. Every other setting is made on speedscore.net.
set -euo pipefail

# The public GitHub repository the program is downloaded from (its bin/ folder).
REPO="Ericsipad/speedscore-netview"

RELEASE_URL="https://raw.githubusercontent.com/$REPO/main/bin"
USER_NAME=speedscore-netview
BIN_DIR=/opt/speedscore-netview/bin
BIN="$BIN_DIR/speedscore-netview"
STATE_DIR=/var/lib/speedscore-netview
CONF_DIR=/etc/speedscore-netview
UNIT=/etc/systemd/system/speedscore-netview.service
HELPER_DIR=/usr/local/lib/speedscore-netview
SUDOERS=/etc/sudoers.d/speedscore-netview
PAGE_PORT=8443

say() { printf '%s\n' "$*"; }
fail() { printf '\nSpeedscore Netview install: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || fail "run it with sudo:  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sudo bash"

# Ubuntu 24.04 or newer only.
[ -r /etc/os-release ] || fail "this is not Ubuntu. Speedscore Netview runs on Ubuntu 24.04 LTS or newer."
. /etc/os-release
[ "${ID:-}" = ubuntu ] || fail "this is ${PRETTY_NAME:-not Ubuntu}. Speedscore Netview runs on Ubuntu 24.04 LTS or newer."
major="${VERSION_ID%%.*}"
[ "$major" -ge 24 ] 2>/dev/null || fail "this is $PRETTY_NAME. Speedscore Netview needs Ubuntu 24.04 LTS or newer."

case "$(uname -m)" in
  x86_64) ARCH=x86_64 ;;
  aarch64) ARCH=aarch64 ;;
  *) fail "this machine type ($(uname -m)) is not supported. Speedscore Netview runs on x86_64 and arm64." ;;
esac

say "Installing Speedscore Netview on $PRETTY_NAME ($ARCH)."

say "- system packages (WireGuard tools, nftables)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q >/dev/null
apt-get install -y -q curl sudo wireguard-tools nftables >/dev/null

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if [ -n "${SPEEDSCORE_NETVIEW_BINARY:-}" ]; then
  # The project's own CI installs the binary it just built.
  cp "$SPEEDSCORE_NETVIEW_BINARY" "$tmp/speedscore-netview"
else
  say "- downloading the program from github.com/$REPO"
  curl -fsSL "$RELEASE_URL/speedscore-netview-$ARCH" -o "$tmp/speedscore-netview" || fail "the download failed."
  curl -fsSL "$RELEASE_URL/speedscore-netview-$ARCH.sha256" -o "$tmp/sum" || fail "the checksum download failed."
  want="$(cut -d' ' -f1 "$tmp/sum")"
  have="$(sha256sum "$tmp/speedscore-netview" | cut -d' ' -f1)"
  [ "$want" = "$have" ] || fail "the downloaded program does not match its checksum; nothing was installed."
fi
[ "$(head -c 4 "$tmp/speedscore-netview" | od -An -tx1 | tr -d ' \n')" = 7f454c46 ] || fail "the downloaded file is not a Linux program."

say "- unprivileged pings (ICMP datagram sockets for every user, as Ubuntu ships it)"
printf 'net.ipv4.ping_group_range = 0 2147483647\n' > /etc/sysctl.d/60-speedscore-netview.conf
sysctl -q -p /etc/sysctl.d/60-speedscore-netview.conf

say "- the service user and folders"
id "$USER_NAME" >/dev/null 2>&1 || useradd --system --home-dir "$STATE_DIR" --no-create-home --shell /usr/sbin/nologin "$USER_NAME"
# The program lives in a folder the service user owns, so the service can update itself.
install -d -m 755 -o "$USER_NAME" -g "$USER_NAME" /opt/speedscore-netview "$BIN_DIR"
install -m 755 -o "$USER_NAME" -g "$USER_NAME" "$tmp/speedscore-netview" "$BIN.new"
mv -f "$BIN.new" "$BIN"
ln -sf "$BIN" /usr/local/bin/speedscore-netview
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "$STATE_DIR"
install -d -m 755 "$CONF_DIR"
[ -f "$CONF_DIR/config.toml" ] || printf '# Speedscore Netview. Every setting is made on speedscore.net; this file only says where Speedscore is.\napi_url = "https://api.speedscore.net"\n' > "$CONF_DIR/config.toml"
chmod 644 "$CONF_DIR/config.toml"

say "- the WireGuard helper (tunnels made on speedscore.net)"
install -d -m 755 "$HELPER_DIR"
cat > "$HELPER_DIR/wg-helper" <<'HELPER'
#!/bin/sh
# Speedscore Netview: brings a WireGuard tunnel made on the website up or down. Root-owned; the service user may run
# only this (see /etc/sudoers.d/speedscore-netview). The tunnel file is copied to /etc/wireguard (only root can write
# there) and checked there, so nothing the service user changes afterwards is used, and wg-quick never runs commands
# from it.
set -eu
action="${1:-}"
name="${2:-}"
case "$action" in up|down) ;; *) echo "usage: wg-helper up|down <name>" >&2; exit 2 ;; esac
printf '%s' "$name" | grep -Eq '^nv[a-z0-9]{1,13}$' || { echo "bad tunnel name" >&2; exit 2; }
src="/var/lib/speedscore-netview/wg/$name.conf"
dst="/etc/wireguard/$name.conf"
umask 077
mkdir -p /etc/wireguard
if [ "$action" = "up" ]; then
  [ -f "$src" ] && [ ! -L "$src" ] || { echo "no tunnel file" >&2; exit 3; }
  cp "$src" "$dst.tmp"
  if grep -Eiq '^[[:space:]]*(preup|postup|predown|postdown|saveconfig)[[:space:]]*=' "$dst.tmp"; then
    rm -f "$dst.tmp"
    echo "the tunnel file asks to run commands; refused" >&2
    exit 3
  fi
  mv "$dst.tmp" "$dst"
fi
[ -f "$dst" ] || exit 0
wg-quick "$action" "$name"
[ "$action" = down ] && rm -f "$dst"
exit 0
HELPER
chown root:root "$HELPER_DIR/wg-helper"
chmod 755 "$HELPER_DIR/wg-helper"
printf '%s ALL=(root) NOPASSWD: %s/wg-helper up *, %s/wg-helper down *\n' "$USER_NAME" "$HELPER_DIR" "$HELPER_DIR" > "$SUDOERS.tmp"
chmod 440 "$SUDOERS.tmp"
visudo -cf "$SUDOERS.tmp" >/dev/null || { rm -f "$SUDOERS.tmp"; fail "the sudo rule for WireGuard was refused by visudo."; }
mv -f "$SUDOERS.tmp" "$SUDOERS"

say "- the service"
cat > "$UNIT" <<'UNITFILE'
[Unit]
Description=Speedscore Netview (links this server to your Speedscore account)
Documentation=https://github.com/Ericsipad/speedscore-netview
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=speedscore-netview
Group=speedscore-netview
ExecStart=/opt/speedscore-netview/bin/speedscore-netview run
# A self-update replaces the program and exits; systemd then starts the new one.
Restart=always
RestartSec=5
# nftables: the speed test ports are opened for the visitor's IP only, while the test runs.
# Without a test they give no answer to anyone.
AmbientCapabilities=CAP_NET_ADMIN
Environment=SPEEDSCORE_NETVIEW_CONFIG=/etc/speedscore-netview/config.toml
Environment=SPEEDSCORE_NETVIEW_STATE=/var/lib/speedscore-netview
ProtectHome=true
PrivateTmp=true
UMask=0077

[Install]
WantedBy=multi-user.target
UNITFILE
systemctl daemon-reload
systemctl enable speedscore-netview.service >/dev/null 2>&1
systemctl restart speedscore-netview.service

if ufw status 2>/dev/null | grep -q '^Status: active'; then
  say "- opening port $PAGE_PORT (the setup page) in ufw"
  ufw allow "$PAGE_PORT/tcp" comment 'Speedscore Netview setup page' >/dev/null
fi

local_ips="$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.' | head -n 3 | tr '\n' ' ' || true)"

say ""
say "Speedscore Netview is installed and running."
say ""
say "Open the setup page in your browser:"
for ip in $local_ips; do say "    https://$ip:$PAGE_PORT"; done
say "    https://<this server's public IP>:$PAGE_PORT   (from outside, when port $PAGE_PORT reaches this server)"
say ""
say "Your browser warns about the certificate the first time (it is this server's own); continue to the page."
say "Sign in with:   user  admin   password  speedscore"
say "You then choose your own password, and the page shows the link key to type on speedscore.net"
say "(My Account -> Connected devices -> Add a server)."
say ""
say "All services on this server are managed in your Speedscore web dashboard."
