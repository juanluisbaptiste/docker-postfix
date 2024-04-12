#Dockerfile for a Postfix email relay service
FROM alpine:3.16

RUN apk update && \
    apk add bash gawk cyrus-sasl cyrus-sasl-login cyrus-sasl-crammd5 mailx \
    postfix && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /var/log/supervisor/ /var/run/supervisor/ && \
    sed -i -e 's/inet_interfaces = localhost/inet_interfaces = all/g' /etc/postfix/main.cf

COPY run.sh /
RUN chmod +x /run.sh
RUN newaliases

# Labeling
LABEL maintainer="Bleala" \
        org.opencontainers.image.source="https://github.com/Bleala/Postfix-DOCKERIZED" \
        org.opencontainers.image.url="https://github.com/Bleala/Postfix-DOCKERIZED"

EXPOSE 25
#ENTRYPOINT ["/run.sh"]
CMD ["/run.sh"]
