# damstack-hashi

A [damstack](https://github.com/eugene-panin/damstack) platform: Consul, Vault
and Nomad on one server, over WireGuard, with Traefik in front and nightly
backups, ready for apps such as [mail](https://github.com/eugene-panin/damstack-mail).

```bash
damstack deploy hashi
```

damstack asks the questions in [`damstack.yaml`](damstack.yaml), writes the
project, then runs the steps: `bootstrap` creates the ops user and locks the
server down to your key, once; `provision` sets up WireGuard, Consul, Vault,
Nomad and the backups; `apply` plans the resources on the platform, checks the
plan against the policies, and applies it when you say yes; after the apps,
`dns` publishes the DNS records of the platform and of every app.

`damstack app add mail` adds an app. The platform `provides` nomad, vault-kv,
consul and ingress-traefik, and gives every app `NOMAD_*`, `CONSUL_*` and
`VAULT_*` to reach them; an app opens its ports on the server with
`public_ports` in its block of `stack.yaml`.

In a project, `damstack plan` shows what `apply` would change,
`damstack output` prints the OpenTofu outputs, `damstack dns-records` the
records to create by hand, and
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
- `infra/`: the OpenTofu root module of the platform, with a lock file for Linux amd64 and arm64;
- `dns/`: the OpenTofu root module that publishes the records in `dns/` of the project;
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
