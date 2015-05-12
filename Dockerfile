#Dockerfile for a Postfix email relay service
FROM centos:latest
MAINTAINER Juan Luis Baptiste juan.baptiste@gmail.com

RUN yum install -y epel-release && yum update -y && \
    yum install -y cyrus-sasl cyrus-sasl-plain cyrus-sasl-md5 mailx \ 
    perl supervisor postfix
RUN sed -i -e "s/^nodaemon=false/nodaemon=true/" /etc/supervisord.conf
RUN sed -i -e 's/inet_interfaces = localhost/inet_interfaces = all/g' /etc/postfix/main.cf
COPY run.sh /
RUN chmod +x /run.sh
COPY etc/supervisord.d/postfix.ini /etc/supervisord.d/
RUN newaliases

EXPOSE 25
#ENTRYPOINT ["/run.sh"]
CMD ["/run.sh"]