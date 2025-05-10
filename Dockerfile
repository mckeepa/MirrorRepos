# FROM fedora:latest
FROM fedora-minimal:latest

# Install dnf5
RUN microdnf install -y dnf5 dnf-utils 'dnf5-command(config-manager)' createrepo httpd && microdnf clean all

# Install necessary packages for repository mirroring
# RUN dnf install -y dnf-utils createrepo httpd && \
#     dnf clean all

# Copy the mirror script and configuration file into the container
COPY scripts/mirror-repo.sh /usr/local/bin/mirror-repo.sh
COPY config/repo-config.repo /etc/yum.repos.d/repo-config.repo

# Make the mirror script executable
RUN chmod +x /usr/local/bin/mirror-repo.sh

# Set the entry point for the container
ENTRYPOINT ["/usr/local/bin/mirror-repo.sh"]
#ENTRYPOINT ["/bin/bash"]