# docker-postfix
[![Docker Build Status](https://img.shields.io/docker/build/juanluisbaptiste/postfix?style=flat-square)](https://hub.docker.com/r/juanluisbaptiste/postfix/build/)
[![Docker Stars](https://img.shields.io/docker/stars/juanluisbaptiste/postfix.svg?style=flat-square)](https://hub.docker.com/r/juanluisbaptiste/postfix/)
[![Docker Pulls](https://img.shields.io/docker/pulls/juanluisbaptiste/postfix.svg?style=flat-square)](https://hub.docker.com/r/juanluisbaptiste/postfix/)

Simple Postfix SMTP TLS relay [docker](http://www.docker.com) image with no local authentication enabled (to be run in a secure LAN).

It also includes rsyslog to enable logging to stdout.


_If you want to follow the development of this project check out [my blog](http://not403.blogspot.com.co/search/label/postfix)._

### Available image tags

This image has been built on CentOS 7 since its inception, but the new CentOS 8 does [not include supervisor](https://github.com/juanluisbaptiste/docker-postfix/issues/16) anymore, so I have started migrating this image to Alpine linux. So currently there are two image tags available:

  * juanluisbaptiste/postfix:latest, current CentOS 7 based image
  * juanluisbaptiste/postfix:alpine, new Alpine based image

If testing goes well for some time, then the current CentOS image will be replaced by the new Alpine one, and _latest_ tag will point to it.

### Build instructions

Clone this repo and then:

    cd docker-Postfix
    sudo docker build -t postfix .

Or you can use the provided [docker-compose](https://github.com/juanluisbaptiste/docker-postfix/blob/master/docker-compose.dev.yml) files:

    sudo docker-compose -f docker-compose.yml -f docker-compose.dev.yml build

For more information on using multiple compose files [see here](https://docs.docker.com/compose/production/). You can also find a prebuilt docker image from [Docker Hub](https://registry.hub.docker.com/u/juanluisbaptiste/postfix/), which can be pulled with this command:

    sudo docker pull juanluisbaptiste/postfix:latest

### How to run it

The following env variables need to be passed to the container:

* `SMTP_SERVER` Server address of the SMTP server to use.
* `SMTP_PORT` (Optional, Default value: 587) Port address of the SMTP server to use.
* `SMTP_USERNAME` Username to authenticate with.
* `SMTP_PASSWORD` Password of the SMTP user.
* `SERVER_HOSTNAME` Server hostname for the Postfix container. Emails will appear to come from the hostname's domain.
* `NO_RELAY` Postix will not be as a relay.

The following env variable(s) are optional.
* `SMTP_HEADER_TAG` This will add a header for tracking messages upstream. Helpful for spam filters. Will appear as "RelayTag: ${SMTP_HEADER_TAG}" in the email headers.

* `SMTP_NETWORKS` Setting this will allow you to add additional, comma seperated, subnets to use the relay. Used like
    -e SMTP_NETWORKS='xxx.xxx.xxx.xxx/xx,xxx.xxx.xxx.xxx/xx'

To use this container from anywhere, the 25 port or the one specified by `SMTP_PORT` needs to be exposed to the docker host server:

    docker run -d --name postfix -p "25:25"  \
           -e SMTP_SERVER=smtp.bar.com \
           -e SMTP_USERNAME=foo@bar.com \
           -e SMTP_PASSWORD=XXXXXXXX \
           -e SERVER_HOSTNAME=helpdesk.mycompany.com \
           juanluisbaptiste/postfix

If you are going to use this container from other docker containers then it's better to just publish the port:

    docker run -d --name postfix -P \
           -e SMTP_SERVER=smtp.bar.com \
           -e SMTP_USERNAME=foo@bar.com \
           -e SMTP_PASSWORD=XXXXXXXX \
           -e SERVER_HOSTNAME=helpdesk.mycompany.com \           
           juanluisbaptiste/postfix

Or if you can start the service using the provided [docker-compose](https://github.com/juanluisbaptiste/docker-postfix/blob/master/docker-compose.yml) file for production use:

    sudo docker-compose up -d

To see the email logs in real time:

    docker logs -f postfix

#### A note about using gmail as a relay

Gmail by default [does not allow email clients that don't use OAUTH 2](http://googleonlinesecurity.blogspot.co.uk/2014/04/new-security-measures-will-affect-older.html)
for authentication (like Thunderbird or Outlook). First you need to enable access to "Less secure apps" on your
[google settings](https://www.google.com/settings/security/lesssecureapps).

Also take into account that email `From:` header will contain the email address of the account being used to
authenticate against the Gmail SMTP server(SMTP_USERNAME), the one on the email will be ignored by Gmail unless you [add it as an alias](https://support.google.com/mail/answer/22370).


### Debugging
If you need troubleshooting the container you can set the environment variable _DEBUG=yes_ for a more verbose output.
