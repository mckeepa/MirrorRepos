#!/bin/bash

# Terraform Mirror - host (VM) setup
# Installs the Terraform CLI, the mirror scripts, the config files and a
# cron job so the mirror runs directly on the host (no container).
#
# Usage:
#   sudo ./scripts/setup-host.sh
#   sudo TF_VERSION=1.13.3 CRON_SCHEDULE="0 * * * *" ./scripts/setup-host.sh

set -euo pipefail

# ---- settings (override via environment) -------------------------------------
TF_VERSION="${TF_VERSION:-1.9.8}"            # Terraform CLI version to install
CONFIG_DIR="${CONFIG_DIR:-/data/config-terraform}"
DATA_DIR="${DATA_DIR:-/data/packages/terraform}"
LOG_FILE="${LOG_FILE:-/var/log/terraform-mirror.log}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
CRON_SCHEDULE="${CRON_SCHEDULE:-*/5 * * * *}"
CRON_USER="${CRON_USER:-root}"
CRON_FILE="${CRON_FILE:-/etc/cron.d/terraform-mirror}"
INSTALL_TERRAFORM="${INSTALL_TERRAFORM:-1}"  # 0 = require existing terraform

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root, e.g.: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ---- prerequisites -----------------------------------------------------------
for cmd in curl unzip tar openssl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: '$cmd' is required. Install it first, e.g.:"
        echo "  sudo dnf install -y curl unzip tar openssl"
        exit 1
    fi
done

# ---- Terraform CLI -------------------------------------------------------------
if ! command -v terraform >/dev/null 2>&1; then
    if [[ "$INSTALL_TERRAFORM" == "1" ]]; then
        echo "Installing Terraform ${TF_VERSION} into ${BIN_DIR} ..."
        tmp="$(mktemp -d)"
        curl -fsSL -o "$tmp/terraform.zip" \
            "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
        unzip -o "$tmp/terraform.zip" -d "$BIN_DIR"
        chmod +x "$BIN_DIR/terraform"
        rm -rf "$tmp"
    else
        echo "ERROR: terraform CLI not found in PATH."
        exit 1
    fi
fi
terraform version

# ---- install scripts and config ------------------------------------------------
echo "Installing mirror scripts into ${BIN_DIR} ..."
install -m 0755 "$REPO_DIR/scripts/mirror-terraform.sh"         "$BIN_DIR/mirror-terraform.sh"
install -m 0755 "$REPO_DIR/scripts/mirror-terraform-modules.sh" "$BIN_DIR/mirror-terraform-modules.sh"

echo "Preparing config (${CONFIG_DIR}) and data (${DATA_DIR}) directories ..."
mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$(dirname "$LOG_FILE")"
cp -n "$REPO_DIR/config/all.providers" "$CONFIG_DIR/all.providers"
cp -n "$REPO_DIR/config/all.modules"   "$CONFIG_DIR/all.modules"
touch "$LOG_FILE"

# ---- cron ----------------------------------------------------------------------
echo "Installing cron job ${CRON_FILE} ..."
cat > "$CRON_FILE" <<EOF
# Terraform provider/module mirror
ALL_PROVIDERS=$CONFIG_DIR/all.providers
ALL_MODULES=$CONFIG_DIR/all.modules
MIRROR_DIR=$DATA_DIR
$CRON_SCHEDULE $CRON_USER $BIN_DIR/mirror-terraform.sh >> $LOG_FILE 2>&1
$CRON_SCHEDULE $CRON_USER $BIN_DIR/mirror-terraform-modules.sh >> $LOG_FILE 2>&1
EOF
chmod 0644 "$CRON_FILE"

echo
echo "Installation complete."
echo "  scripts: $BIN_DIR/mirror-terraform.sh, $BIN_DIR/mirror-terraform-modules.sh"
echo "  config:  $CONFIG_DIR/all.providers, $CONFIG_DIR/all.modules"
echo "  data:    $DATA_DIR"
echo "  cron:    $CRON_FILE  ($CRON_SCHEDULE, user: $CRON_USER)"
echo "  log:     $LOG_FILE"
echo
echo "Edit the config files, then run once manually to verify:"
echo "  sudo ALL_PROVIDERS=$CONFIG_DIR/all.providers MIRROR_DIR=$DATA_DIR $BIN_DIR/mirror-terraform.sh"
echo "  sudo ALL_MODULES=$CONFIG_DIR/all.modules     MIRROR_DIR=$DATA_DIR/modules $BIN_DIR/mirror-terraform-modules.sh"
