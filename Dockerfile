FROM alpine:edge AS builder
RUN apk update
RUN apk upgrade
RUN apk add --update go gcc g++ elogind-dev
WORKDIR /src
COPY postfix_exporter/go.mod postfix_exporter/go.sum ./
RUN go mod download
RUN go mod verify
ADD postfix_exporter .
RUN  CGO_ENABLED=1 GOOS=linux go build  -o /bin/postfix_exporter -tags nosystemd

#Dockerfile for a Postfix email relay service
FROM alpine:3.13
MAINTAINER Panagiotis Bariamis

RUN apk update && \
    apk add bash gawk cyrus-sasl cyrus-sasl-login cyrus-sasl-crammd5 mailx \
    perl supervisor postfix rsyslog && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /var/log/supervisor/ /var/run/supervisor/ && \
    sed -i -e 's/inet_interfaces = localhost/inet_interfaces = all/g' /etc/postfix/main.cf

COPY etc/ /etc/
COPY run.sh /
RUN chmod +x /run.sh
RUN newaliases

EXPOSE 25 587 9154

CMD ["/run.sh"]
