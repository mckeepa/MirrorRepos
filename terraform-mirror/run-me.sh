#!/bin/bash


# Using ROOTLESS
#stop all running containers
podman stop $(podman ps -q -f name=terraform-mirror)
podman rm $(podman ps -aq -f name=terraform-mirror)

podman build -t terraform-mirror .

mkdir -p data
cp -r terraform-mirror/config/ /data/config-terraform/

podman run -v /data/repo:/data:z -v /data/config-terraform:/config:z -v /data/log:/var/log/:z -it --name terraform-mirror terraform-mirror



# USING SUDO
#stop all running containers
sudo podman stop $(sudo podman ps -q -f name=terraform-mirror)
sudo podman rm $(sudo podman ps -aq -f name=terraform-mirror)

sudo podman build -t terraform-mirror .
sudo podman run -v /data/repo:/data:z -v /data/config-terraform:/config:z -v /data/log:/var/log/:z -it --name terraform-mirror terraform-mirror



# Run as a Service
# ~/.config/containers/systemd/terraform-mirror.container

mkdir -p ~/.config/containers/systemd/
cp ./terraform-mirror.container ~/.config/containers/systemd/terraform-mirror.container

systemctl --user daemon-reload
systemctl --user list-unit-files           | grep terraform-mirror
systemctl --user list-units --type=service | grep terraform-mirror
systemctl --user start terraform-mirror.service
systemctl --user enable terraform-mirror.service
