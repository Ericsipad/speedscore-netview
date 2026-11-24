#!/usr/bin/env bash
# Speedscore Netview for Linux: uninstall.
#   curl -fsSL https://raw.githubusercontent.com/Ericsipad/speedscore-netview/main/uninstall.sh | sudo bash
# Keeps the results in /var/lib/speedscore-netview; add "-s -- --purge" after "bash" to delete them too.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run it with sudo." >&2; exit 1; }
purge=no
[ "${1:-}" = "--purge" ] && purge=yes
systemctl disable --now speedscore-netview.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/speedscore-netview.service
systemctl daemon-reload
# Tunnels the website made, and the firewall table of the speed tests.
for f in /etc/wireguard/nv*.conf; do
  [ -f "$f" ] || continue
  wg-quick down "$(basename "$f" .conf)" >/dev/null 2>&1 || true
  rm -f "$f"
done
nft delete table inet speedscore_netview >/dev/null 2>&1 || true
if ufw status 2>/dev/null | grep -q '^Status: active'; then
  ufw delete allow 8443/tcp >/dev/null 2>&1 || true
  ufw delete allow 51820/udp >/dev/null 2>&1 || true
fi
rm -f /etc/sudoers.d/speedscore-netview /usr/local/bin/speedscore-netview /etc/sysctl.d/60-speedscore-netview.conf
rm -rf /usr/local/lib/speedscore-netview /opt/speedscore-netview
userdel speedscore-netview >/dev/null 2>&1 || true
if [ "$purge" = yes ]; then
  rm -rf /var/lib/speedscore-netview /etc/speedscore-netview
  echo "Speedscore Netview removed, with its results, login and settings."
else
  echo "Speedscore Netview removed. The results stay in /var/lib/speedscore-netview (run with --purge to delete them)."
fi
echo "Also remove the server on your account on speedscore.net (My Account -> Connected devices)."
