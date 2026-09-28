# damstack-hashistack

A [damstack](https://github.com/eugene-panin/damstack) stack: Consul, Vault
and Nomad on one server, over WireGuard, with Traefik in front, nightly
backups, and apps such as mail.

```bash
damstack deploy hashistack
```

damstack asks the questions in [`damstack.yaml`](damstack.yaml), writes the
project, then runs the steps: `bootstrap` creates the ops user and locks the
server down to your key, once; `provision` sets up WireGuard, Consul, Vault,
Nomad and the backups; `apply` plans the resources on the platform, checks the
plan against the policies, and applies it when you say yes.

In a project, `damstack plan` shows what `apply` would change,
`damstack output` prints the OpenTofu outputs, and
`damstack provision --check --diff` shows what `provision` would change.

The project is data only: `stack.yaml`, the one file you edit, the encrypted
`vault.yml`, `ca.pem`, the encrypted OpenTofu state in `state/`, and the
WireGuard files of your devices in `clients/`. The code is this stack, at the
version the project was deployed with, mounted read-only.

## Layout

- `damstack.yaml`: the questions, the secrets, and the steps;
- `template/stack.yaml.tmpl`: the `stack.yaml` a new project starts from;
- `ansible/`: the playbooks and the inventory, whose variables come from
  `stack.yaml` and `vault.yml` of the project;
- `infra/`: the OpenTofu root module, with a lock file for Linux amd64 and arm64;
- `policy/`: the Conftest policies every plan passes before it is applied.

## Tested

`damstack stack check` sets up a project from [`test/answers.yaml`](test/answers.yaml)
and checks that the playbooks parse, OpenTofu validates against the project,
the policies pass their tests, and that `stack.yaml` says what the answers
said and every variable the roles read resolves from the project
([`test/resolve.yml`](test/resolve.yml)).

[`test/bootstrap.sh`](test/bootstrap.sh) runs the bootstrap playbook against
fresh Ubuntu 24.04 servers in containers: a new ops user, a second run that
changes nothing, a rename refused, an existing user left alone or taken over
with `adopt_user`, a system user refused, and the user the server came with
kept as the ops user.

## License

MIT, see [LICENSE](LICENSE).
