file="../config/all.repos"

# Read header
IFS=',' read -r repoId_h releasever_h basearch_h < "$file"

# Loop over remaining lines
tail -n +2 "$file" | while IFS=',' read -r repoId releasever basearch; do
    # Trim whitespace
    repoId="${repoId//[[:space:]]/}"
    releasever="${releasever//[[:space:]]/}"
    basearch="${basearch//[[:space:]]/}"

    echo "repoId=$repoId"
    echo "releasever=$releasever"
    echo "basearch=$basearch"
    echo "----"
done