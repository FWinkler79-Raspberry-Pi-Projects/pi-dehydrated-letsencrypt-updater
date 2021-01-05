#!/usr/bin/env bash
set -e
set -u
set -o pipefail

# Your Domain
domain="<your Duck DNS domain>"

# Your DuckDNS Token
token="<your Duck DNS Token>"
 
case "$1" in
    "deploy_challenge")
        curl "https://www.duckdns.org/update?domains=$domain&token=$token&txt=$4"
        echo
        ;;
    "clean_challenge")
        curl "https://www.duckdns.org/update?domains=$domain&token=$token&txt=removed&clear=true"
        echo
        ;;
    "deploy_cert")
        echo "Certificates download succeeded."
        echo "Restarting Home Assistant container."
        docker container restart hass
	    ;;
    "unchanged_cert")
        echo "Certificate unchanged. Doing nothing."
        ;;
    "startup_hook")
        echo "Started up successfully"
        ;;
    "exit_hook")
        echo "Exited successfully."
        ;;
    *)
        #echo Unknown hook "${1}"
        #exit 0
        ;;
esac
