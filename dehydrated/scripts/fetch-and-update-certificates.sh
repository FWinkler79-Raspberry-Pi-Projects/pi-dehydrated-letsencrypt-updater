#!/bin/bash

# Register with Let's Encrypt.
/dehydrated/scripts/register-with-letsencrypt.sh

# After registration, request certificates.
/dehydrated/scripts/request-certificates.sh

# Unregister from Let's Encrypt.
/dehydrated/scripts/unregister.sh

# Remove any remains of accounts.
/dehydrated/scripts/remove-accounts-and-chains-cache.sh