#!/bin/bash

# Update the local ClamAV signature database using cvdupdate.
# Run before scanfiles.sh, and schedule it (e.g. daily via cron) so the
# signatures stay current.
#
# One-off host prep (first time only):
#   sudo mkdir -p /data/clamav-db
#   sudo chown -R $(whoami):$(id -gn) /data/clamav-db
#
# Build the updater image once:  podman build -t cvdupdate ./scanfiles
CLAMAV_DB="${CLAMAV_DB:-/data/clamav-db}"

podman run --rm \
  -v "$CLAMAV_DB":/clamav-db:Z \
  localhost/cvdupdate:latest \
  cvd update
