#!/bin/bash

[ "${DEBUG}" == "yes" ] && set -x

function add_config_value() {
  local key=${1}
  local value=${2}
  # local config_file=${3:-/etc/postfix/main.cf}
  [ "${key}" == "" ] && echo "ERROR: No key set !!" && exit 1
  [ "${value}" == "" ] && echo "ERROR: No value set !!" && exit 1

  echo "Setting configuration option ${key} with value: ${value}"
 postconf -e "${key} = ${value}"
}

# Read password and username from file to avoid unsecure env variables
if [ -n "${SMTP_PASSWORD_FILE}" ]; then [ -e "${SMTP_PASSWORD_FILE}" ] && SMTP_PASSWORD=$(cat "${SMTP_PASSWORD_FILE}") || echo "SMTP_PASSWORD_FILE defined, but file not existing, skipping."; fi
if [ -n "${SMTP_USERNAME_FILE}" ]; then [ -e "${SMTP_USERNAME_FILE}" ] && SMTP_USERNAME=$(cat "${SMTP_USERNAME_FILE}") || echo "SMTP_USERNAME_FILE defined, but file not existing, skipping."; fi

[ -z "${SMTP_SERVER}" ] && echo "SMTP_SERVER is not set" && exit 1
[ -z "${SERVER_HOSTNAME}" ] && echo "SERVER_HOSTNAME is not set" && exit 1
[ ! -z "${SMTP_USERNAME}" -a -z "${SMTP_PASSWORD}" ] && echo "SMTP_USERNAME is set but SMTP_PASSWORD is not set" && exit 1

SMTP_PORT="${SMTP_PORT:-587}"

#Get the domain from the server host name
DOMAIN=`echo ${SERVER_HOSTNAME} | awk 'BEGIN{FS=OFS="."}{print $(NF-1),$NF}'`

# Set needed config options
add_config_value "maillog_file" "/dev/stdout"
add_config_value "myhostname" ${SERVER_HOSTNAME}
add_config_value "mydomain" ${DOMAIN}
add_config_value "mydestination" "${DESTINATION:-localhost}"
add_config_value "myorigin" '$mydomain'
add_config_value "relayhost" "[${SMTP_SERVER}]:${SMTP_PORT}"
add_config_value "smtp_use_tls" "yes"
if [ ! -z "${SMTP_USERNAME}" ]; then
  add_config_value "smtp_sasl_auth_enable" "yes"
  add_config_value "smtp_sasl_password_maps" "lmdb:/etc/postfix/sasl_passwd"
  add_config_value "smtp_sasl_security_options" "noanonymous"
fi
add_config_value "always_add_missing_headers" "${ALWAYS_ADD_MISSING_HEADERS:-no}"
#Also use "native" option to allow looking up hosts added to /etc/hosts via
# docker options (issue #51)
add_config_value "smtp_host_lookup" "native,dns"

if [ "${SMTP_PORT}" = "465" ]; then
  add_config_value "smtp_tls_wrappermode" "yes"
  add_config_value "smtp_tls_security_level" "encrypt"
fi

# Bind to both IPv4 and IPv4
add_config_value "inet_protocols" "all"

# Create sasl_passwd file with auth credentials
if [ ! -f /etc/postfix/sasl_passwd -a ! -z "${SMTP_USERNAME}" ]; then
  grep -q "${SMTP_SERVER}" /etc/postfix/sasl_passwd  > /dev/null 2>&1
  if [ $? -gt 0 ]; then
    echo "Adding SASL authentication configuration"
    echo "[${SMTP_SERVER}]:${SMTP_PORT} ${SMTP_USERNAME}:${SMTP_PASSWORD}" >> /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
  fi
fi

#Set header tag
if [ ! -z "${SMTP_HEADER_TAG}" ]; then
  postconf -e "header_checks = regexp:/etc/postfix/header_checks"
  echo -e "/^MIME-Version:/i PREPEND RelayTag: $SMTP_HEADER_TAG\n/^Content-Transfer-Encoding:/i PREPEND RelayTag: $SMTP_HEADER_TAG" >> /etc/postfix/header_checks
  echo "Setting configuration option SMTP_HEADER_TAG with value: ${SMTP_HEADER_TAG}"
fi

#Enable logging of subject line
if [ "${LOG_SUBJECT}" == "yes" ]; then
  postconf -e "header_checks = regexp:/etc/postfix/header_checks"
  echo -e "/^Subject:/ WARN" >> /etc/postfix/header_checks
  echo "Enabling logging of subject line"
fi

#Check for subnet restrictions
nets='10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16'
if [ ! -z "${SMTP_NETWORKS}" ]; then
  declare ipv6re="^((([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|\
    ([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|\
    ([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|\
    ([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|\
    :((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}|\
    ::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|\
    (2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|\
    (2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))/[0-9]{1,3})$"

  for i in $(sed 's/,/\ /g' <<<$SMTP_NETWORKS); do
    if grep -Eq "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}" <<<$i ; then
      nets+=", $i"
    elif grep -Eq "$ipv6re" <<<$i ; then
      readarray -d \/ -t arr < <(printf '%s' "$i")
      nets+=", [${arr[0]}]/${arr[1]}"
    else
      echo "$i is not in proper IPv4 or IPv6 subnet format. Ignoring."
    fi
  done
fi
add_config_value "mynetworks" "${nets}"

# Set SMTPUTF8
if [ ! -z "${SMTPUTF8_ENABLE}" ]; then
  postconf -e "smtputf8_enable = ${SMTPUTF8_ENABLE}"
  echo "Setting configuration option smtputf8_enable with value: ${SMTPUTF8_ENABLE}"
fi

if [ ! -z "${OVERWRITE_FROM}" ]; then
  echo -e "/^From:.*$/ REPLACE From: $OVERWRITE_FROM" > /etc/postfix/smtp_header_checks
  postmap /etc/postfix/smtp_header_checks
  postconf -e 'smtp_header_checks = regexp:/etc/postfix/smtp_header_checks'
  echo "Setting configuration option OVERWRITE_FROM with value: ${OVERWRITE_FROM}"
fi

# Set message_size_limit
if [ ! -z "${MESSAGE_SIZE_LIMIT}" ]; then
  postconf -e "message_size_limit = ${MESSAGE_SIZE_LIMIT}"
  echo "Setting configuration option message_size_limit with value: ${MESSAGE_SIZE_LIMIT}"
fi

#Start services

# If host mounting /var/spool/postfix, we need to delete old pid file before
# starting services
rm -f /var/spool/postfix/pid/master.pid

exec /usr/sbin/postfix -c /etc/postfix start-fg
