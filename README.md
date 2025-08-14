# RPM Repository Mirror

This project provides a Container-based solution for creating a mirror of an RPM repository. It includes all necessary scripts and configuration files to set up and run the repository synchronisation process.


| Project Name     | Description                       |
|------------------|-----------------------------------|
|**Repo-Mirror-Base:** | Used as a base for `Repo-Mirror`, the base is fedora-minimal and including all updates from date the base image is created image.|
|**Repo-Mirror:**  | Includes Script to register repos, and to download repos to a `/data/packages/`. This Directory is a mounted volume. |
|**scan files:**   | uses ClamAV to scan `/scan` directory and move files that fail into the `/quarantine`. Before Scanning ClamAv updates it's  database from the directory `/clamav-db`.  The three directories are passed in as volumes.|
|**Web-Server:**   | Website to expose the downloaded files. Uses Apache HTTPD, exposed contents on `/data/packages/` from web server.|




# Containers Used
  - Mirror repos using DNF base => ` localhost/rpm-repo-mirror-base:latest` => `quay.io/fedora/fedora-minimal:43-x86_64`
  - Scan files  =>  `python:3.12-alpine`
  - Expose files via Web Server  => `httpd:alpine`



## Prerequisites




### Install Podman

Allow rootless users to run containers is podman. 

