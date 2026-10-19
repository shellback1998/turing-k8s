#!/usr/bin/env bash
# Installs the lab settings exported by playbooks/academy-viewer.yml on the Academy host
# (turing-manager), checks it can reach the cluster and the viewer, restarts both sites, and
# deletes the bundle. Run as: sudo ./academy-labs-bundle/install.sh
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
etc=${ACADEMY_ETC:-/etc/scottacademy}   # overridable for testing only
# Its own folder: /etc/scottacademy is root-only (0700), so the site user could not reach a subfolder.
dest=${ACADEMY_LABS_DEST:-/etc/scottacademy-labs}
owner=${ACADEMY_OWNER:-piadmin}
systemctl=${SYSTEMCTL:-systemctl}
declare -A envfile=([live]=$etc/academy-web.env [dev]=$etc/academy-dev.env)
declare -A unit=([live]=scottacademy-web [dev]=scottacademy-dev-web)

[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo $0" >&2; exit 1; }
id "$owner" >/dev/null || { echo "User $owner not found" >&2; exit 1; }
for f in controller.token cluster-ca.crt viewer.crt viewer.key viewer-json.key live.env dev.env; do
  [[ -s "$here/$f" ]] || { echo "Missing $f in $here" >&2; exit 1; }
done

api=$(sed -n 's/^ACADEMY_LABS_K8S_URL=//p' "$here/live.env")
viewer=$(sed -n 's/^ACADEMY_VIEWER_URL=//p' "$here/live.env")

echo "Checking the cluster API at $api as the lab controller..."
code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 --cacert "$here/cluster-ca.crt" \
  -H "Authorization: Bearer $(cat "$here/controller.token")" "$api/api/v1/namespaces/academy-labs/pods")
[[ $code == 200 ]] || { echo "  expected 200, got $code. Nothing was changed." >&2; exit 1; }
echo "Checking the viewer at $viewer/ ..."
code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$viewer/")
[[ $code == 200 ]] || { echo "  expected 200, got $code. Nothing was changed." >&2; exit 1; }

install -d -m 0750 -o "$owner" -g "$owner" "$dest"
for f in controller.token cluster-ca.crt viewer.crt viewer.key viewer-json.key; do
  install -m 0600 -o "$owner" -g "$owner" "$here/$f" "$dest/$f"
done

# Prove the site's own user can read them before restarting anything.
if [[ $owner != root ]]; then
  sudo -u "$owner" cat "$dest/viewer-json.key" >/dev/null \
    || { echo "  $owner can't read $dest; sites not restarted" >&2; exit 1; }
fi

for site in live dev; do
  file=${envfile[$site]}
  if [[ ! -f $file ]]; then echo "  $file not found; skipping the $site site"; continue; fi
  cp -p "$file" "$file.bak-labs"
  sed -i '/^# Scott Academy labs/d; /^ACADEMY_LABS_/d; /^ACADEMY_VIEWER_/d' "$file"
  sed "s#^ACADEMY_LABS_DIR=.*#ACADEMY_LABS_DIR=$dest#" "$here/$site.env" >> "$file"
  "$systemctl" restart "${unit[$site]}"
  echo "  $site site: settings written to $file, ${unit[$site]} restarted"
done

rm -rf "$here"
echo "Done. Labs are configured; the bundle has been deleted."
