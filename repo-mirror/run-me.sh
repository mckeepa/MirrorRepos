#!/bin/bash


# Using ROOTLESS
#stop all running containers
podman stop $(podman ps -q -f name=rpm-repo-mirror)
podman rm $(podman ps -aq -f name=rpm-repo-mirror)


#sudo podman ps -all
#sudo podman rm ec47032d334c
podman build -t rpm-repo-mirror .

mkdir data
podman run -v ./data:/data:z -it --name rpm-repo-mirror rpm-repo-mirror
# podman run -v /mnt/packages:/mnt/packages:Z -it -p 8081:80 --name rpm-repo-mirror rpm-repo-mirror
# podman run -it -p 8081:80 --name rpm-repo-mirror rpm-repo-mirror


cd ./webserver
podman build -t file-browser .
podman run -d -p 8080:80 -v /mnt/packages:/mnt/packages:Z file-browser
cd ..









# USING SUDO
#stop all running containers
sudo podman stop $(sudo podman ps -q -f name=rpm-repo-mirror)
sudo podman rm $(sudo podman ps -aq -f name=rpm-repo-mirror)

#sudo podman ps -all
#sudo podman rm ec47032d334c
sudo podman build -t rpm-repo-mirror .
sudo podman run -v /data:/data:z -it --name rpm-repo-mirror rpm-repo-mirror

#sudo podman run --mount type=volume,source=/data,destination=/data,ro=true -it --name rpm-repo-mirror rpm-repo-mirror
# sudo podman run -v /mnt/packages:/mnt/packages:Z -it -p 8081:80 --name rpm-repo-mirror rpm-repo-mirror

cd ./webserver
sudo podman build -t file-browser .
sudo podman run -d -p 8080:80 -v /mnt/packages:/mnt/packages:Z file-browser
cd ..