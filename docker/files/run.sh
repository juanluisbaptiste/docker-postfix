#!/bin/bash

# Set Debug
[ "${DEBUG}" == "yes" ] && set -x

# Function for Postfix config value add
add_config_value() {
  # Local variables
  local key=${1}
  local value=${2}
  # local config_file=${3:-/etc/postfix/main.cf}

  # If 'key' is empty
  if [[ "${key}" == "" ]] 
  then
    # Error Message
    echo "ERROR: No key set!" 
    exit 1
  fi

  # If 'value' is empty
  if [[ "${value}" == "" ]] 
  then
    # Error Message
    echo "ERROR: No value set!"
    exit 1
  fi

  # Log 'key' with 'value'
  echo "Setting configuration option ${key} with value: ${value}"

  # Set Postfix config
  postconf -e "${key} = ${value}"
}

# Read SMTP password from file to avoid unsecure env variables
if [[ -n "${SMTP_PASSWORD_FILE}" ]]
then
  # Check if 'SMTP_PASSWORD_FILE' exists
  if [[ -e "${SMTP_PASSWORD_FILE}" ]]
  then
    # Set SMTP_PASSWORD variable from file
    SMTP_PASSWORD=$(cat "${SMTP_PASSWORD_FILE}")

  else
    # Log error message, that SMTP_PASSWORD_FILE does not exist
    echo "SMTP_PASSWORD_FILE defined, but file not existing, skipping."
  fi
fi

# Read SMTP username from file to avoid unsecure env variables
if [[ -n "${SMTP_USERNAME_FILE}" ]]
then
  # Check if 'SMTP_USERNAME_FILE' exists
  if [[ -e "${SMTP_USERNAME_FILE}" ]]
  then
    # Set SMTP_USERNAME variable from file
    SMTP_USERNAME=$(cat "${SMTP_USERNAME_FILE}")

  else
    # Log error message, that SMTP_USERNAME_FILE does not exist
    echo "SMTP_USERNAME_FILE defined, but file not existing, skipping."
  fi
fi

# Check if SMTP_SERVER variable is empty
if [[ -z "${SMTP_SERVER}" ]]
then
  # Log error message
  echo "SMTP_SERVER is not set"

  # Exit Container
  exit 1
fi

# Check if SERVER_HOSTNAME variable is empty
if [[ -z "${SERVER_HOSTNAME}" ]]
then
  # Log error message
  echo "SERVER_HOSTNAME is not set"

  # Exit Container
  exit 1
fi

# Check if SMTP_USERNAME variable is set, but SMTP_PASSWORD variable is empty
if [[ -n "${SMTP_USERNAME}" ]] && [[ -z "${SMTP_PASSWORD}" ]]
then
  # Log error message
  echo "SMTP_USERNAME is set but SMTP_PASSWORD is not set"

  # Exit Container
  exit 1
fi

# Set SMTP Port, if not set use default value of 587
SMTP_PORT="${SMTP_PORT:-587}"

# Get the domain from the server host name
DOMAIN=$(echo "${SERVER_HOSTNAME}" | awk 'BEGIN{FS=OFS="."}{print $(NF-1),$NF}')

# Set needed config options
add_config_value "maillog_file" "/dev/stdout"
add_config_value "myhostname" "${SERVER_HOSTNAME}"
add_config_value "mydomain" "${DOMAIN}"
add_config_value "mydestination" "${DESTINATION:-localhost}"
add_config_value "myorigin" '$mydomain'
add_config_value "relayhost" "[${SMTP_SERVER}]:${SMTP_PORT}"
add_config_value "smtp_use_tls" "yes"

# Check if SMTP_USERNAME is set
if [[ -n "${SMTP_USERNAME}" ]]
then
  add_config_value "smtp_sasl_auth_enable" "yes"
  add_config_value "smtp_sasl_password_maps" "lmdb:/etc/postfix/sasl_passwd"
  add_config_value "smtp_sasl_security_options" "noanonymous"
fi

# Set needed config options
add_config_value "always_add_missing_headers" "${ALWAYS_ADD_MISSING_HEADERS:-no}"

