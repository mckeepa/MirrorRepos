#!/bin/bash

# ============================================================================
# Terraform Module Mirror
# ============================================================================
# What this script does:
#
#   Terraform "modules" are reusable bundles of infrastructure code that
#   people publish on the public Terraform Registry
#   (https://registry.terraform.io/browse/modules).
#
#   This script downloads ("mirrors") copies of the modules listed in a
#   simple CSV file, so they can later be served from a local file share
#   or web server — e.g. for machines with no internet access.
#
# How it works, step by step:
#   1. Read the CSV file: each line is "module name, version".
#   2. Ask the registry where that module's source code actually lives
#      (the registry only returns a pointer, usually a GitHub repo +
#      commit ID).
#   3. Download that source code as a .tar.gz archive.
#   4. Repack the archive so the module files sit at the top level, and
#      save it under MIRROR_DIR/<module>/<version>/.
#
# Only needs: bash, curl, tar. No Terraform installation required.
#
# Registry API reference:
#   https://developer.hashicorp.com/terraform/internals/module-registry-protocol
# ============================================================================

# ----------------------------------------------------------------------------
# Configuration — every value can be overridden via environment variables.
#
# The syntax "${VAR:-default}" means: use the value of VAR if it is set,
# otherwise use the default. This lets the same script run both inside the
# container (which uses the /config and /data paths) and directly on a host.
#
#   ALL_MODULES  - path to the CSV file listing the modules to download
#   MIRROR_DIR   - folder where the downloaded module archives are saved
#   REGISTRY_URL - base address of the Terraform Registry API
# ----------------------------------------------------------------------------
# Note: bash variable assignments must not have spaces around the "=".
ALL_MODULES="${ALL_MODULES:-/config/all.modules}"
MIRROR_DIR="${MIRROR_DIR:-/data/packages/terraform/modules}"
REGISTRY="${REGISTRY_URL:-https://registry.terraform.io}"

# ----------------------------------------------------------------------------
# Safety check: make sure the CSV file exists before doing any work.
# "-f" tests "is this an existing file?". If not, print an error and stop.
# ----------------------------------------------------------------------------
if [[ ! -f $ALL_MODULES ]]; then
    echo "Module configuration file not found: $ALL_MODULES"
    exit 1
fi

# ----------------------------------------------------------------------------
# Read the CSV file line by line.
#
# The first line is a column header ("module,version") — read it here and
# discard it so it is not treated as a module.
# "IFS=','" tells "read" to split each line at the comma.
# ----------------------------------------------------------------------------
IFS=',' read -r module_h version_h < "$ALL_MODULES"

