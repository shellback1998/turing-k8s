# Scott Academy Linux labs on K3s

Cluster side of the on-demand Linux labs for academy.scottgaudet.com
(design: `docs/labs-design.md` in shellback1998/scottacademy; image: `infra/labs/linux-image`).

| File | What it is |
|---|---|
| `cluster-setup.yaml` | One-time setup: `academy-labs` namespace (Pod Security *restricted*), quota (2 labs, 1 CPU, 1 GiB, no Services), per-container limits, default-deny network with DNS and opt-in internet HTTPS (private, Tailscale and metadata ranges blocked), and two service accounts: the lab controller (pods in this namespace only) and the browser viewer (attach only). |
| `lab-pod.template.yaml` | One lab as the controller creates it: non-root, no capabilities, no API token, 90-minute hard deadline, never on the control plane. |
| `build-image.sh` | Builds the lab image natively on turing-node01 (arm64), smoke-tests it and pushes it to `192.168.8.191:5000`. Refuses to overwrite an existing tag. |
| `test-local.sh` | Throwaway end-to-end test on a local K3s-in-Docker cluster (never touches the real one). |
| `../playbooks/academy-labs.yml` | Applies the setup with a preview first and checks the controller's permissions afterwards; `--tags prepull` pulls a new image onto the workers. |

```bash
academy-labs/build-image.sh ~/scottacademy/infra/labs/linux-image 2026.10.18-1
ansible-playbook playbooks/academy-labs.yml --check --diff   # preview
ansible-playbook playbooks/academy-labs.yml                  # apply
ansible-playbook playbooks/academy-labs.yml --tags prepull -e academy_lab_image_tag=<tag>
```

Remove everything: `kubectl delete namespace academy-labs`.
