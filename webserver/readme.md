
```bash
cd ./webserver

podman stop $(podman ps -q)
podman rm $(podman ps -aq)

podman build -t file-browser .


podman run -d -p 8080:80 -v /data/repos:/data:Z file-browser
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