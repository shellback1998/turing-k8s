#!/usr/bin/env bash
# Throwaway end-to-end test of cluster-setup.yaml on a local K3s-in-Docker cluster.
# Never touches the real cluster: it uses its own container and kubeconfig.
#   academy-labs/test-local.sh <image-tar> <image-ref> [k3s-image]
# Optional: K3S_AIRGAP=<k3s-airgap-images-<arch>.tar.zst> to load K3s's own images offline.
# Optional: SANDBOX_RUNC_WRAP=1 when running inside a sandbox that forbids negative oom_score_adj
#           (pods fail with "failed to update /proc/self/oom_score_adj"). Never needed on real nodes.
set -Eeuo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tar="$1"; image="$2"; k3s_image="${3:-rancher/k3s:v1.36.4-k3s1}"
name=academy-labs-test
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT
pass() { echo "PASS  $*"; }
ready() { k -n academy-labs wait --for=condition=Ready "pod/$1" --timeout=180s >/dev/null || {
  k -n academy-labs describe pod "$1" | tail -25; k -n academy-labs get events --sort-by=.lastTimestamp | tail -10
  fail "lab pod $1 did not start"; }; }
fail() { echo "FAIL  $*" >&2; exit 1; }

docker rm -f "$name" >/dev/null 2>&1 || true
# Hosts still on cgroup v1 (some CI/dev containers) need kubelet's opt-in; real nodes use v2.
extra=(); [[ "$(docker info -f '{{.CgroupVersion}}')" == 1 ]] && extra=(--kubelet-arg=fail-cgroupv1=false)
airgap=(); [[ -n "${K3S_AIRGAP:-}" ]] && airgap=(-v "$K3S_AIRGAP:/var/lib/rancher/k3s/agent/images/k3s-airgap-images.tar.zst:ro")
docker run -d --name "$name" --privileged --tmpfs /run --tmpfs /var/run "${airgap[@]}" \
  -e K3S_KUBECONFIG_MODE=644 "$k3s_image" server --disable=traefik,metrics-server --node-label=role=worker "${extra[@]}" >/dev/null
if [[ "${SANDBOX_RUNC_WRAP:-0}" == 1 ]]; then
  docker cp "$here/test-runc-wrap.sh" "$name:/tmp/runc-wrap"
  docker exec "$name" sh -c 'mv /bin/runc /bin/runc.real && cp /tmp/runc-wrap /bin/runc && chmod +x /bin/runc'
fi
for _ in $(seq 90); do docker exec "$name" test -f /etc/rancher/k3s/k3s.yaml 2>/dev/null && break; sleep 2; done
ip="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name")"
# kubectl inside the K3s container: no kubeconfig on this machine, so the real cluster is unreachable.
k() { docker exec -i "$name" kubectl "$@"; }
for _ in $(seq 90); do k get nodes 2>/dev/null | grep -q ' Ready' && break; sleep 2; done
for _ in $(seq 90); do k -n kube-system get deploy/coredns >/dev/null 2>&1 && break; sleep 2; done
k wait -n kube-system --for=condition=Available deploy/coredns --timeout=240s >/dev/null
# The single test node is the control plane; let lab pods schedule on it for this test only.
k label node --all node-role.kubernetes.io/control-plane- >/dev/null
docker cp "$tar" "$name:/tmp/image.tar"
docker exec "$name" ctr -n k8s.io images import /tmp/image.tar >/dev/null
pass "local K3s up and image imported"

k apply --server-side -f - < "$here/cluster-setup.yaml" >/dev/null
pass "cluster-setup.yaml applied"

can() { k auth can-i "$1" "$2" --as=system:serviceaccount:academy-labs:academy-lab-controller -n "$3" "${@:4}"; }
[[ "$(can create pods academy-labs)" == yes ]] || fail "controller cannot create lab pods"
[[ "$(can create pods academy-labs --subresource=exec 2>/dev/null || true)" == no ]] || fail "controller can exec into labs"
[[ "$(can create pods academy-labs --subresource=attach 2>/dev/null || true)" == no ]] || fail "controller can attach to labs"
for check in "create pods default" "create services academy-labs" \
             "get secrets academy-labs" "delete namespaces academy-labs" "create networkpolicies academy-labs"; do
  set -- $check; [[ "$(can "$1" "$2" "$3" 2>/dev/null || true)" == no ]] || fail "controller can $check"
