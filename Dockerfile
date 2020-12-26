#Dockerfile for a Postfix email relay service
FROM alpine:latest
LABEL net.rev-system.auther="Juan Luis Baptiste juan.baptiste@gmail.com" \
    net.rev-system.original-source="https://github.com/juanluisbaptiste/docker-postfix" \
    net.rev-system.descripption="Simple Postfix SMTP TLS relay docker image with no local authentication enabled (to be run in a secure LAN)."

RUN apk update && \
    apk add bash gawk cyrus-sasl cyrus-sasl-plain cyrus-sasl-login cyrus-sasl-crammd5 mailx \
    perl supervisor postfix rsyslog && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /var/log/supervisor/ /var/run/supervisor/ && \
    sed -i -e 's/inet_interfaces = localhost/inet_interfaces = all/g' /etc/postfix/main.cf

COPY etc/ /etc/
COPY run.sh /
RUN chmod +x /run.sh
RUN newaliases

EXPOSE 25
#ENTRYPOINT ["/run.sh"]
CMD ["/run.sh"]
