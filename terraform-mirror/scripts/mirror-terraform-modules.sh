#!/bin/bash

# Terraform Module Mirror
# Downloads module archives from the public Terraform Registry
# (https://registry.terraform.io/browse/modules) using the module
# registry download API.
#
# The registry answers a download request with HTTP 204 and an
# X-Terraform-Get header pointing at the module source, typically:
#   git::https://github.com/<org>/<repo>?ref=<commit-sha>
# This script resolves that pointer and downloads the matching
# source archive, repacked with the module files at the archive root.
#
# https://developer.hashicorp.com/terraform/internals/module-registry-protocol

# Paths are environment-overridable so the script also runs outside the container
ALL_MODULES="${ALL_MODULES:-/config/all.modules}"
MIRROR_DIR="${MIRROR_DIR:-/data/packages/terraform/modules}"
REGISTRY="${REGISTRY_URL:-https://registry.terraform.io}"

# Check if the configuration file exists
if [[ ! -f $ALL_MODULES ]]; then
    echo "Module configuration file not found: $ALL_MODULES"
    exit 1
fi

# Read header
IFS=',' read -r module_h version_h < "$ALL_MODULES"

# Loop over remaining lines
tail -n +2 "$ALL_MODULES" | while IFS=',' read -r module version; do
    # Skip empty lines and comments
    [[ -z "$module" || "$module" =~ ^[[:space:]]*# ]] && continue

    # Trim whitespace
    module="${module//[[:space:]]/}"
    version="${version//[[:space:]]/}"

    # module is "namespace/name/system", e.g. "terraform-aws-modules/vpc/aws"
    name="$(echo "$module" | cut -d/ -f2)"

    # "latest" or empty version: resolve the newest release from the registry
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

    download_url="$REGISTRY/v1/modules/$module/$version/download"

    # The registry responds 204 with an X-Terraform-Get header
    get_url="$(curl -fsSI "$download_url" | tr -d '\r' | sed -n 's/^[Xx]-[Tt]erraform-[Gg]et:[[:space:]]*//p')"
    if [[ -z "$get_url" ]]; then
        echo "ERROR: no X-Terraform-Get header returned for $module $version"
        echo "---------------- FAILED $module $version -------------------"
        continue
    fi
    echo "source=$get_url"

    # Strip go-getter style prefix and query, e.g.
    # git::https://github.com/<org>/<repo>?ref=<sha>
    src="${get_url#git::}"
    repo="${src%%\?*}"
    ref=""
    [[ "$src" == *\?ref=* ]] && ref="${src#*\?ref=}"

    dest_dir="$MIRROR_DIR/$module/$version"
    mkdir -p "$dest_dir"
    dest_file="$dest_dir/${name}-${version}.tar.gz"

    if [[ "$repo" =~ ^https://github\.com/ ]]; then
        # GitHub hosted: download the source archive for the ref
        orgrepo="${repo#https://github.com/}"
        archive_url="https://github.com/$orgrepo/archive/${ref:-HEAD}.tar.gz"

        echo "downloading $archive_url"
        tmp="$(mktemp -d /tmp/tf-module-XXXXXX)"
        # Repack without the <org>-<repo>-<sha>/ wrapper directory so the
        # archive has the module .tf files at its root
        if curl -fsSL "$archive_url" | tar -xz --strip-components=1 -C "$tmp"; then
            tar -czf "$dest_file" -C "$tmp" .
            echo "saved $dest_file"
        else
            echo "ERROR downloading $archive_url"
        fi
        rm -rf "$tmp"
    elif [[ "$repo" =~ \.(tar\.gz|tgz)$ ]]; then
        # Direct tar.gz archive URL
        curl -fsSL "$repo" -o "$dest_file" && echo "saved $dest_file"
    elif [[ "$repo" =~ \.zip$ ]]; then
        curl -fsSL "$repo" -o "$dest_dir/${name}-${version}.zip" && echo "saved $dest_dir/${name}-${version}.zip"
    else
        echo "ERROR: unsupported module source for $module: $get_url"
    fi

    echo "---------------- COMPLETED $module $version -------------------"
done

echo "Terraform module synchronization completed."
