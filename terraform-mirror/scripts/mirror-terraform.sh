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

# ----------------------------------------------------------------------------
# Generate the JSON index files for Terraform's "network mirror" protocol.
#
# `terraform providers mirror` only writes the provider .zip files. When the
# mirror directory is served by a plain web server (httpd), the Terraform
# client additionally expects two JSON documents per provider:
#
#   <hostname>/<namespace>/<name>/index.json     -> {"versions": {"1.2.3": {}}}
#   <hostname>/<namespace>/<name>/<version>.json -> {"archives": {"linux_amd64":
#                                                     {"url": ..., "hashes": [...]}}}
#
# "hashes" holds "h1:" + base64(SHA256 of the .zip) — the same hash Terraform
# records in .terraform.lock.hcl.
# ----------------------------------------------------------------------------
generate_provider_indexes() {
    local providers_root="$MIRROR_DIR/registry.terraform.io"
    [[ -d "$providers_root" ]] || return 0

    local provider_dir version_dir platform_dir zip_file
    for provider_dir in "$providers_root"/*/*; do
        [[ -d $provider_dir ]] || continue

        # index.json lists every mirrored version of this provider
        local index_json='{"versions":{'
        local first=1
        for version_dir in "$provider_dir"/*/; do
            [[ -d $version_dir ]] || continue
            local version="${version_dir%/}"
            version="${version##*/}"

            [[ $first -eq 0 ]] && index_json+=","
            index_json+="\"$version\":{}"
            first=0

            # <version>.json lists one archive per mirrored platform
            local archives_json="{"
            local a_first=1
            for platform_dir in "$version_dir"/*/; do
                [[ -d $platform_dir ]] || continue
                local platform="${platform_dir%/}"
                platform="${platform##*/}"

                zip_file="$(find "$platform_dir" -maxdepth 1 -name '*.zip' -print -quit)"
                [[ -f $zip_file ]] || continue

                local hash="h1:$(openssl dgst -sha256 -binary "$zip_file" | base64)"
                [[ $a_first -eq 0 ]] && archives_json+=","
                archives_json+="\"$platform\":{\"url\":\"$version/$platform/$(basename "$zip_file")\",\"hashes\":[\"$hash\"]}"
                a_first=0
            done
            archives_json+="}"
            echo "{\"archives\":$archives_json}" > "$provider_dir/$version.json"
        done
        index_json+="}}"
        echo "$index_json" > "$provider_dir/index.json"
        echo "wrote network-mirror index for ${provider_dir#"$providers_root"/}"
    done
}

generate_provider_indexes

echo "Terraform provider synchronization completed."