done
pass "controller limited to lab pods in academy-labs"

lab() { sed -e "s|\${LAB_ID}|$1|g" -e "s|\${IMAGE}|$image|g" -e "s|\${INTERNET}|$2|g" "$here/lab-pod.template.yaml"; }
lab t1 false | k apply -f - >/dev/null
ready lab-t1
pass "lab pod starts under Pod Security 'restricted'"

[[ "$(k -n academy-labs exec lab-t1 -- id -u)" == 1000 ]] || fail "lab not running as UID 1000"
k -n academy-labs exec lab-t1 -- test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token || fail "API token mounted"
k -n academy-labs exec lab-t1 -- pwsh -NoProfile -Command '$PSVersionTable.PSVersion.Major' | grep -q 7 || fail "pwsh"
pass "non-root, no API token, PowerShell 7 runs"

probe() { # probe <pod> <host> <port>: prints open/closed
  k -n academy-labs exec "$1" -- python3 -c "import socket,sys
s=socket.socket(); s.settimeout(4)
try: s.connect(('$2',$3)); print('open')
except Exception: print('closed')"; }
k -n academy-labs exec lab-t1 -- python3 -c "import socket; socket.getaddrinfo('kubernetes.default.svc.cluster.local', 443)" \
  || fail "cluster DNS lookup failed"
pass "DNS works"
for target in "10.43.0.1 443" "$ip 6443" "169.254.169.254 80" "192.168.8.115 22" "100.100.100.100 53" "1.1.1.1 443"; do
  set -- $target; [[ "$(probe lab-t1 "$1" "$2")" == closed ]] || fail "lab-t1 reached $1:$2"
done
pass "default lab: API server, node, metadata, LAN, Tailscale and internet all blocked"
# Control: the same probe from a namespace without these rules must succeed, so the blocks above
# come from the NetworkPolicies and not from the test environment.
k create namespace control >/dev/null
k -n control run ctl --image="$image" --restart=Never --command -- sleep 300 >/dev/null
k -n control wait --for=condition=Ready pod/ctl --timeout=180s >/dev/null
[[ "$(k -n control exec ctl -- python3 -c "import socket
s=socket.socket(); s.settimeout(4)
try: s.connect(('10.43.0.1',443)); print('open')
except Exception: print('closed')")" == open ]] || fail "control pod could not reach the API server either; network test is inconclusive"
pass "control pod outside academy-labs reaches the API server, so the blocks are the policies'"

lab t2 true | k apply -f - >/dev/null
ready lab-t2
for target in "10.43.0.1 443" "$ip 6443" "169.254.169.254 80" "192.168.8.115 22"; do
  set -- $target; [[ "$(probe lab-t2 "$1" "$2")" == closed ]] || fail "internet lab reached $1:$2"
done
pass "internet-enabled lab still blocked from API server, node, metadata and LAN"

if lab t3 false | k apply -f - >/dev/null 2>&1; then fail "a third lab was allowed"; fi
pass "quota allows at most two labs"
if k -n academy-labs create service clusterip x --tcp=80 >/dev/null 2>&1; then fail "service allowed"; fi
pass "no Services can be created"
cat <<YAML | k apply -f - >/dev/null 2>&1 && fail "privileged pod accepted" || pass "privileged pod rejected"
apiVersion: v1
kind: Pod
metadata: { name: bad, namespace: academy-labs }
spec:
  containers: [{ name: c, image: $image, securityContext: { privileged: true } }]
YAML

k -n academy-labs delete pod lab-t2 --wait >/dev/null
lab t4 false | sed 's/activeDeadlineSeconds: 5400/activeDeadlineSeconds: 15/' | k apply -f - >/dev/null
for _ in $(seq 40); do
  phase="$(k -n academy-labs get pod lab-t4 -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [[ "$phase" == Failed ]] && break; sleep 2
done
[[ "$(k -n academy-labs get pod lab-t4 -o jsonpath='{.status.reason}')" == DeadlineExceeded ]] || fail "deadline not enforced"
pass "hard deadline stops a lab on its own"
echo "ALL CHECKS PASSED"