# "tail -n +2" outputs the file starting at line 2 (i.e. skips the header).
# The "while read" loop then processes one module per line.
tail -n +2 "$ALL_MODULES" | while IFS=',' read -r module version; do
    # Skip blank lines and comment lines (starting with #).
    # "continue" jumps straight to the next line of the file.
    [[ -z "$module" || "$module" =~ ^[[:space:]]*# ]] && continue

    # Remove all whitespace from both values, so stray spaces in the CSV
    # (e.g. "vpc, 5.13.0") do not break URLs or folder names later.
    module="${module//[[:space:]]/}"
    version="${version//[[:space:]]/}"

    # A module name has three parts: "namespace/name/system",
    # e.g. "terraform-aws-modules/vpc/aws". "cut -d/ -f2" picks the middle
    # part ("vpc"), which is used later when naming the downloaded file.
    name="$(echo "$module" | cut -d/ -f2)"

    # If the CSV says "latest" (or the version is empty), ask the registry
    # for the newest published version. The registry answers with JSON;
    # the grep/cut pipeline picks out the first "version": "x.y.z" value.
    if [[ -z "$version" || "$version" == "latest" ]]; then
        version="$(curl -fsS "$REGISTRY/v1/modules/$module" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)"
        if [[ -z "$version" ]]; then
            echo "ERROR: could not resolve latest version for $module"
            echo "---------------- FAILED $module -------------------"
            continue
        fi
        echo "resolved latest version=$version"
    fi

    echo "module=$module"
    echo "version=$version"

    # ------------------------------------------------------------------
    # Ask the registry: "where do I download this exact version?"
    # ------------------------------------------------------------------
    download_url="$REGISTRY/v1/modules/$module/$version/download"

    # The registry does not host the files itself. It answers with HTTP
    # status 204 ("no content") plus a response header named
    # "X-Terraform-Get" that points at the real source, typically:
    #   git::https://github.com/<org>/<repo>?ref=<commit-sha>
    #
    # We deliberately use GET and discard the (empty) body instead of
    # a lighter HEAD request: the registry's CDN answers HEAD with
    # "405 Method Not Allowed" for some modules (e.g. Azure/regions).
    # The sed command extracts just the value of the X-Terraform-Get header.
    get_url="$(curl -fsS -o /dev/null -D - "$download_url" | tr -d '\r' | sed -n 's/^[Xx]-[Tt]erraform-[Gg]et:[[:space:]]*//p')"
    if [[ -z "$get_url" ]]; then
        echo "ERROR: no X-Terraform-Get header returned for $module $version"
        echo "---------------- FAILED $module $version -------------------"
        continue
    fi
    echo "source=$get_url"

    # ------------------------------------------------------------------
    # Break the X-Terraform-Get value into its useful parts.
    #
    # Example:  git::https://github.com/Azure/terraform-azurerm-naming?ref=abc123
    #   "git::"       - prefix telling Terraform which fetcher to use (ignored)
    #   "?ref=abc123" - the exact git commit of the release
    #
    # After the lines below:
    #   repo = https://github.com/Azure/terraform-azurerm-naming
    #   ref  = abc123
    # ------------------------------------------------------------------
    src="${get_url#git::}"          # drop the "git::" prefix if present
    repo="${src%%\?*}"             # keep everything before the "?"
    ref=""
    [[ "$src" == *\?ref=* ]] && ref="${src#*\?ref=}"   # keep text after "?ref="

    # Build the output paths, e.g.
    #   <mirror>/terraform-aws-modules/vpc/aws/5.13.0/vpc-5.13.0.tar.gz
    dest_dir="$MIRROR_DIR/$module/$version"
    mkdir -p "$dest_dir"   # create the folder (and any parents) if needed
    dest_file="$dest_dir/${name}-${version}.tar.gz"

    if [[ "$repo" =~ ^https://github\.com/ ]]; then
        # --- Most common case: the module source lives on GitHub ---
        # GitHub can serve any commit as a .tar.gz archive at:
        #   https://github.com/<org>/<repo>/archive/<commit>.tar.gz
        orgrepo="${repo#https://github.com/}"
        archive_url="https://github.com/$orgrepo/archive/${ref:-HEAD}.tar.gz"

        echo "downloading $archive_url"
        tmp="$(mktemp -d /tmp/tf-module-XXXXXX)"   # temporary working folder
        # Download and unpack in one step. GitHub's archive wraps everything
        # in a top folder named "<repo>-<commit>/"; "--strip-components=1"
        # removes that wrapper so the module's .tf files sit at the root,
        # which is the layout Terraform expects.
        if curl -fsSL "$archive_url" | tar -xz --strip-components=1 -C "$tmp"; then
            # Repack the cleaned-up files into the final archive.
            tar -czf "$dest_file" -C "$tmp" .
            echo "saved $dest_file"
        else
            echo "ERROR downloading $archive_url"
        fi
        rm -rf "$tmp"   # always clean up the temporary folder
    elif [[ "$repo" =~ \.(tar\.gz|tgz)$ ]]; then
        # --- Rare case: the pointer is already a direct .tar.gz download ---
        curl -fsSL "$repo" -o "$dest_file" && echo "saved $dest_file"
    elif [[ "$repo" =~ \.zip$ ]]; then
        # --- Rare case: the pointer is a direct .zip download ---
        curl -fsSL "$repo" -o "$dest_dir/${name}-${version}.zip" && echo "saved $dest_dir/${name}-${version}.zip"
    else
        # Anything else (e.g. a non-GitHub git server) is not supported;
        # report it and move on to the next module in the CSV.
        echo "ERROR: unsupported module source for $module: $get_url"
    fi

    echo "---------------- COMPLETED $module $version -------------------"
done

echo "Terraform module synchronization completed."
