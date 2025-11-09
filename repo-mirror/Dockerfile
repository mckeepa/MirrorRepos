FROM localhost/rpm-repo-mirror-base:latest

RUN dnf install -y cronie && dnf clean all


# Copy the mirror script and configuration file into the container
COPY config/all.repos        /config/all.repos

#COPY config/repo-config.repo /etc/yum.repos.d/repo-config.repo
#COPY config/rocky.repo       /etc/yum.repos.d/rocky.repo
COPY config/* /etc/yum.repos.d/
RUN ls -la /etc/yum.repos.d/

# Copy the mirror script into the container
COPY scripts/mirror-repo.sh /usr/local/bin/mirror-repo.sh
RUN chmod +x /usr/local/bin/mirror-repo.sh

# Add the cron job
RUN mkdir -p /etc/cron.d

# Run every hour on the hour
# RUN echo "0 * * * * /usr/local/bin/mirror-repo.sh >> /var/log/mirror-repo.log 2>&1" > /etc/cron.d/mirror-repo

# run every 5 minutes
RUN echo "*/5 * * * * /usr/local/bin/mirror-repo.sh >> /var/log/mirror-repo.log 2>&1" > /etc/cron.d/mirror-repo


RUN chmod 0644 /etc/cron.d/mirror-repo 
RUN crontab /etc/cron.d/mirror-repo

# Ensure log file exists
RUN touch /var/log/mirror-repo.log

# Start cron in the foreground
CMD ["crond", "-n"]

# Make the mirror script executable
#RUN chmod +x /usr/local/bin/mirror-repo.sh

# Set the entry point for the container
# ENTRYPOINT ["sh", "-c",  "/usr/local/bin/mirror-repo.sh >> /var/log/mirror-repo-entry.log 2>&1"]
# ...existing code...
# ENTRYPOINT ["sh", "-c", "/usr/local/bin/mirror-repo.sh >> /var/log/mirror-repo-entry.log 2>&1; tail -f /dev/null"]
# ...existing code...
#ENTRYPOINT ["/bin/bash"]
