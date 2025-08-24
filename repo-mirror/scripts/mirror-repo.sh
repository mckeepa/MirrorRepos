#!/bin/bash

# Load repository configuration
# REPO_CONFIG="/config/repo-config.repo"
# REPO_CONFIG="/etc/yum.repos.d/repo-config.repo"
cp /config/repos/* /etc/yum.repos.d/
ALL_REPOS="/config/all.repos"

file_path="/etc/dnf/dnf.conf"
cat "$file_path"

# Check if the configuration file exists
if [[ ! -f $ALL_REPOS ]]; then
    echo "Repository configuration file not found: $ALL_REPOS"
    exit 1
fi

# Disable all repositories
# Get the list of repo ids
repo_ids=$(dnf repo list | awk 'NR > 1 {print $1}')

# Disable each repository
for repo_id in $repo_ids; do
    echo "Disabling repository: $repo_id"
    #dnf config-manager --set-disabled "$repo_id"
    dnf config-manager setopt "$repo_id".enabled=0
done


# get the contents inside the []
repo_ids=$(grep -oP '^\[\K[^\]]+' "$ALL_REPOS")
for repo_id in $repo_ids; do
    echo "Enabling repository: $repo_id"
    dnf config-manager setopt "$repo_id".enabled=1
done


for repo_id in $repo_ids; do
    # Sync the repository
    echo "Syncing repository: $repo_id"
    #dnf reposync --delete -p /mnt/packages/ --repoid="$repo_id" --newest-only --download-metadata
    dnf reposync -p /data/packages/ --repoid="$repo_id" --newest-only --download-metadata
    echo "Completed Syncing repository: $repo_id"
done


# # Read repository URLs from the configuration file
# while IFS= read -r line; do



#     value=$(echo "$line" | grep -oP '\[\K[^\]]+')
#     # Skip empty lines and comments
#     [[ -z "$value" || "$value" =~ ^# ]] && continue

#     # dnf config-manager --set-enabled "$value" 
#     dnf config-manager setopt "$value".enabled=1

#     # Sync the repository
#     echo "Syncing repository: $line"
#     dnf reposync --delete -p /mnt/packages/ --repoid="$value" --newest-only --download-metadata
# done < "$REPO_CONFIG"

echo "Repository synchronization completed."