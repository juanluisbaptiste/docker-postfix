### Dockerfile for a Postfix email relay service###

# Alpine Base Image
FROM alpine:3.21.2

# Build Arguments
ARG ALPINE_VERSION="3.21.2" \
        IMAGE_VERSION="1.0.3" \
        POSTFIX_VERSION="3.9.1"

# Update and install packages
RUN apk update \
    && apk add --no-cache --upgrade apk-tools \
    && apk upgrade --no-cache --available \
    # Install needed packages
    && apk add bash gawk cyrus-sasl cyrus-sasl-login cyrus-sasl-crammd5 mailx postfix \
    # Clear cache
    && rm -rf /var/cache/apk/* \
    # Create log directories
    && mkdir -p /var/log/supervisor/ /var/run/supervisor/ \
    # Allow all interfaces
    && sed -i -e 's/inet_interfaces = localhost/inet_interfaces = all/g' /etc/postfix/main.cf

# Add start script
ADD files/run.sh /

# Make start script executable
RUN chmod +x /run.sh

# Build a new copy of the alias database
RUN newaliases

# Labeling
LABEL maintainer="Bleala" \
        version="${IMAGE_VERSION}" \
        description="Postfix ${POSTFIX_VERSION} on Alpine ${ALPINE_VERSION}" \
        org.opencontainers.image.source="https://github.com/Bleala/Postfix-DOCKERIZED" \
        org.opencontainers.image.url="https://github.com/Bleala/Postfix-DOCKERIZED"

# Expose Postfix Port
EXPOSE 25

# Cmd to run
CMD ["/run.sh"]
#ENTRYPOINT ["/run.sh"]