# Also use "native" option to allow looking up hosts added to /etc/hosts via
# docker options (issue #51)
add_config_value "smtp_host_lookup" "native,dns"

# Check if SMTP_PORT is 465
if [[ "${SMTP_PORT}" = "465" ]]
then
  # Set needed config options
  add_config_value "smtp_tls_wrappermode" "yes"
  add_config_value "smtp_tls_security_level" "encrypt"
fi

# Bind to both IPv4 and IPv4
add_config_value "inet_protocols" "all"

# Create sasl_passwd file with auth credentials
if [[ ! -f /etc/postfix/sasl_passwd ]] && [[ -n "${SMTP_USERNAME}" ]]
then
  grep -q "${SMTP_SERVER}" /etc/postfix/sasl_passwd  > /dev/null 2>&1
  if [[ "${?}" -gt 0 ]]; then
    echo "Adding SASL authentication configuration"
    echo "[${SMTP_SERVER}]:${SMTP_PORT} ${SMTP_USERNAME}:${SMTP_PASSWORD}" >> /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
  fi
fi

# Set header tag
if [[ -n "${SMTP_HEADER_TAG}" ]]
then
  postconf -e "header_checks = regexp:/etc/postfix/header_checks"
  echo -e "/^MIME-Version:/i PREPEND RelayTag: $SMTP_HEADER_TAG\n/^Content-Transfer-Encoding:/i PREPEND RelayTag: $SMTP_HEADER_TAG" >> /etc/postfix/header_checks
  echo "Setting configuration option SMTP_HEADER_TAG with value: ${SMTP_HEADER_TAG}"
fi

# Enable logging of subject line
if [[ "${LOG_SUBJECT}" == "yes" ]]
then
  postconf -e "header_checks = regexp:/etc/postfix/header_checks"
  echo -e "/^Subject:/ WARN" >> /etc/postfix/header_checks
  echo "Enabling logging of subject line"
fi

# Check for subnet restrictions
nets='10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16'
if [[ -n "${SMTP_NETWORKS}" ]]
then
  declare ipv6re="^((([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|\
    ([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|\
    ([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|\
    ([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|\
    :((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}|\
    ::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|\
    (2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|\
    (2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))/[0-9]{1,3})$"

  for i in $(sed 's/,/\ /g' <<< "${SMTP_NETWORKS}")
  do
    if grep -Eq "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}" <<< "${i}"
    then
      nets+=", ${i}"
    elif grep -Eq "${ipv6re}" <<< "${i}"
    then
      readarray -d \/ -t arr < <(printf '%s' "${i}")
      nets+=", [${arr[0]}]/${arr[1]}"
    else
      echo "${i} is not in proper IPv4 or IPv6 subnet format. Ignoring."
    fi
  done
fi
add_config_value "mynetworks" "${nets}"

# Set SMTPUTF8
if [[ -n "${SMTPUTF8_ENABLE}" ]]
then
  postconf -e "smtputf8_enable = ${SMTPUTF8_ENABLE}"
  echo "Setting configuration option smtputf8_enable with value: ${SMTPUTF8_ENABLE}"
fi

if [[ -n "${OVERWRITE_FROM}" ]]
then
  echo -e "/^From:.*$/ REPLACE From: ${OVERWRITE_FROM}" > /etc/postfix/smtp_header_checks
  postmap /etc/postfix/smtp_header_checks
  postconf -e 'smtp_header_checks = regexp:/etc/postfix/smtp_header_checks'
  echo "Setting configuration option OVERWRITE_FROM with value: ${OVERWRITE_FROM}"
fi

# Set message_size_limit
if [[ -n "${MESSAGE_SIZE_LIMIT}" ]]
then
  postconf -e "message_size_limit = ${MESSAGE_SIZE_LIMIT}"
  echo "Setting configuration option message_size_limit with value: ${MESSAGE_SIZE_LIMIT}"
fi

# If host mounting /var/spool/postfix, we need to delete old pid file before
# starting services
rm -f /var/spool/postfix/pid/master.pid

# Start Postfix service
exec /usr/sbin/postfix -c /etc/postfix start-fg
