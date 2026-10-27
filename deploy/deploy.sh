#!/usr/bin/env bash
#
# Rebuild every app image from the checkout this script lives in, then restart
# the systemd units that run them. Run on the VM as root:
#
#   sudo ~/shiny-multiapp/deploy/deploy.sh
#
# Images are built with the pinned CRAN snapshot in the Dockerfile, so a deploy
# does not silently pick up new package versions; bump CRAN_SNAPSHOT to do that
# on purpose.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apps=(hub met trial)

if [[ $EUID -ne 0 ]]; then
  echo "deploy.sh must run as root (the containers are rootful): sudo $0" >&2
  exit 1
fi

echo "==> Building images from ${repo}"
for app in "${apps[@]}"; do
  podman build --build-arg APP="${app}" -t "shiny-${app}:latest" "${repo}"
done

# The proxy reads these from the host rather than from its image, so a change
# to the nginx config reaches it without rebuilding anything.
echo "==> Installing proxy configuration"
install -D -m 0644 -t /opt/shiny-proxy \
  "${repo}/docker/nginx.conf" \
  "${repo}/docker/nginx-tls.conf" \
  "${repo}/docker/app_routes.conf" \
  "${repo}/docker/shiny_proxy.conf"

# Restarting an app recreates its container, but the fixed addresses in the
# Quadlet units mean it comes back on the same IP, so the proxy's cached DNS
# stays valid and does not need restarting for that reason. It is restarted
# anyway, to pick up any change to the files just installed above.
echo "==> Restarting units"
systemctl restart "${apps[@]/#/shiny-}"
systemctl restart shiny-proxy

echo "==> Waiting for the apps to accept connections"
for i in {1..30}; do
  if curl -fsS -o /dev/null http://127.0.0.1/hub/; then break; fi
  [[ $i -eq 30 ]] && { echo "hub did not come up within 30s" >&2; exit 1; }
  sleep 1
done

echo "==> Health check"
for path in hub met trial; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1/${path}/")"
  printf '    /%-6s %s\n' "${path}/" "${code}"
  [[ "${code}" == "200" ]] || { echo "/${path}/ returned ${code}, not 200" >&2; exit 1; }
done

echo "==> Deployed"
