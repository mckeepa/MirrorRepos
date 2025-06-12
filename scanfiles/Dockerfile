FROM python:3.12-alpine

# Install pip3 (already included in python:alpine), and git (required for some pip installs)
RUN apk add --no-cache git

# Install cvdupdate using pip3
RUN pip3 install --no-cache-dir cvdupdate


RUN cvd config set --dbdir /clamav-db

# Set default command
# CMD ["cvdupdate", "list"]
CMD ["cvd", "update"]