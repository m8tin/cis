###########################################################################
# Dockerfile to build a Container to update TLS Certificates automatically.
# Based on latest Ubuntu LTS
###########################################################################
# See https://hub.docker.com/_/ubuntu
FROM ubuntu:latest

# Update repositories
RUN echo Version 20251030v1
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y apt-utils

#### BEGIN INSTALLATION ###################################################
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y cron curl dnsutils openssh-client

ADD acme.sh-3.1.1.tar.gz /tmp/acme.sh-setup/
COPY renewCerts.sh /renewCerts.sh
COPY start.sh /start.sh 

# Run the command on container startup
CMD ["bash", "/start.sh"]
