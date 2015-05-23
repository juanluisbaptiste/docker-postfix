#!/bin/bash

[ -z "${SMTP_SERVER}" ] && echo "SMTP_SERVER is not set" && exit 1
[ -z "${SMTP_USERNAME}" ] && echo "SMTP_USERNAME is not set" && exit 1
[ -z "${SMTP_PASSWORD}" ] && echo "SMTP_PASSWORD is not set" && exit 1

#Get the domain from the server host name
DOMAIN=`echo $SERVER_HOSTNAME |awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//'`

#Comment default mydestination, we will set it bellow
sed -i -e '/mydestination/ s/^#*/#/' /etc/postfix/main.cf

echo "myhostname=$SERVER_HOSTNAME"  >> /etc/postfix/main.cf
echo "mydomain=$DOMAIN"  >> /etc/postfix/main.cf
echo 'mydestination=$myhostname'  >> /etc/postfix/main.cf
echo 'myorigin=$mydomain'  >> /etc/postfix/main.cf
echo "relayhost = [$SMTP_SERVER]:587" >> /etc/postfix/main.cf
echo "smtp_use_tls=yes" >> /etc/postfix/main.cf
echo "smtp_sasl_auth_enable = yes" >> /etc/postfix/main.cf
echo "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" >> /etc/postfix/main.cf
echo "smtp_sasl_security_options = noanonymous" >> /etc/postfix/main.cf

echo "[$SMTP_SERVER]:587 $SMTP_USERNAME:$SMTP_PASSWORD" >> /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

supervisord