Referenced Site:  
 [RHEL allow rootless Containes in Podman](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/building_running_and_managing_containers/assembly_starting-with-containers_building-running-and-managing-containers#proc_upgrading-to-rootless-containers_assembly_starting-with-containers)

Ensure Sub UIDs do not clash with other users.
```bash
# check exisitong users
sudo cat /etc/subuid
```
Allocate Sub UserIds
```bash
sudo  usermod --add-subuids 200000-201000 --add-subgids 200000-201000 <userid>
podman ps
```

Create a new Linux Group to access resources
```bash
sudo groupadd podman-repo-mirror 
sudo usermod --append --groups podman-repo-mirror <userid1>
sudo usermod --append --groups podman-repo-mirror <userid2>

# verify users have been added
grep 'podman-repo-mirror' /etc/group
```

Grant Group access to directories on the host
```bash
sudo chown -R :podman-repo-mirror /mnt/packages
# Verify Ownership has changed
ls -la /mnt/
ls -la /mnt/packages/
```


## Building the repo-mirror Image
To build the base  image, navigate to the project directory and run:


## Project Structure

- **Dockerfile**: Contains instructions to build the Docker image for the RPM repository mirror.
- **scripts/mirror-repo.sh**: Script responsible for syncing the RPM repositories using `dnf` or `yum`.
- **config/repo-config.repo**: Configuration file specifying the repository URLs and options for synchronization.
- **data**: Directory to hold mirrored repository data. (Tracked by Git with `.gitkeep`)
- **docker-compose.yml**: Defines services, networks, and volumes for the Docker application.
- **README.md**: Documentation for building and running the Docker container.


Build the base Image first
```bash
podman build -t rpm-repo-mirror-base ./repo-mirror-base
```

Before building `repo-mirror` project, update sure the correct Repos are configure for mirroring: 
  - ./repo-mirror-base/config/all.repos
  - ./repo-mirror-base/config/repos

Add any more repos you need. 
`./repo-mirror-base/config/all.repos`
```ini
[rocky-9.6-x86_64-baseos]
[code]
```
`./repo-mirror-base/config/repos/rocky.repo`
```ini
[rocky-9.6-x86_64-baseos]
name=Rocky Linux $releasever - BaseOS
baseurl=http://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/
gpgcheck=1
enabled=1
countme=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
```

`./repo-mirror-base/config/repos/vscode.repo`
```ini
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode/
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
```

### Build the image
```bash
podman build -t rpm-repo-mirror ./repo-mirror
```
### Running the Container

Create a base image with the latest updates as 
To run the container with these volumes:
  - /data     -> directory to persist the mirrored repository data.
  - /var/log/:z -> Logs

```bash
podman run --rm -v /data/repo:/data:z -v /data/log:/var/log/:z  -it --name rpm-repo-mirror rpm-repo-mirror
```

### Usage

After running the container, the RPM repositories specified in the `config/repo-config.repo` file will be synchronized to the `data` directory.


## Build the Web Server

Non-root can't use standard ports like 443 or 80, 
sothe website could be: 
  - run on the host and not in a container    
  - run as root / privileged user
  - Place a Proxy such as Nginx to 443    

In this example it will be run it as root. 
```bash
sudo podman build -t file-browser ./webserver
```




# Run on Boot

## User setup for start on Boot

Use a service account `repo-code-sv`
```bash
sudo useradd repo-code-sv
sudo passwd repo-code-sv

```
## add user to group

Create a group, and add the user 
```bash
sudo groupadd podman-repo-mirror
sudo usermod --append --groups podman-repo-mirror repo-code-sv

# verify user works
su -l repo-code-sv
podman ps
```

Allow `service user` account to start a service at system start that persists over logouts.

```bash
ssh repo-code-sv@localhost

loginctl show-user repo-code-sv | grep ^Linger
Linger=no

loginctl enable-linger repo-code-sv

loginctl show-user repo-code-sv | grep ^Linger
Linger=yes

exit
```

## Export Image from Podman
Export the build image so it can be load into the profile for the service account or moved to another server

```bash
podman images  -a fedora/fedora-minimal --no-trunc
podman export -o quay.io_fedora_fedora-minimal_43-x86_64.tar sha256:cc3a8d84b8c80a5cea864e90ec58dec86d50ce78aec13bd1a0be45aa95cf3e59

podman save -o rpm-repo-mirror.tar --format oci-archive rpm-repo-mirror
mv rpm-repo-mirror.tar /tmp/
```

## As the (`repo-code-sv`) service Account, load the OCI Image into the registry 
```bash
ssh repo-code-sv@localhost
podman load -i /tmp/rpm-repo-mirror.tar 

sudo mkdir /data
sudo mkdir /data/repos

# chown USER:GROUP FILE
sudo chown repo-code-sv:podman-repo-mirror /data
sudo chown repo-code-sv:podman-repo-mirror /data/repos

```
 ### Another Example 
```bash
podman pull ghcr.io/steele-ntwrk/custom-netbox-dtli:offline
podman images  -a ghcr.io/steele-ntwrk/custom-netbox-dtli --no-trunc
podman save -o custom-netbox-dtli.tar --format oci-archive sha256:7e3329d675895dc1834cda96f8b8ddfd2eea5ff7614a61fbd705617ce05137f3

# Get it off the vm and on to a desktop
scp paul@192.168.122.243:/home/paul/custom-netbox-dtli.tar   /tmp/

# On target machine 
podman load -i  custom-netbox-dtli.tar  


```

## Run the Container so and create SYSTEMD
```bash
podman run -v /data/repos:/data:Z -it --name rpm-repo-mirror rpm-repo-mirror

podman generate systemd --new --files --name rpm-repo-mirror
```
## rootless containers running under Systemd
```bash
podman generate systemd --name --new rpm-repo-mirror

mkdir -p $HOME/.config/containers/systemd 
vi $HOME/.config/containers/systemd/container-rpm-repo-mirror.service

mkdir -p ~/.config/systemd/user/
mv $HOME/.config/containers/systemd/container-rpm-repo-mirror.service ~/.config/systemd/user/
# $HOME/.config/containers/systemd/container-rpm-repo-mirror.service

systemctl --user daemon-reload

systemctl --user start container-rpm-repo-mirror
systemctl --user is-active container-rpm-repo-mirror
systemctl --user status container-rpm-repo-mirror

podman ps
```

## Create a timer for starting the Service.
```bash
vi ~/.config/systemd/user/container-rpm-repo-mirror-timer.timer
```

```ini
[Unit]
Description=container-rpm-repo-mirror Timer
Requires=container-rpm-repo-mirror.service

[Timer]
OnCalendar=*:00/5:00
Unit=container-rpm-repo-mirror.service

[Install]
WantedBy=timers.target
```

```bash
systemctl --user daemon-reload

systemctl --user start container-rpm-repo-mirror-timer.timer
systemctl --user is-active container-rpm-repo-mirror-timer.timer
systemctl --user status container-rpm-repo-mirror-timer.timer
```