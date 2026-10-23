# External URLs — web proxy allow rules

Every outbound destination MirrorRepos needs, grouped by purpose.
All traffic is HTTPS (443) unless noted. Configure on the corporate web
proxy; if it does TLS inspection, install the proxy CA into the host trust
store (see [terraform-mirror/standalone.md](terraform-mirror/standalone.md)).

## A. The solution itself — build, update, operate

Needed on the mirror host to build/rebuild the container images and keep the
tooling current. Only these rules are needed if the mirrored content is
imported from elsewhere instead of downloaded directly.

| Domain | Used for | Needed by |
|---|---|---|
| `quay.io` | `fedora-minimal` base image | podman build (all mirror images) |
| `docker.io`, `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com` | `httpd:alpine`, `python:3.12-alpine`, `clamav/clamav` images | webserver run, scanfiles build/run |
| `mirrors.fedoraproject.org` | dnf metalink resolution | image builds / rebuilds (`dnf update` layer) |
| `dl.fedoraproject.org` (+ the Fedora mirror it redirects to) | RPM package updates inside image builds | repo-mirror-base build |
| `releases.hashicorp.com` | Terraform CLI (`terraform.zip`) | terraform-mirror image build |
| `pypi.org`, `files.pythonhosted.org` | `pip install cvdupdate` | scanfiles image build |
| `database.clamav.net` | ClamAV signature database (`cvd update`) | scanfiles/cv-update.sh (run daily) |

## B. Mirrored content — what is downloaded and served to clients

The actual content being mirrored. Adjust the RPM rows to match
`repo-mirror/config/repos/*.repo` if you change mirrors.

| Domain | Content | Mirrored by |
|---|---|---|
| `dl.rockylinux.org` | Rocky Linux 8/9/10 repos (BaseOS, AppStream, CRB, HighAvailability, ...) | repo-mirror |
| `mirrors.fedoraproject.org` | EPEL metalinks (mirror resolution) | repo-mirror |
| `fedora.mirror.serversaustralia.com.au` | EPEL 9 Everything (primary EPEL baseurl) | repo-mirror |
| `mirror.aarnet.edu.au` | EPEL 9 Everything (alternate mirror) | repo-mirror |
| `download1.rpmfusion.org` | RPM Fusion free for Fedora | repo-mirror |
| `packages.microsoft.com` | VS Code RPMs (`vscode`, `vscode-el10`) | repo-mirror |
| `registry.terraform.io` | Terraform registry API — provider/module version resolution and download pointers | terraform-mirror |
| `releases.hashicorp.com` | Terraform provider `.zip` binaries + checksums/signatures | terraform-mirror (providers) |
| `github.com` | Module source resolution + archive redirect | terraform-mirror (modules) |
| `codeload.github.com` | Module `.tar.gz` archives (GitHub's redirect target) | terraform-mirror (modules) |
| `api.github.com` | Some modules' `X-Terraform-Get` points at the GitHub API | terraform-mirror (occasional) |
| `objects.githubusercontent.com` | Release assets for third-party (non-HashiCorp) providers hosted on GitHub | terraform-mirror (occasional) |

## Explicitly NOT required

| Domain | Why |
|---|---|
| `checkpoint.hashicorp.com` | HashiCorp telemetry — disabled by the scripts (`CHECKPOINT_DISABLE=1`) |

## Quick test from the mirror host

```bash
# solution
curl -sI https://quay.io/ | head -1
curl -sI https://database.clamav.net/ | head -1
# mirrored content
curl -sI http://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/repodata/repomd.xml | head -1
curl -s  https://registry.terraform.io/v1/providers/hashicorp/aws/versions | head -c 80
```
