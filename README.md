# docker-postfix
Simple Postfix SMTP TLS relay [docker](http://www.docker.com) image.

### Build instructions

Clone this repo and then:

    cd docker-Postfix
    sudo docker build -t postfix .

You can also find a prebuilt docker image from [Docker Hub](https://registry.hub.docker.com/u/juanluisbaptiste/postfix/), which can be pulled with this command:

    sudo docker pull juanluisbaptiste/postfix:latest

### How to run it

The following env variables need to be passed to the container:

* `SMTP_SERVER` Server address of the SMTP server to use.
* `SMTP_USERNAME` Username to authenticate with.
* `SMTP_PASSWORD` Password of the SMTP user.

To use this container from anywhere, the port 25 needs to be exposed to the docker host server:

    docker run --rm --name postfix -p "25:25" -e SMTP_SERVER=smtp.bar.com -e SMTP_USERNAME=foo@bar.com -e SMTP_PASSWORD=XXXXXXXX postfix
    
If you are going to use this container from other docker containers then it's better to just publish the port:

    docker run --rm --name postfix -P -e SMTP_SERVER=smtp.bar.com -e SMTP_USERNAME=foo@bar.com -e SMTP_PASSWORD=XXXXXXXX postfix
    
    
#### A note about using gmail as a relay

Since last year, Gmail by default (does not allow email clients that don't use OAUTH 2)[http://googleonlinesecurity.blogspot.co.uk/2014/04/new-security-measures-will-affect-older.html] 
for authentication (like Thunderbird or Outlook). First you need to enable access to "Less secure apps" on your 
[google settings](https://www.google.com/settings/security/lesssecureapps). 

Also take into account that email `From:` header will contain the email address of the account being used to 
authenticate against the Gmail SMTP server(SMTP_USERNAME), the one on the email will be ignored by Gmail.