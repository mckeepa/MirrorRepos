
```bash
cd ./webserver

#sudo podman stop $(sudo podman ps -q)
sudo podman stop $(sudo podman ps -aq -f name=file-browser)

#sudo podman rm $(sudo podman ps -aq)
sudo podman rm $(sudo podman ps -aq -f name=file-browser)

sudo podman build -t file-browser .
sudo podman run -it -p 8080:80 -v ../repo-mirror/data:/data:ro --name file-browser file-browser 

# podman run -d -p 8080:80 -v /data/repos:/data:Z file-browser
# podman run -d -p 8080:80 -v /data/repos:/mnt:Z file-browser

```

## Export image and load into local Image Regsitry
```bash
podman image list 
# or
podman image list --no-trunc

# podman save -o oci-alpine.tar --format oci-archive alpine
podman save -o file-browser.tar --format oci-archive localhost/file-browser


podman save -o docker.io-library-httpd-alpine.tar --format oci-archive docker.io/library/httpd:alpine
podman save -o file-browser.tar --format oci-archive localhost/file-browser:latest

podman save -o fedora-minimal.tar --format oci-archive quay.io/fedora/fedora-minimal:43-x86_64
podman save -o rpm-repo-mirror-base.tar --format oci-archive localhost/rpm-repo-mirror-base:latest
podman save -o rpm-repo-mirror.tar --format oci-archive localhost/rpm-repo-mirror:latest

#remove ALL Local images -a (all) -f (force)c
podman rmi -a -f

podman load -i file-browser.tar
```

## Run the Container so and create SYSTEMD
```bash

# podman run -v /data/repos:/data:Z -it --name rpm-repo-mirror rpm-repo-mirror
podman run -d -p 8080:80 -v /data/repos:/data:Z --name file-browser file-browser
podman generate systemd --new --files --name file-browser
```
# rootless containers running under Systemd

```bash
podman generate systemd --name --new file-browser

mkdir -p $HOME/.config/containers/systemd 
vi $HOME/.config/containers/systemd/container-file-browser.service

mkdir -p ~/.config/systemd/user/
mv $HOME/.config/containers/systemd/container-file-browser.service ~/.config/systemd/user/
# $HOME/.config/containers/systemd/container-rpm-repo-mirror.service

systemctl --user daemon-reload

systemctl --user start container-file-browser
systemctl --user is-active container-file-browser
systemctl --user status container-file-browser

podman ps
```