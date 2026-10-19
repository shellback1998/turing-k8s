# Scott Academy Linux labs on K3s

Cluster side of the on-demand Linux labs for academy.scottgaudet.com
(design: `docs/labs-design.md` in shellback1998/scottacademy; image: `infra/labs/linux-image`).

| File | What it is |
|---|---|
| `cluster-setup.yaml` | One-time setup: `academy-labs` namespace (Pod Security *restricted*), quota (2 labs, 1 CPU, 1 GiB, no Services), per-container limits, default-deny network with DNS and opt-in internet HTTPS (private, Tailscale and metadata ranges blocked), the lab controller (service account and token; pods in this namespace only) and the viewer's role (`pods/exec` here only, bound to the certificate user `academy-lab-viewer`). |
| `lab-pod.template.yaml` | One lab as the Academy creates it: non-root, no capabilities, no API token, 95-minute hard deadline, never on the control plane. |
| `viewer.yaml` | The browser viewer: Apache Guacamole 1.6.0 (guacd + web app) in `academy-viewer`, NodePort 30880, served at `/viewer`. No accounts; sign-in only by sealed one-minute JSON from the Academy. |
| `install-on-academy-host.sh` | Run on turing-manager: installs the exported credentials and settings, checks the API and viewer are reachable, restarts both sites, deletes the bundle. |
| `build-image.sh` | Builds the lab image natively on turing-node01 (arm64), smoke-tests it and pushes it to `192.168.8.191:5000`. Refuses to overwrite an existing tag. |
| `test-local.sh` | Throwaway end-to-end test on a local K3s-in-Docker cluster (never touches the real one). |
| `../playbooks/academy-labs.yml` | Applies the setup with a preview first and checks the controller's permissions afterwards; `--tags prepull` pulls a new image onto the workers. |
| `../playbooks/academy-viewer.yml` | `--tags viewer`: sign-in key, viewer client certificate (CSR API, renewed under 30 days), Guacamole, permission checks. `--tags export`: the bundle for turing-manager. |

Setting up labs, start to finish (on k8s-manager, in this repo):

```bash
# 1. Build and push the lab image (on turing-node01, arm64)
academy-labs/build-image.sh ~/scottacademy/infra/labs/linux-image 2026.10.19-1

# 2. Namespace, limits, network rules, RBAC; then pre-pull the image on the workers
ansible-playbook playbooks/academy-labs.yml --ask-vault-pass --check --diff   # preview
ansible-playbook playbooks/academy-labs.yml --ask-vault-pass
ansible-playbook playbooks/academy-labs.yml --ask-vault-pass --tags prepull -e academy_lab_image_tag=2026.10.19-1

# 3. The viewer, then the settings bundle for the Academy host
ansible-playbook playbooks/academy-viewer.yml --ask-vault-pass --tags viewer
ansible-playbook playbooks/academy-viewer.yml --ask-vault-pass --tags export -e academy_lab_image_tag=2026.10.19-1

# 4. Install on turing-manager (checks connectivity first, restarts both sites, deletes the bundle)
scp -r ~/academy-labs-bundle piadmin@turing-manager:
ssh -t piadmin@turing-manager sudo ./academy-labs-bundle/install.sh
rm -rf ~/academy-labs-bundle
```

A new lab image later: steps 1, the `prepull` line, the `export` line and step 4.

Remove everything: `kubectl delete namespace academy-labs academy-viewer`.
