
# Create a directory on the host for the ClamAV database:
mkdir -p /clamav-db
sudo chown -R $(whoami):$(whoami) /clamav-db
#Set correct permissions:
chmod -R u+rwX /clamav-db

#If using SELinux, ensure correct context:
sudo chcon -Rt container_file_t /clamav-db

# Run the container and execute the update, mounting the directory:
podman run --rm \
  -v /clamav-db:/clamav-db:Z \
  localhost/cvdupdate:latest \
  /bin/sh -c "cvd update"
