# damstack-hashistack

A [damstack](https://github.com/eugene-panin/damstack) stack: Consul, Vault
and Nomad on one server, over WireGuard, with Traefik in front, nightly
backups, and apps such as mail.

```bash
damstack deploy hashistack
```

damstack asks the questions in [`damstack.yaml`](damstack.yaml), then runs
the steps: `init` writes the project, `bootstrap` locks the server down to
your key, `provision` sets up the server, `plan` and `apply` the resources on
it.

The project is data only: `stack.yaml`, the one file you edit, the encrypted
`vault.yml`, `ca.pem`, the encrypted OpenTofu state in `state/`, and the
WireGuard files of your devices in `clients/`. The code is this stack, at the
version the project was deployed with, mounted read-only.

## Layout

- `bin/stack`: what damstack runs inside damstack-toolbox, one command per step;
- `ansible/`: the playbooks and the inventory, whose variables come from
  `stack.yaml` and `vault.yml` of the project;
- `infra/`: the OpenTofu root module, with a lock file for Linux amd64 and arm64;
- `policy/`: the Conftest policies every plan passes before it is applied;
- `template/stack.yaml.j2`: the `stack.yaml` a new project starts from.

## Tested

`bin/stack check` sets up a project from [`test/answers.json`](test/answers.json)
and checks that:

- the vault is encrypted and holds every secret;
- a second init refuses;
- the policies pass their tests;
- OpenTofu validates against the project;
- the playbooks parse, and every variable the roles read resolves.

## License

MIT, see [LICENSE](LICENSE).
