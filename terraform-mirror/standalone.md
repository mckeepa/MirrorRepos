# Standalone (no container) — Terraform Mirror

Run the mirror scripts straight from the repo. Nothing is installed system-wide;
everything is controlled by environment variables.

## What each script needs

| Script | Mirrors | Host requirements |
|---|---|---|
| `scripts/mirror-terraform-modules.sh` | Modules | `bash`, `curl`, `tar` — that's all |
| `scripts/mirror-terraform.sh` | Providers | the above **plus the Terraform CLI** |

The Terraform CLI is a single static binary — no package manager needed:

```bash
curl -fsSL -o /tmp/terraform.zip \
  "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip"
unzip /tmp/terraform.zip -d ~/.local/bin    # or: sudo unzip ... -d /usr/local/bin
rm /tmp/terraform.zip
terraform version
```

## Quick start

```bash
cd ~/MirrorRepos/terraform-mirror

# Modules (works immediately)
ALL_MODULES=./config/all.modules \
MIRROR_DIR=./data/packages/terraform/modules \
    bash scripts/mirror-terraform-modules.sh

# Providers (needs the terraform binary in PATH)
ALL_PROVIDERS=./config/all.providers \
MIRROR_DIR=./data/packages/terraform \
    bash scripts/mirror-terraform.sh
```

Output lands in `./data/packages/terraform/`:

```
data/packages/terraform/
├── registry.terraform.io/...      # providers (registry mirror layout)
└── modules/...                    # modules (*.tar.gz source archives)
```

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
curl -sI https://registry.terraform.io/v1/modules/terraform-aws-modules/vpc/aws/5.13.0/download | head -5
# expect: HTTP/2 204 and an x-terraform-get header
```

## Troubleshooting

- **Verbose run:** `bash -x scripts/mirror-terraform-modules.sh`
- **Provider fails to resolve:** check `curl -s https://registry.terraform.io/v1/providers/hashicorp/aws/versions | head -c 200`
- **Behind proxy:** confirm `env | grep -i proxy` and the CA cert is trusted
- **Module skipped with "unsupported module source":** the module's repo is not
  on GitHub and not a direct archive URL — check the log line for its
  `X-Terraform-Get` value
