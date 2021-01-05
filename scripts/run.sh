#!/bin/bash

# Check if there is an accounts folder in the 
# container. If not, register with Let's Encrypt.
ACCOUNTS_FOLDER="/letsencrypt/accounts"
if [ -d $ACCOUNTS_FOLDER ]; then
  echo "Found accounts folder. Reusing account for fetching certificates."
else
  echo "Registering with Let's Encrypt"
  /scripts/register.sh
fi

/scripts/fetch-certs.sh

# Create a CRON tab that renews the certs every 1st day of every month.
echo "0 1 1 * * /scripts/fetch-certs.sh" > /etc/crontabs/root

# Excute the CRON daemon in background (-b) to check logs (-d = stderr, 8 = Error, 0 = verbose)
crond -f -d 8