# Terraform Mirror

Mirrors Terraform **providers** and **modules** from the public registry
(`registry.terraform.io`):

- **Providers** are mirrored with
  [`terraform providers mirror`](https://developer.hashicorp.com/terraform/cli/commands/providers/mirror).
- **Modules** are downloaded via the
  [module registry download API](https://developer.hashicorp.com/terraform/internals/module-registry-protocol)
  (Terraform has no CLI command for mirroring modules) and stored as
  `.tar.gz` archives.

This is the Terraform equivalent of the `repo-mirror` project:

| | repo-mirror | terraform-mirror |
|---|---|---|
| Config | `config/all.repos` (`repoId,releasever,basearch`) | `config/all.providers` (`provider,version,platforms`), `config/all.modules` (`module,version`) |
| Script | `scripts/mirror-repo.sh` (`dnf reposync`) | `scripts/mirror-terraform.sh` (`terraform providers mirror`), `scripts/mirror-terraform-modules.sh` (registry API + curl) |
| Output | `/data/packages/<repoid>` | `/data/packages/terraform/...` |

## Prerequisites

The base image must exist first (same as repo-mirror):

```bash
podman build -t rpm-repo-mirror-base ./repo-mirror-base
```

## Configuration files

| File | Mirrors | Format | Artifact |
|---|---|---|---|
| `config/all.providers` | Terraform **providers** — binary plugins Terraform uses to talk to cloud APIs, e.g. `hashicorp/aws` | `provider,version,platforms` | signed provider binaries + registry index, consumed via `provider_installation` |
| `config/all.modules` | Terraform **modules** — reusable bundles of `.tf` code, e.g. `terraform-aws-modules/vpc/aws` | `module,version` | source `.tar.gz` archives, consumed via the module `source` URL |

Version semantics are the same in both files:

- `version` may be an exact version (pinned), `latest`, or empty (newest
  release, resolved at sync time).
- Repeat a row with different versions to mirror multiple versions side by
  side — useful when different projects pin different versions of the same
  provider or module.
- Lines starting with `#` are ignored.

## Providers

Edit `config/all.providers`. One provider per line:

```
provider,version,platforms
hashicorp/aws, 5.70.0, linux_amd64
hashicorp/aws, 5.49.0, linux_amd64
hashicorp/azurerm, latest, linux_amd64
# hashicorp/kubernetes, 2.33.0, linux_amd64 linux_arm64
```

- `provider` — `namespace/name` as used in `required_providers`.
- `version` — exact version, or `latest`/empty for the newest release.
  Multiple rows for the same provider mirror several versions side by side.
- `platforms` — space separated list, e.g. `linux_amd64 linux_arm64 windows_amd64`.
  Defaults to `linux_amd64` when empty.
- Lines starting with `#` are ignored.

## Modules

Edit `config/all.modules`. One module per line, using the address shown on
https://registry.terraform.io/browse/modules:

```
module,version
terraform-aws-modules/vpc/aws, 5.13.0
terraform-aws-modules/vpc/aws, 5.8.1
terraform-aws-modules/security-group/aws, latest
```

- `module` — `namespace/name/system`, e.g. `terraform-aws-modules/vpc/aws`.
- `version` — exact version, or `latest`/empty to resolve the newest release
  from the registry at sync time. Multiple rows for the same module mirror
  several versions side by side.
- Lines starting with `#` are ignored.

How it works: the registry download endpoint
(`/v1/modules/<namespace>/<name>/<system>/<version>/download`) replies with an
`X-Terraform-Get` header pointing at the module source, typically
`git::https://github.com/<org>/<repo>?ref=<commit-sha>`. The script downloads
the matching source archive and repacks it so the module `.tf` files sit at
the archive root.

Limitation: GitHub-hosted modules (the vast majority of the public registry)
and direct `.tar.gz`/`.zip` archive URLs are handled; other source hosts are
logged as errors.

## Build & Run

```bash
podman build -t terraform-mirror .
podman run -v /data/repo:/data:z -v /data/config-terraform:/config:z -v /data/log:/var/log/:z -it --name terraform-mirror terraform-mirror
```

Or use `run-me.sh` / `docker-compose.yml` / the quadlet `terraform-mirror.container`,
following the same pattern as `repo-mirror`.

The container runs the mirror via cron and appends to `/var/log/mirror-terraform.log`.

## Running on the host (no container)

> **Tip:** to run straight from the repo with **no installation at all**
> (and for the corporate proxy allow-list), see [standalone.md](standalone.md).

The same mirror scripts run directly on a VM — they only need `curl`,
`unzip`, `tar` and the Terraform CLI. All paths are environment-overridable,
so the container behaviour is unchanged:

| Variable | Default (container) | Purpose |
|---|---|---|
| `ALL_PROVIDERS` | `/config/all.providers` | provider list |
| `ALL_MODULES` | `/config/all.modules` | module list |
| `MIRROR_DIR` | `/data/packages/terraform` (`.../modules` for modules) | output directory |
| `REGISTRY_URL` | `https://registry.terraform.io` | registry API (modules only) |

### Automated setup

```bash
sudo dnf install -y curl unzip tar cronie
sudo systemctl enable --now crond
cd terraform-mirror
sudo ./scripts/setup-host.sh
```

`setup-host.sh`:

- installs the Terraform CLI into `/usr/local/bin` (skip with
  `INSTALL_TERRAFORM=0`; pick a version with `TF_VERSION=1.13.3`)
- installs both mirror scripts into `/usr/local/bin/`
- copies `all.providers` / `all.modules` into `/data/config-terraform/`
  (existing files are not overwritten)
- writes the cron file `/etc/cron.d/terraform-mirror` and logs to
  `/var/log/terraform-mirror.log`

All settings are environment-overridable, e.g.:

```bash
sudo CRON_SCHEDULE="0 * * * *" DATA_DIR=/srv/mirror/terraform ./scripts/setup-host.sh
```

### Manual cron setup

System-wide — `/etc/cron.d/terraform-mirror` (note the **user column**, here
`root`):

```
ALL_PROVIDERS=/data/config-terraform/all.providers
ALL_MODULES=/data/config-terraform/all.modules
MIRROR_DIR=/data/packages/terraform
*/5 * * * * root /usr/local/bin/mirror-terraform.sh >> /var/log/terraform-mirror.log 2>&1
*/5 * * * * root /usr/local/bin/mirror-terraform-modules.sh >> /var/log/terraform-mirror.log 2>&1
```

Or per-user via `crontab -e` (no user column, paths to your home directory):

```
*/5 * * * * ALL_PROVIDERS=$HOME/tf-config/all.providers MIRROR_DIR=$HOME/mirror/terraform /usr/local/bin/mirror-terraform.sh >> $HOME/terraform-mirror.log 2>&1
*/5 * * * * ALL_MODULES=$HOME/tf-config/all.modules MIRROR_DIR=$HOME/mirror/terraform/modules /usr/local/bin/mirror-terraform-modules.sh >> $HOME/terraform-mirror.log 2>&1
```

### One-off run (testing)

```bash
sudo ALL_PROVIDERS=/data/config-terraform/all.providers \
     MIRROR_DIR=/data/packages/terraform \
     /usr/local/bin/mirror-terraform.sh

sudo ALL_MODULES=/data/config-terraform/all.modules \
     MIRROR_DIR=/data/packages/terraform/modules \
     /usr/local/bin/mirror-terraform-modules.sh

tail -f /var/log/terraform-mirror.log
```

## Output layout

`terraform providers mirror` writes the standard provider mirror layout:

```
/data/packages/terraform/
└── registry.terraform.io/
    └── hashicorp/
        └── aws/
            ├── 5.70.0.json
            ├── index.json
            └── 5.70.0/
                └── linux_amd64/
                    └── terraform-provider-aws_5.70.0_linux_amd64.zip
```

Modules are stored as plain archives:

```
/data/packages/terraform/modules/
└── terraform-aws-modules/
    └── vpc/
        └── aws/
            └── 5.13.0/
                └── vpc-5.13.0.tar.gz
```

Because everything lands under `/data/packages/`, the existing `webserver`
container exposes it over HTTP automatically.

## Client configuration

Consumers point their Terraform CLI at the mirror with a
[CLI configuration file](https://developer.hashicorp.com/terraform/cli/config/config-file#provider-installation)
(`terraform.rc` / `~/.terraformrc`):

Network mirror (via the webserver container):

```hcl
provider_installation {
  network_mirror {
    url = "http://<mirror-host>:8080/terraform/"
  }
}
```

Filesystem mirror (direct access to the data volume):

```hcl
provider_installation {
  filesystem_mirror {
    path = "/data/packages/terraform"
  }
}
```

### Modules

Modules have no `provider_installation` equivalent; reference the mirrored
archive directly as the module source:

```hcl
module "vpc" {
  source = "https://<mirror-host>:8080/terraform/modules/terraform-aws-modules/vpc/aws/5.13.0/vpc-5.13.0.tar.gz"
}
```

Terraform downloads and extracts the archive. The mirrored archives are
packed with the module `.tf` files at the root, so no `//subdir` suffix is
needed.
