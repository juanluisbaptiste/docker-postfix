#!/bin/bash

[ "${DEBUG}" == "yes" ] && set -x

function add_config_value() {
  local key=${1}
  local value=${2}
  local config_file=${3:-/etc/postfix/main.cf}
  [ "${key}" == "" ] && echo "ERROR: No key set !!" && exit 1
  [ "${value}" == "" ] && echo "ERROR: No value set !!" && exit 1

  echo "Setting configuration option ${key} with value: ${value}"
 postconf -e "${key} = ${value}"
}

# Read password from file to avoid unsecure env variables
if [ -n "${SMTP_PASSWORD_FILE}" ]; then [ -f "${SMTP_PASSWORD_FILE}" ] && read SMTP_PASSWORD < ${SMTP_PASSWORD_FILE} || echo "SMTP_PASSWORD_FILE defined, but file not existing, skipping."; fi

[ -z "${SMTP_SERVER}" ] && echo "SMTP_SERVER is not set" && exit 1
[ -z "${SMTP_USERNAME}" ] && echo "SMTP_USERNAME is not set" && exit 1
[ -z "${SMTP_PASSWORD}" ] && echo "SMTP_PASSWORD is not set" && exit 1
[ -z "${SERVER_HOSTNAME}" ] && echo "SERVER_HOSTNAME is not set" && exit 1

SMTP_PORT="${SMTP_PORT:-587}"

#Get the domain from the server host name
DOMAIN=`echo ${SERVER_HOSTNAME} |awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//'`

# Set needed config options
add_config_value "myhostname" ${SERVER_HOSTNAME}
add_config_value "mydomain" ${DOMAIN}
add_config_value "mydestination" '$myhostname'
add_config_value "myorigin" '$mydomain'
add_config_value "relayhost" "[${SMTP_SERVER}]:${SMTP_PORT}"
add_config_value "smtp_use_tls" "yes"
add_config_value "smtp_sasl_auth_enable" "yes"
add_config_value "smtp_sasl_password_maps" "hash:/etc/postfix/sasl_passwd"
add_config_value "smtp_sasl_security_options" "noanonymous"

# Create sasl_passwd file with auth credentials
if [ ! -f /etc/postfix/sasl_passwd ]; then
  grep -q "${SMTP_SERVER}" /etc/postfix/sasl_passwd  > /dev/null 2>&1
  if [ $? -gt 0 ]; then
    echo "Adding SASL authentication configuration"
    echo "[${SMTP_SERVER}]:${SMTP_PORT} ${SMTP_USERNAME}:${SMTP_PASSWORD}" >> /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
  fi
fi

#Set header tag  
if [ ! -z "${SMTP_HEADER_TAG}" ]; then
  postconf -e "header_checks = regexp:/etc/postfix/header_tag"
  echo -e "/^MIME-Version:/i PREPEND RelayTag: $SMTP_HEADER_TAG\n/^Content-Transfer-Encoding:/i PREPEND RelayTag: $SMTP_HEADER_TAG" > /etc/postfix/header_tag
  echo "Setting configuration option SMTP_HEADER_TAG with value: ${SMTP_HEADER_TAG}"
fi

#Check for subnet restrictions
nets='10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16'
if [ ! -z "${SMTP_NETWORKS}" ]; then
        for i in $(sed 's/,/\ /g' <<<$SMTP_NETWORKS); do
                if grep -Eq "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}" <<<$i ; then
                        nets+=", $i"
                else
                        echo "$i is not in proper IPv4 subnet format. Ignoring."
                fi
        done
fi
add_config_value "mynetworks" "${nets}"

#Start services

# If host mounting /var/spool/postfix, we need to delete old pid file before
# starting services
rm -f /var/spool/postfix/pid/master.pid

exec supervisord
