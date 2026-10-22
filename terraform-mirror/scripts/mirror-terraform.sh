#!/bin/bash

# Terraform Provider Mirror
# Mirrors providers from registry.terraform.io into a local filesystem
# mirror layout using 'terraform providers mirror'.
# https://developer.hashicorp.com/terraform/cli/commands/providers/mirror

# Paths are environment-overridable so the script also runs outside the container
ALL_PROVIDERS="${ALL_PROVIDERS:-/config/all.providers}"
MIRROR_DIR="${MIRROR_DIR:-/data/packages/terraform}"

export CHECKPOINT_DISABLE=1
export TF_IN_AUTOMATION=1

# Check if the configuration file exists
if [[ ! -f $ALL_PROVIDERS ]]; then
    echo "Provider configuration file not found: $ALL_PROVIDERS"
    exit 1
fi

# Read header
IFS=',' read -r provider_h version_h platforms_h < "$ALL_PROVIDERS"

# Loop over remaining lines
tail -n +2 "$ALL_PROVIDERS" | while IFS=',' read -r provider version platforms; do
    # Skip empty lines and comments
    [[ -z "$provider" || "$provider" =~ ^[[:space:]]*# ]] && continue

    # Trim whitespace
    provider="${provider//[[:space:]]/}"
    version="${version//[[:space:]]/}"
    # Trim ends but keep inner spaces (platforms are space separated)
    platforms="$(echo "$platforms" | xargs)"

    # Default platform if none specified
    [[ -z "$platforms" ]] && platforms="linux_amd64"

    # provider is "namespace/name", e.g. "hashicorp/aws"
    name="${provider##*/}"

    # "latest" or empty version resolves the newest release
    [[ -z "$version" ]] && version="latest"

    echo "provider=$provider"
    echo "version=$version"
    echo "platforms=$platforms"

    # Generate a throwaway configuration for this provider
    workdir="$(mktemp -d /tmp/tf-mirror-XXXXXX)"
    {
        echo "terraform {"
        echo "  required_providers {"
        echo "    $name = {"
        echo "      source  = \"$provider\""
        [[ "$version" != "latest" ]] && echo "      version = \"$version\""
        echo "    }"
        echo "  }"
        echo "}"
    } > "$workdir/main.tf"

    # Build -platform arguments
    platform_args=()
    for p in $platforms; do
        platform_args+=("-platform=$p")
    done

    echo "terraform -chdir=$workdir providers mirror ${platform_args[*]} $MIRROR_DIR"

    terraform -chdir="$workdir" providers mirror "${platform_args[@]}" "$MIRROR_DIR"

    rm -rf "$workdir"

    echo "---------------- COMPLETED $provider $version ($platforms) -------------------"
done

echo "Terraform provider synchronization completed."
