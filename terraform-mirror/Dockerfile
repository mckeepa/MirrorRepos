FROM localhost/rpm-repo-mirror-base:latest

# Terraform CLI version to install
ARG TF_VERSION=1.9.8

# Tools needed to fetch Terraform
RUN dnf install -y curl unzip cronie && dnf clean all

# Download and install the Terraform CLI
RUN curl -fsSL -o /tmp/terraform.zip \
        "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" \
    && unzip -o /tmp/terraform.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/terraform \
    && rm -f /tmp/terraform.zip \
    && terraform version

# Copy the provider and module lists into the container
COPY config/all.providers /config/all.providers
COPY config/all.modules /config/all.modules

# Copy the mirror scripts into the container
COPY scripts/mirror-terraform.sh /usr/local/bin/mirror-terraform.sh
COPY scripts/mirror-terraform-modules.sh /usr/local/bin/mirror-terraform-modules.sh
RUN chmod +x /usr/local/bin/mirror-terraform.sh /usr/local/bin/mirror-terraform-modules.sh

# Add the cron job
RUN mkdir -p /etc/cron.d

# run every 5 minutes
RUN echo "*/5 * * * * /usr/local/bin/mirror-terraform.sh >> /var/log/mirror-terraform.log 2>&1" > /etc/cron.d/mirror-terraform
RUN echo "*/5 * * * * /usr/local/bin/mirror-terraform-modules.sh >> /var/log/mirror-terraform.log 2>&1" >> /etc/cron.d/mirror-terraform

RUN chmod 0644 /etc/cron.d/mirror-terraform
RUN crontab /etc/cron.d/mirror-terraform

# Ensure log file exists
RUN touch /var/log/mirror-terraform.log

# Start cron in the foreground
CMD ["crond", "-n"]
