#!/bin/bash

#Ensure both directories are owned by your user:
sudo chown -R $(whoami):$(whoami) /data /quarantine

#Set correct permissions:
chmod -R u+rwX /data /quarintine

#If using SELinux, ensure correct context:
sudo chcon -Rt container_file_t /data/quarantine



SCAN_DIR="/data/repo-mirror"
QUARANTINE_DIR="/data/quarantine"
CLAMAV_DB="/data/clamav-db"

podman run --rm \
  -v "$SCAN_DIR":/scan:Z \
  -v "$QUARANTINE_DIR":/quarantine:Z \
  -v "$CLAMAV_DB":/clamav-db:Z \
  clamav/clamav:latest \
  /bin/sh -c "clamscan --database=/clamav-db -r --move=/quarantine /scan"



podman run --rm \
  -v "$SCAN_DIR":/scan:Z \
  -v "$QUARANTINE_DIR":/quarantine:Z \
  -v "$CLAMAV_DB":/clamav-db:Z \
  localhost/scan-mirror:latest \
  /bin/sh -c "clamscan --database=/clamav-db -r --move=/quarantine /scan"

# 
#  /bin/sh -c "freshclam && clamscan -r --move=/quarantine /scan"
