#Dockerfile for a Postfix email relay service
FROM alpine
MAINTAINER Juan Luis Baptiste juan.baptiste@gmail.com
ARG PACKAGES="bash gawk cyrus-sasl cyrus-sasl-plain cyrus-sasl-login cyrus-sasl-crammd5 mailx perl postfix"
RUN apk update && \
    apk upgrade && \
    apk add --update --no-cache $PACKAGES && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /var/log/supervisor/ /var/run/supervisor/ && \
    sed -i -e 's/inet_interfaces = localhost/inet_interfaces = all/g' /etc/postfix/main.cf 

COPY run.sh /
RUN chmod +x /run.sh && \
    newaliases

EXPOSE 25
#ENTRYPOINT ["/run.sh"]
CMD ["/run.sh"]
