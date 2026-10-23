#!/bin/bash

# Scan the mirrored files with ClamAV; files that fail are moved to quarantine.
#
# Three directories are mounted into the container:
#   SCAN_DIR       - the files to scan (the mirrored packages)
#   QUARANTINE_DIR - files that fail the scan are moved here
#   CLAMAV_DB      - ClamAV signature database (keep it updated via cv-update.sh)
#
# One-off host prep (first time only):
#   sudo mkdir -p /data/quarantine /data/clamav-db
#   sudo chown -R $(whoami):$(id -gn) /data/quarantine /data/clamav-db
SCAN_DIR="${SCAN_DIR:-/data/repo/packages}"
QUARANTINE_DIR="${QUARANTINE_DIR:-/data/quarantine}"
CLAMAV_DB="${CLAMAV_DB:-/data/clamav-db}"

podman run --rm \
  -v "$SCAN_DIR":/scan:Z \
  -v "$QUARANTINE_DIR":/quarantine:Z \
  -v "$CLAMAV_DB":/clamav-db:Z \
  docker.io/clamav/clamav:latest \
  /bin/sh -c "clamscan --database=/clamav-db -r --move=/quarantine /scan"
