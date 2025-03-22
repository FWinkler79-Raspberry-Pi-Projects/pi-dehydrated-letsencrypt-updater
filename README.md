# pi-dehydrated-letsencrypt-updater

- [What is pi-dehydrated-letsencrypt-updater?](#what-is-pi-dehydrated-letsencrypt-updater)
- [What does PDLU do?](#what-does-pdlu-do)
- [How does PDLU work?](#how-does-pdlu-work)
- [Usage](#usage)
  - [Using Docker-Compose](#using-docker-compose)
  - [User Configurations](#user-configurations)
  - [Starting a Container](#starting-a-container)
- [Troubleshooting](#troubleshooting)
- [Appendix A: Technical Setup](#appendix-a-technical-setup)
  - [Contents](#contents)
  - [Image File Structure](#image-file-structure)
  - [Docker File](#docker-file)
  - [Scripts Explained](#scripts-explained)
- [Appendix B: Building the image](#appendix-b-building-the-image)
- [Appendix C: Advanced Usage](#appendix-c-advanced-usage)
- [References](#references)

## What is pi-dehydrated-letsencrypt-updater?

pi-dehydrated-letsencrypt-updater (PDLU) is a docker image that fetches [Let's Encrypt](https://letsencrypt.org) certificates for domains registered with [Duck DNS](https://www.duckdns.org/). It was built for Raspberry Pi with 64-bit ARM processors, but it could easily be built for other platforms as well.

Let's Encrypt is a certificate authority (CA) that issues signed certificates free of charge. Duck DNS is a free dynamic DNS (dynDNS) services that you can register domains for your servers with.

If you have a home server accessible by a given domain registered with Duck DNS, and you protect the server with e.g. HTTPS, you will need a valid and signed certificate that was issued by a trusted certificate authority and for your domain. This is what PDLU was built for.

PDLU is based on [dehydrated](https://github.com/dehydrated-io/dehydrated/tree/master), a shell script that implements a Let´s Encrypt client. 

PDLU also includes a docker client inside the image. That allows PDLU to restart docker containers on the Docker host, e.g. after certificates have been refreshed and applications referring to them need to be restarted.

In the following we explain how PDLU is used and how it works.

## What does PDLU do? 

In a nutshell, PDLU does the following:

1. Register an account with [Let's Encrypt](https://letsencrypt.org). 
2. Request Certificates for one or more Duck [Duck DNS](https://www.duckdns.org) domains.
3. Handle Let's Encrypt challenges to prove ownership of the Duck DNS domains.
4. Download signed certificates from Let's Encrypt.
5. Automatically refresh certificates.
6. Restarts a configurable set of docker containers on the Docker host machine.

## How does PDLU work?

> :medal_sports: The working model of this image was greatly inspired by the excellent blog post on [Hass, DuckDNS and Let's Encrypt](https://www.splitbrain.org/blog/2017-08/10-homeassistant_duckdns_letsencrypt) from the Home Assistant community.

To understand how PDLU works, we first need to understand how Let's Encrypt works. Let's Encrypt uses the ACME v2 Protocol to request and exchange certificates. As the owner of a network domain you request certificates from Let's Encrypt. When you so so, you have to prove to Let's Encrypt that you are the rightful owner of the domain. To do so, Let's Encrypt will respond with a _challenge_ to your initial certificate request. The challenge is simply a randomized token value. 

In order to prove that you are the rightful owner of the domain, you need to make the challenge token value available to Let's Encrypt via a Web server or a DNS server you control. By providing the challenge value back to Let's Encrypt via a different channel tied to your domain (Web or DNS) you prove that you control the domain. That's reason enough for Let's Encrypt to trust you and sign certificates for you. Essentially, this is a two-factor authentication. 

In our case we will be using DNS as the channel to prove ownership of our domain. To do so, we need to make sure that the challenge token received by Let's Encrypt is added as `TXT` entries to the DNS records issued by the DNS server when somebody - like Let's Encrypt - does a DNS lookup of our domain. Since Duck DNS owns and controls our DNS server, we need to tell Duck DNS to add the challenge token to DNS records for our domain. Duck DNS provides a REST API for that. To call that API we need to get an API token, which is bound to our Duck DNS account, which we used to register our domain. 

Once we have called the Duck DNS REST API to include the challenge token inte DNS records, we inform Let's Encrypt that it can do a DNS lookup of our domain and verify that the the challenge was properly included. If that is the case, we have proven to Let's Encrypt that we own and control the domain. 

## Usage

### Using Docker-Compose

You can use the image with plain `docker`, but it is recommended to use `docker-compose`, since it simplifies usage a lot.

The following docker-compose file shows how the image can / should be used:

```bash
---
services:
  cert-updater:
    image: fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0
    container_name: cert-updater
    network_mode: host
    dns:
      - 8.8.8.8   # required due to some alpine issue with not resolving names properly.
    environment:
      - PUID=1000
      - PGID=1000
      # (Mandatory) Your Duck DNS API token.
      - DUCK_DNS_TOKEN="<your Duck DNS API token>"

      # (Optional) The Let's Encrypt URL to use. 
      # Possible values are:
      #  For staging:    https://acme-staging-v02.api.letsencrypt.org/directory (default)
      #  For production: https://acme-v02.api.letsencrypt.org/directory         (beware rate limiting!)
      - CA_URL=https://acme-v02.api.letsencrypt.org/directory

      # (Optional) The number of days before expiry that a cert
      # should be refreshed. 
      # Default: 35
      #- RENEW_DAYS_BEFORE_EXPIRY=35

      # (Optional) The time to wait for DNS challenge to have propagated.
      # Default: 60
      #- DNS_CHALLENGE_PROPAGATION_TIME=180
    volumes:
      # Map the host's docker socket into the container
      # As a result the docker client in the container can
      # interact with the host's docker daemon, thus controlling
      # the host docker from within the container.
      - /var/run/docker.sock:/var/run/docker.sock
      # The user configurations of this docker image.
      - ./dehydrated/configurations:/dehydrated/configurations
      # The output folder where certificates will be stored.
      - ./dehydrated/certificates:/dehydrated/certificates
```

You need to specify your Duck DNS API token by setting the `DUCK_DNS_TOKEN` environment variable.

For production you should also set the `CA_URL` envrironment variable to point to https://acme-v02.api.letsencrypt.org/directory.
While trying to get things running, use the staging landscape which is not rate limited. The staging landscape is set by default if no `CA_URL` is specified.

You can teak the number of days before a certificate expires that decides when a certificate should be renwed.
Certificates that are valid for less than `RENEW_DAYS_BEFORE_EXPIRY` will be refreshed automatically. The default of 35 days works well and is adjusted to the monthly refresh-check. There should be little reason to change this value. If you do, make sure your refresh check cycle fits accordingly.

You can set the `DNS_CHALLENGE_PROPAGATION_TIME` in seconds. This time defines how long the this image will wait before calling the Let's Encrypt APIs to verify the delivered challenge response. Since Duck DNS sometimes takes a while to add and propagate challenge tokens to DNS records, you can adjust the time to wait for it to be done here. Typically 180 seconds should be enough. The default is 60 seconds.

The `volumes` map defines three mappings:
1. Mapping the Docker socket of the host into the container, so that the internal Docker client can interact with it.
2. Mapping the `configurations` folder containing the user settings, i.e. `domains.txt` and `restart-containers.sh`
3. Mapping the `certificates` folder where downloaded certificates will be stored.

Note that you can point other applications (e.g. running in docker containers on the Docker host) to the `certificates` folder. This image will refresh the certificates in a timely manner and thus your applications should have working certificates at any point in time.

### User Configurations

In the `docker-compose.yaml` make sure to specify at least the following:

1. `DUCK_DNS_TOKEN` - the Duck DNS API token.
2. `CA_URL` - the Let's Encrypt landscape to be used in production. (i.e. https://acme-v02.api.letsencrypt.org/directory)

For more information see [Using Docker-Compose](#using-docker-compose).

In your local `configurations` folder you should place at least the following files.

1. `domains.text`
2. `restart-containers.sh`

The `domains.txt` file must contain the Duck DNS domains for which certificates shall be fetched. For example, the file could look as follows:

```
mydomain.duckdns.org
```

For more complex examples see [Dehydrated Domains.txt Reference](https://github.com/dehydrated-io/dehydrated/blob/master/docs/domains_txt.md).

The `restart-containers.sh` script can be equally simple. For example the following file would restart two containers on the Docker host named `homeassistant` and `portainer`:

```shell
#!/bin/bash

echo "Restarting Containers:"
echo "-- homeassistant"
echo "-- portainer"

docker container restart homeassistant portainer
```

That's all you have to provide as configurations. The rest will be taken care of by this image internally.

### Starting a Container

To start the container, execute:

```bash
docker-compose up # add -d, if you want to run it in the background.
```

This will start the container amd immediately registers with Let's Encrypt to fetch certificates and start a cron job to renew them.
You can verify it using:

```bash
docker logs -f cert-updater
```

As a result you should see something like this:

```bash
Registering with Let's Encrypt
# INFO: Using main config file /letsencrypt/configuration/config
+ Generating account key...
+ Registering account key with ACME server...
+ Fetching account URL...
+ Done!
# INFO: Using main config file /letsencrypt/configuration/config
Started up successfully
 + Creating chain cache directory /letsencrypt/configuration/chains
Processing somedomain.duckdns.org
 + Creating new directory /letsencrypt/certs/somedomain.duckdns.org ...
 + Signing domains...
 + Generating private key...
 + Generating signing request...
 + Requesting new certificate order from CA...
 + Received 1 authorizations URLs from the CA
 + Handling authorization for somedomain.duckdns.org
 + 1 pending challenge(s)
 + Deploying challenge tokens...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100     2    0     2    0     0      1      0 --:--:--  0:00:01 --:--:--     1
OK
 + Responding to challenge for somedomain.duckdns.org authorization...
 + Challenge is valid!
 + Cleaning challenge tokens...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100     2    0     2    0     0      1      0 --:--:--  0:00:01 --:--:--     1
OK
 + Requesting certificate...
 + Checking certificate...
 + Done!
 + Creating fullchain.pem...
Certificates download succeeded.
Restarting Home Assistant container.
hass
Exited successfully.
crond: crond (busybox 1.31.1) started, log level 8
```

## Troubleshooting

In case of problems when fetching certificates proceed as follows:

1. Log into the running `cert-updater` container and unregister from Let's Encrypt:
   ```bash
      docker exec -it cert-updater /bin/bash
      $bash%>  /dehydrated/scripts/unregister.sh
   ```

2. Delete any remaining `accounts` and `chains` folders:
   ```bash
      docker exec -it cert-updater /bin/bash
      $bash%>  /dehydrated/scripts/remove-accounts-and-chains-cache.sh
   ```

3. Stop and remove the cert-updater container:
   ```bash
      docker-compose down
      # if still necessary do also this:
      docker container rm cert-updater 
   ```
4. Delete local certificates folder:
   ```bash
      sudo rm -rf ./certificates
   ```
5. Start cert-updater container again:
   ```bash
      docker-compose up -d
      docker logs -f cert-updater # to see the container boot up.
   ```

This should register with Let's Encrypt again and fetch new certificates. It then should also restart the containers given in `restart-containers.sh`.

## Appendix A: Technical Setup

### Contents

The image contains the following components:

* A Docker client
* [dehydrated](https://github.com/dehydrated-io/dehydrated/tree/master) script acting as a Let's Encrypt client.
* `cron`, `bash`, `openssl`, `curl`

The image is based on [pi-docker-client-image](https://github.com/FWinkler79-Raspberry-Pi-Projects/pi-docker-client-image) ([image on Docker Hub](https://github.com/FWinkler79-Raspberry-Pi-Projects/pi-docker-client-image)). This image is a plain Alpine Linux image with a Docker client installed, so that from a docker container the Docker host can be controlled. This allows us to restart Docker containers from within this image that are running outside of it on the Docker host. This comes in handy when containers referencing certificates fetched by this image need to be restarted when the certificates were refreshed.

### Image File Structure 

The files that were added (apart from the installed tools listed above) are:

```bash
/dehydrated
  |- dehydrated                         # The dehydrated script acting as Let's Encrypt client.
  |- config                             # The dehydrated (internal) configurations. See also: https://github.com/dehydrated-io/dehydrated/blob/master/docs/examples/config
  |- certificates/                      # Folder where fetched certificates will be stored. Map this to a local folder.
  |- configurations/                    # Contains the (public) user configurations.  
      |- domains.txt                    # This is where the domains are specified for which certs shall be fetched.
      |- restart-containers.sh          # A script that will be executed once certificates have been fetched. Can be used to restart docker containers on Docker host.
/scripts
  |- run.sh                              # The run script used as entry `CMD` of the Docker image. Calls fetch-and-update-certificates.sh and adds it as a CRON job.
  |- fetch-and-update-certificates.sh    # The main script called by run.sh. Calls all other scripts to register, fetch, unregsiter.
  |- register-with-letsencrypt.sh        # Uses the dehydrated script to create an account at Let's Encrypt.
  |- request-certificates.sh             # Requests the certificates from Let's Encrypt.
  |- hook.sh                             # Contains callbacks called by dehydrated during certificate fetch requests. Handles challenges from Let's Encrypt.
  |- set-permissions.sh                  # Changes permissions of the certificate folder so that read-only access is possible. By default only root has access, which is too restrictive.
  |- unregister.sh                       # Unregisters the active account from Let's Encrypt.
  |- remove-accounts-and-chains-cache.sh # Cleanup script removing any remains of previous Let's Encrypt accounts.
```

### Docker File

The `Dockerfile` is relatively simple:

```Dockerfile
# Base image providing the docker client
FROM fwinkler79/arm64v8-docker-client:1.0.0

# Installing dependencies
RUN apk update      \
    && apk upgrade  \
    && apk add curl \
    && apk add bash \
    && apk add openssl \
    && rm -rf /var/cache/apk/*

# Copying required files
COPY ./dehydrated /dehydrated

# The Duck DNS API token to use for API calls.
# You need to set this to your Duck DNS token as 
# it will be used in calls to Duck DNS REST API.
ENV DUCK_DNS_TOKEN="unspecified"

# The Let's Encrypt API URL to be used.
# Options are: 
# - Staging:    "https://acme-staging-v02.api.letsencrypt.org/directory"
# - Production: "https://acme-v02.api.letsencrypt.org/directory"
ENV CA_URL=https://acme-staging-v02.api.letsencrypt.org/directory

# Number of days before expiry that 
# certificates should be refreshed.
ENV RENEW_DAYS_BEFORE_EXPIRY=35

# Seconds to wait for the DNS challenge 
# to have propagated.
ENV DNS_CHALLENGE_PROPAGATION_TIME=60

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/dehydrated/scripts/run.sh"]
```

Note that the `CA_URL` can point to a staging or production environment. The production environment is rate-limited.
Firing too many requests at it will get you blocked for 2 days. Make sure to your staging whenever you are trying to get things working.

Also note that you need to provide your Duck DNS API token. The `hook.sh` script calls the Duck DNS API to position the challenge in the DNS records.

### Scripts Explained

#### run.sh

```shell
#!/bin/bash

# Fetch certificates by registering, downloading and un-registering.
/dehydrated/scripts/fetch-and-update-certificates.sh

# Finally, create a CRON tab that renews the certs every 1st day of every month.
echo "Creating a CRON tab to renew certificates every 1st day of every month."
echo "0 1 1 * * /dehydrated/scripts/fetch-and-update-certificates.sh" > /etc/crontabs/root
echo

# Excute the CRON daemon in background (-b) to check logs (-d = stderr, 8 = Error, 0 = verbose)
echo "Starting CRON daemon."
crond -f -d 8
```

Triggers the entire process of fetching and updating certificates and registers it as a CRON job for regulare updates.

#### fetch-and-update-certificates.sh

```shell
#!/bin/bash

# Register with Let's Encrypt.
/dehydrated/scripts/register-with-letsencrypt.sh

# After registration, request certificates.
/dehydrated/scripts/request-certificates.sh

# Unregister from Let's Encrypt.
/dehydrated/scripts/unregister.sh

# Remove any remains of accounts.
/dehydrated/scripts/remove-accounts-and-chains-cache.sh
```

Executes the entire process of fetching and updating certificates. Starts by registering with Let's Encrypt, followed by requesting certificates. This will result in a challenge from Let's Encrypt which is then handled by calling Duck DNS APIs to add the challenge to the DNS records (see also [hook.sh](#hooksh)). Once done, unregisters from Let's Encrypt and removes any remains of the account information to not keep any lingering state.

#### register-with-letsencrypt.sh

```shell
#!/bin/bash
echo "Registering with Let's Encrypt."
/dehydrated/dehydrated --register --accept-terms --config /dehydrated/config
```

Uses the `dehydrated` script to register to Let's Encrypt. The internal `/dehydrated/config` file is used for configurations.

#### request-certificates.sh

```shell
#!/bin/bash
echo "Requesting certificates."
/dehydrated/dehydrated --cron --config /dehydrated/config --out /dehydrated/certificates
```

Uses the `dehydrated` script to retrieve or update certificates from Let's Encrypt. The internal `/dehydrated/config` file is used for configurations.
Donwloaded / refreshed certificates are stored in the `/dehydrated/certificates` folder.

##### hook.sh

The `hook.sh` script is a script with callback functions triggered in the lifecycle of the certificate retrieval of `dehydrated`.
In the following the relevant callbacks will be described individually.

```shell
#!/usr/bin/env bash

deploy_challenge() {
  local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
  echo "Deploy Challenge called:"
  echo "-- Domain:                   $DOMAIN"
  echo "-- Duck DNS API Token:       $DUCK_DNS_TOKEN"
  echo "-- Challenge Response Token: $TOKEN_VALUE."
  echo 
  echo "Calling Duck DNS API to set DNS TXT Record containing challenge response token."
  echo "-- REST URL: 'https://www.duckdns.org/update?domains=$DOMAIN&token=$DUCK_DNS_TOKEN&txt=$TOKEN_VALUE'"
  echo 
  curl "https://www.duckdns.org/update?domains=$DOMAIN&token=$DUCK_DNS_TOKEN&txt=$TOKEN_VALUE"
  echo 
  echo "Challenge response token deployed to DNS TXT Records."
  echo "Waiting $DNS_CHALLENGE_PROPAGATION_TIME seconds for DNS-based challenge to propagate."
  sleep $DNS_CHALLENGE_PROPAGATION_TIME
  echo
}
```

The `deploy_challenge` function is called when Let's Encrypt responded with a challenge token. The function calls the Duck DNS REST API to deploy the challenge as DNS record `TXT` entries (see `CHALLENGETYPE="dns-01"` in [config](dehydrated/config)). 

Note that the Duck DNS API Token is required here as well as the domain and challenge token value.

```shell
clean_challenge() {
  local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
  echo "Clean Challenge called:"
  echo "-- Domain:                   $DOMAIN"
  echo "-- Duck DNS API Token:       $DUCK_DNS_TOKEN"
  echo "-- Challenge Response Token: $TOKEN_VALUE"
  echo
  echo "Calling Duck DNS API to clean DNS TXT record used for challenge response token."
  echo "-- REST URL: 'https://www.duckdns.org/update?domains=$DOMAIN&token=$DUCK_DNS_TOKEN&txt=$TOKEN_VALUE&clear=true'"
  echo
  curl "https://www.duckdns.org/update?domains=$DOMAIN&token=$DUCK_DNS_TOKEN&txt=$TOKEN_VALUE&clear=true"
  echo
}
```

The `clean_challenge` function is called, when the challenge was validates by Let's Encrypt and can be removed from the DNS records again.
Also this function call the Duck DNS REST APIs to remove the formerly added `TXT` enties from any future DNS records.

```shell
deploy_cert() {
  local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"
  echo "Successfully downloaded certificate:"
  echo " -- Domain:         $DOMAIN"
  echo " -- Key File:       $KEYFILE"
  echo " -- Cert File:      $CERTFILE"
  echo " -- Fullchain File: $FULLCHAINFILE"
  echo " -- Chain File:     $CHAINFILE"
  echo " -- Timestamp:      $TIMESTAMP"
  echo
  echo "Calling user script to set permissions."
  /dehydrated/scripts/set-permissions.sh
  echo
  echo "Calling user script to restarting docker containers."
  /dehydrated/configurations/restart-containers.sh
  echo
}
```

The `deploy_cert` function is called whenever certificates have been successfully downloaded. As a result the function will adjust the permissions to be read-only for everyone and thus lowers the very restrictive access rights that come with `dehydrated` defaults (i.e. root-only).
After setting permissions, it calls the `restart-containers.sh` script responsible for restaring containers on Docker host.

```shell
unchanged_cert() {
  local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"
  echo "Certificate unchanged:"
  echo " -- Domain:         $DOMAIN"
  echo " -- Key File:       $KEYFILE"
  echo " -- Cert File:      $CERTFILE"
  echo " -- Fullchain File: $FULLCHAINFILE"
  echo " -- Chain File:     $CHAINFILE"
  echo "Nothing to be done!"
}
```

The `unchanged_cert` function is called whenever `dehydrated` detects that a certificate is still valid and therefore does not have to be changed. Output is of informational nature only and for debugging purposes.

## Appendix B: Building the image

You can build this image on your Ma using Docker's cross-architecture build feature:

```bash
# Listing existing docker buildx builders. You can see which architectures are supported.
docker buildx ls

# Create docker buildx builder named 'raspibuilder'
docker buildx create --name raspibuilder

# Use 'raspibuilder' for docker buildx
docker buildx use raspibuilder

# Cross-building Docker image for Raspi
docker buildx build --platform linux/arm64 -t <docker-user-name>/<image-name>:<version> --push .
```

This builds an image for Raspberry Pi and pushes it to the Docker Hub repository you specify.

See [Cross-Building Docker Images](https://fwinkler79.github.io/blog/2021/01/04/cross-building-docker-images.html) for details.

## Appendix C: Advanced Usage

You can call all the scripts (including the dehydrated script itself) from the docker container as well.

If the container is not running yet, you can for example use the following command to register manually:

```bash
docker run -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /dehydrated/scripts/register.sh
```

If you already have a running container, you can use:

```bash
docker exec -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /dehydrated/scripts/register.sh
```

To run a bash, call:

```bash
docker exec -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /bin/bash
```

To run the dehydrated script yourself, run:

```bash
# For help
docker run -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /dehydrated/dehydrated --help

# To register to Let's Encrypt
docker run -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /dehydrated/dehydrated --register --accept-terms --config /dehydrated/config

# To request certificates
docker run -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /dehydrated/dehydrated --cron --config /dehydrated/config --out /dehydrated/certificates
```

> ❗Note: The dehydrated script also allows to revoke certificates. In case you need that, you can run the script from this image directly. See [Dehdrated Usage](https://github.com/dehydrated-io/dehydrated/blob/master/README.md#usage) for more details.

## References

**Duck DNS and Let's Encrypt** 
* [Duck DNS](https://www.duckdns.org)
* [Let's Encrypt](https://letsencrypt.org/)
* [Effortless Encryption with Let's Encrypt and DuckDNS](https://www.home-assistant.io/blog/2017/09/27/effortless-encryption-with-lets-encrypt-and-duckdns/)

**Dehydrated**
* [Dehydrated](https://github.com/dehydrated-io/dehydrated/blob/master/README.md)
* [Dehdrated Usage](https://github.com/dehydrated-io/dehydrated/blob/master/README.md#usage)
* [Dehydrated Domains.txt Reference](https://github.com/dehydrated-io/dehydrated/blob/master/docs/domains_txt.md)
* [Dehydrated Examples](https://github.com/dehydrated-io/dehydrated/tree/master/docs/examples)
* [Dehydrated Docs](https://github.com/dehydrated-io/dehydrated/tree/master/docs)

**Docker Cross-Building Images**
* [Cross-Building Docker Images](https://fwinkler79.github.io/blog/cross-building-docker-images.html)
* [Docker Multi-Arch Builds and Cross Builds](https://docs.docker.com/docker-for-mac/multi-arch/)
* [arm32v7 Docker Images](https://hub.docker.com/u/arm32v7)
* [arm64v8 Docker Images](https://hub.docker.com/u/arm64v8)
* [Docker Official Images](https://github.com/docker-library/official-images?tab=readme-ov-file#architectures-other-than-amd64)
* [Docker Official Alpine arm64v8 Image](https://hub.docker.com/r/arm64v8/alpine)
* [Alpine Official arm64v8 image](https://hub.docker.com/layers/library/alpine/latest/images/sha256-cf7e6d447a6bdf4d1ab120c418c7fd9bdbb9c4e838554fda3ed988592ba02936)

**Miscellaneous**
* [Alpine docker client](https://github.com/Cethy/alpine-docker-client)
* [Docker Dehydrated](https://github.com/matrix-org/docker-dehydrated)
* [Installing TLS/SSL using Let's Encrypt](https://community.home-assistant.io/t/installing-tls-ssl-using-lets-encrypt/196975)
* [Hass, DuckDNS and Let's Encrypt](https://www.splitbrain.org/blog/2017-08/10-homeassistant_duckdns_letsencrypt)
* [Simple Let's Encrypt on Debian](https://www.splitbrain.org/blog/2016-05/14-simple_letsencrypt_on_debian_apache)


