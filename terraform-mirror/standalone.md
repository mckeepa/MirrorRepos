# Standalone (no container) — Terraform Mirror

Run the mirror scripts straight from this repo — no container build, nothing
installed system-wide. Everything is controlled by environment variables.

The **module mirror runs without the Terraform binary** (just `bash`, `curl`,
`tar`). Only the provider mirror needs the binary — see
[Two ways to download](#two-ways-to-download).

## In this file

1. [Quick start](#quick-start) — run the module mirror right now
2. [Two ways to download](#two-ways-to-download) — with and without `terraform`
3. [What each script needs](#what-each-script-needs)
4. [Output layout](#output-layout)
5. [Environment variables](#environment-variables)
6. [Scheduled runs (cron)](#scheduled-runs-cron)
7. [Corporate web proxy — domains to allow](#corporate-web-proxy--domains-to-allow)
8. [Troubleshooting](#troubleshooting)

## Quick start

Mirror every module listed in `config/all.modules` into `./data/` — no
Terraform installation needed:

```bash
cd ~/MirrorRepos/terraform-mirror && \
  ALL_MODULES=$PWD/config/all.modules \
  MIRROR_DIR=$PWD/data/packages/terraform/modules \
  bash scripts/mirror-terraform-modules.sh
```

Providers (needs the Terraform binary, see below):

```bash
cd ~/MirrorRepos/terraform-mirror && \
  ALL_PROVIDERS=$PWD/config/all.providers \
  MIRROR_DIR=$PWD/data/packages/terraform \
  bash scripts/mirror-terraform.sh
```

## Two ways to download

The two scripts take deliberately different approaches.

### 1. Without the Terraform binary — `scripts/mirror-terraform-modules.sh`

Modules are just source code, so plain HTTPS downloads are enough. The script
asks the registry API where each module's source lives (a GitHub repo +
commit), downloads the archive with `curl`, and repacks it with `tar`.
No Terraform installation required — verified against both
`terraform-aws-modules/*` and `Azure/*` (AVM) modules.

### 2. With the Terraform binary — `scripts/mirror-terraform.sh`

Provider mirroring **does** use the Terraform binary. The script generates a
throwaway `required_providers` block per provider and runs
`terraform providers mirror`. Benefits of letting Terraform do the work:

- **Integrity checks** — Terraform verifies the checksums and signatures of
  the provider packages it downloads.
- **Correct layout** — packages land in the exact filesystem-mirror directory
  structure (`registry.terraform.io/<ns>/<name>/<version>/<os_arch>/`) that
  `terraform init` expects, so the mirror works with no post-processing.
- **Multi-platform** — one run fetches every OS/arch listed in the CSV.

The Terraform CLI is a single static binary (`terraform.zip`) — no package
manager needed:

```bash
curl -fsSL -o /tmp/terraform.zip \
  "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip"
unzip /tmp/terraform.zip -d ~/.local/bin    # or: sudo unzip ... -d /usr/local/bin
rm /tmp/terraform.zip
terraform version
```

## What each script needs

| Script | Mirrors | Terraform binary? | Host requirements |
|---|---|---|---|
| `scripts/mirror-terraform-modules.sh` | Modules | **No** | `bash`, `curl`, `tar` |
| `scripts/mirror-terraform.sh` | Providers | **Yes** | the above + `terraform` and `openssl` in `PATH` |

## Output layout

Output lands in `./data/packages/terraform/`:

```
data/packages/terraform/
├── registry.terraform.io/...      # providers (registry mirror layout + network-mirror JSON)
└── modules/...                    # modules (*.tar.gz source archives)
```

## Client access (via the webserver)

The mirrored files under `data/packages/terraform/` are served by the
webserver at `http(s)://<mirror-host>/terraform/`, alongside the RPM repos.
Clients consume providers via `provider_installation` (network mirror) and
modules via archive URLs — see [readme.md](readme.md#client-configuration).

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `ALL_PROVIDERS` | `/config/all.providers` | path to the provider CSV |
| `ALL_MODULES` | `/config/all.modules` | path to the module CSV |
| `MIRROR_DIR` | `/data/packages/terraform` (`.../modules` for the modules script) | output directory |
| `REGISTRY_URL` | `https://registry.terraform.io` | registry API (modules only) |
| `HTTPS_PROXY` / `https_proxy` | — | corporate web proxy, if required |
| `NO_PROXY` / `no_proxy` | — | hosts to bypass the proxy |

## Scheduled runs (cron)

Per-user crontab — no root needed (`crontab -e`):

```
*/5 * * * * cd ~/MirrorRepos/terraform-mirror && ALL_PROVIDERS=./config/all.providers MIRROR_DIR=./data/packages/terraform bash scripts/mirror-terraform.sh >> ./data/terraform-mirror.log 2>&1
*/5 * * * * cd ~/MirrorRepos/terraform-mirror && ALL_MODULES=./config/all.modules MIRROR_DIR=./data/packages/terraform/modules bash scripts/mirror-terraform-modules.sh >> ./data/terraform-mirror.log 2>&1
```

For a system-wide install (`/usr/local/bin`, `/etc/cron.d`, service account),
use `scripts/setup-host.sh` instead — see [readme.md](readme.md#running-on-the-host-no-container).

## Corporate web proxy — domains to allow

Both scripts only speak HTTPS (443). Allow these outbound domains:

| Domain | Needed for | Used by |
|---|---|---|
| `registry.terraform.io` | Registry API: resolving provider/module versions and download locations | both scripts |
| `releases.hashicorp.com` | Provider binaries (`.zip` + checksums/signature) and the Terraform CLI itself | providers |
| `github.com` | Module source resolution and archive download redirect | modules |
| `codeload.github.com` | The actual module `.tar.gz` archives (GitHub redirects here) | modules |
| `api.github.com` | Some modules whose `X-Terraform-Get` points at the GitHub API | modules (occasional) |
| `objects.githubusercontent.com` | Release assets for third-party (non-HashiCorp) providers hosted on GitHub | providers (occasional) |
| `checkpoint.hashicorp.com` | Telemetry — **not required**; disabled by the scripts (`CHECKPOINT_DISABLE=1`) | — |

If your proxy requires authentication or TLS inspection, also install the
proxy's CA certificate into the system trust store, otherwise `curl` and
`terraform` will fail with certificate errors.

Set the proxy before running:

```bash
export HTTPS_PROXY="http://proxy.company.com:3128"
export HTTP_PROXY="http://proxy.company.com:3128"
export NO_PROXY="localhost,127.0.0.1"
```

Quick proxy connectivity test:

```bash
curl -sD - -o /dev/null https://registry.terraform.io/v1/modules/terraform-aws-modules/vpc/aws/5.13.0/download | head -5
# expect: HTTP/2 204 and an x-terraform-get header
# (use "-D -", not "-I": the CDN answers HEAD with 405 for some modules)
```

## Troubleshooting

- **Verbose run:** `bash -x scripts/mirror-terraform-modules.sh`
- **Provider fails to resolve:** check `curl -s https://registry.terraform.io/v1/providers/hashicorp/aws/versions | head -c 200`
- **Behind proxy:** confirm `env | grep -i proxy` and the CA cert is trusted
- **Module skipped with "unsupported module source":** the module's repo is not
  on GitHub and not a direct archive URL — check the log line for its
  `X-Terraform-Get` value
- **Module fails with "no X-Terraform-Get header returned":** the registry's
  CDN answers **HEAD** requests with `405` for some modules (e.g.
  `Azure/regions`). The module script therefore issues a **GET** and discards
  the body when reading the `X-Terraform-Get` header — if you probe endpoints
  by hand, use `curl -sD - -o /dev/null`, not `curl -sI`
