# ClamAV antivirus scan on directories

1. Run the container to update the ClamAV signature database (stored on a mounted volume).
2. Run the scan container with three mounted volumes:
   - directory holding the ClamAV signature DB
   - target directory to be scanned
   - quarantine directory for files that fail the scan