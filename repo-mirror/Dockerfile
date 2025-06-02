# FROM fedora:latest
# FROM fedora-minimal:latest
# FROM quay.io/fedora/fedora-minimal:latest
FROM localhost/rpm-repo-mirror-base:latest
# FROM redhat/ubi9-minimal:latest


# Install dnf5
# RUN microdnf install -y dnf5 dnf-utils 'dnf5-command(config-manager)' createrepo httpd && microdnf clean all
# RUN microdnf install -y gawk

# RUN microdnf install -y dnf5 dnf-utils 'dnf5-command(config-manager)' createrepo && microdnf clean all
# RUN dnf upgrade -y
# RUN dnf install gawk -y


# Copy the mirror script and configuration file into the container
COPY scripts/mirror-repo.sh /usr/local/bin/mirror-repo.sh

COPY config/all.repos /config/all.repos
COPY config/repo-config.repo /etc/yum.repos.d/repo-config.repo
COPY config/rocky.repo /etc/yum.repos.d/rocky.repo


# Install necessary packages for repository mirroring
# RUN dnf install -y dnf-utils createrepo httpd && \
#     dnf clean all
# RUN dnf clean metadata
# RUN dnf update


# Make the mirror script executable
RUN chmod +x /usr/local/bin/mirror-repo.sh

# Set the entry point for the container
ENTRYPOINT ["/usr/local/bin/mirror-repo.sh"]
#ENTRYPOINT ["/bin/bash"]