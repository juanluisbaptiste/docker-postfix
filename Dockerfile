#Dockerfile for a Postfix email relay service
FROM debian:latest
LABEL maintainer="Juan Luis Baptiste juan.baptiste@gmail.com"
RUN set -eux; \
    apt-get update; \
    apt-get install -y \
        supervisor \
        postfix \
        rsyslog \
    ; \
    rm -rf /var/lib/apt/lists/*

RUN sed -i -e 's/inet_interfaces = localhost/inet_interfaces = all/g' /etc/postfix/main.cf
RUN mkdir -p /var/run/supervisor

COPY etc/*.conf /etc/
COPY etc/rsyslog.d/* /etc/rsyslog.d
COPY run.sh /
RUN chmod +x /run.sh
COPY etc/supervisord.d/*.ini /etc/supervisord.d/
RUN newaliases

EXPOSE 25
#ENTRYPOINT ["/run.sh"]
CMD ["/run.sh"]