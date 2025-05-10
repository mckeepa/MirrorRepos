# RPM Repository Mirror

This project provides a Container-based solution for creating a mirror of an RPM repository. It includes all necessary scripts and configuration files to set up and run the repository synchronization process.

## Project Structure

- **Dockerfile**: Contains instructions to build the Docker image for the RPM repository mirror.
- **scripts/mirror-repo.sh**: Script responsible for syncing the RPM repositories using `dnf` or `yum`.
- **config/repo-config.repo**: Configuration file specifying the repository URLs and options for synchronization.
- **data**: Directory to hold mirrored repository data. (Tracked by Git with `.gitkeep`)
- **docker-compose.yml**: Defines services, networks, and volumes for the Docker application.
- **README.md**: Documentation for building and running the Docker container.

## Prerequisites

- Docker / Podman installed on your machine.
- Docker Compose installed (if using `docker-compose.yml`).

## Install Podman

### Allow Rootless
 [RHEL allow rootless Containes in Podman](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/building_running_and_managing_containers/assembly_starting-with-containers_building-running-and-managing-containers#proc_upgrading-to-rootless-containers_assembly_starting-with-containers)

Ensure Sub UIDs do not clash with other users.
```bash
# check exisitong users
sudo cat /etc/subuid
```

```bash
sudo  usermod --add-subuids 200000-201000 --add-subgids 200000-201000 <userid>
podman ps
```
### Create a Linux Group to access resources
```bash
sudo groupadd podman-repo-mirror 
sudo usermod --append --groups podman-repo-mirror <userid1>
sudo usermod --append --groups podman-repo-mirror <userid2>

# verify users have been added
grep 'podman-repo-mirror' /etc/group
```

## Grant Group access to volume

```bash
sudo chown -R :podman-repo-mirror /mnt/packages
# Verify Ownership has changed
ls -la /mnt/
ls -la /mnt/packages/
```

## Building the Docker Image

To build the Docker image, navigate to the project directory and run:

```
docker build -t rpm-repo-mirror .
```

## Running the Container

To run the container, use the following command:

```
docker run --rm -v $(pwd)/data:/data rpm-repo-mirror
```

This command mounts the `data` directory to persist the mirrored repository data.

## Usage

After running the container, the RPM repositories specified in the `config/repo-config.repo` file will be synchronized to the `data` directory.

## Contributing

Feel free to submit issues or pull requests for improvements or additional features.