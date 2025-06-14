FROM quay.io/fedora/fedora-minimal:43-x86_64


# Install dnf5 and other necessary utilities
RUN microdnf install -y dnf5 dnf-utils 'dnf5-command(config-manager)' createrepo && microdnf clean all
RUN dnf upgrade -y
RUN dnf install -y cronie
RUN dnf install gawk -y
RUN dnf clean metadata


# Copy the mirror script and configuration file into the container
COPY scripts/mirror-repo.sh /usr/local/bin/mirror-repo.sh

# Make the mirror script executable
RUN chmod +x /usr/local/bin/mirror-repo.sh

