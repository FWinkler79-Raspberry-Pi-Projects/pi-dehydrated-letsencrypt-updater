#!/bin/bash

# Check if there is an accounts folder in the 
# container. If not, register with Let's Encrypt.
# ACCOUNTS_FOLDER="/dehydrated/accounts"
# if [ -d $ACCOUNTS_FOLDER ]; then
#   # If an account already exist, don't register again ...
#   echo "Found accounts folder! Reusing account for fetching certificates."
# else
#   # ... otherwise register with Let's Encrypt.
#   /dehydrated/scripts/register-with-letsencrypt.sh
# fi

# Fetch certificates by registering, downloading and un-registering.
/dehydrated/scripts/fetch-and-update-certificates.sh

# Finally, create a CRON tab that renews the certs every 1st day of every month.
echo "Creating a CRON tab to renew certificates every 1st day of every month."
echo "0 1 1 * * /dehydrated/scripts/fetch-and-update-certificates.sh" > /etc/crontabs/root
echo

# Excute the CRON daemon in background (-b) to check logs (-d = stderr, 8 = Error, 0 = verbose)
echo "Starting CRON daemon."
crond -f -d 8