# pi-dehydrated-letsencrypt-updater

- [❗ WARNING - Updating `dehydrated` Script ❗](#-warning---updating-dehydrated-script-)
- [Contents](#contents)
- [How it works](#how-it-works)
- [Building the image](#building-the-image)
- [Image File Structure](#image-file-structure)
- [Usage](#usage)
  - [Configuration](#configuration)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## ❗ WARNING - Updating `dehydrated` Script ❗

Every now and then you might want to update the [dehydrated](https://github.com/dehydrated-io/dehydrated) script which acts as the certificate client for Letsencrypt. You can download the file from the link and place it in the [`letsencrypt`](letsencrypt/) folder.

❗ IMPORTANT: you need to adjust the script's `umask 077` to something less restrictive. We usually use: `umask 000` (read and execute permissions)

See also this description about `umask` permissions: https://en.wikipedia.org/wiki/Umask

If you fail to do that, the certificates will be stored in files and folders only accessible to `root`.
Home Assistant and Portainer will then not have access unless they are run in `root` mode (`PUID=0`, `PGID=0`).
That should be avoided, however, as an attacker that found a way into Home Assistant or Portainer could then gain full `root` access.


## Contents

A Docker image for Raspberry Pi to 

* register a certificate account with Let's Encrypt 
* download signed certificates for your [Duck DNS](https://www.duckdns.org) domain(s)
* automatically refresh certificates for your domain
* (optional) with custom hooks to trigger actions after certificates were refreshed

By default this image uses the `dns-01` challenge method with Let's Encrypt, which makes it possible to retrieve certificates from Let's Encrypt without having to provide specific Web endpoints for challenge callbacks.
Instead, DNS TXT records are manipulated and used to prove to Let's Encrypt that you are the owner of your domain.

The image contains the following components:

* a docker client
* the [dehydrated / let's encrypt script](https://github.com/dehydrated-io/dehydrated) doing most of the magic
* cron, bash, openssl, curl (needed by dehydrated)

I use this image to:

* fetch my initial certificates for my Duck DNS domain
* export them to a local folder on my docker host (via a volume mapping)
* automatically refresh them before they expire (using cron installed in the image)
* restart another container running a server that reads the certificates from the local folder on my docker host.

By doing so, I can run my server and automatically update its SSL certificates when they expire (happens every 90 days with Let's Encrypt certificates). That keeps the server certs always valid with zero manual intervention.

The respository also comes with a Docker-Compose file making it easy to start the image, and showing how I used it.

## How it works

The working model of this image was greatly inspired by the excellent blog post on [Hass, DuckDNS and Let's Encrypt](https://www.splitbrain.org/blog/2017-08/10-homeassistant_duckdns_letsencrypt) from the Home Assistant community. Make sure you read and understand it, since you will find pieces of it (both concepts and software) in this image.

In essence it is is like this:

* First you need a domain, i.e. a textual URL representation of your server's public IP address.
  You will want one anyway if your server is on the public internet, because typing IP addresses (especially IPv6 ones 😉) is tedious and they also tend to change. You can get a free domain within seconds from [Duck DNS](https://www.duckdns.org), a Domain Name System (DNS) provider.
* To get an SSL certificate for your server that is accepted by browsers like Chrome or Safari, you need one from a trusted certificate signing authority (CA). 
  Most charge money for signing your certificates, but luckily [Let's Encrypt](https://letsencrypt.org/) is for free. So that's what we use.
* By creating and signing your certificates, Let's Encrypt effectively vouches for you not being a malicious scumbag that tries to rip other people off. They therefore need a proof that domain or server that your certificate is created for is under your control.  
  Note, you could still be a scumbag, but as long as you have your own domain under control and not trying to impersonate someone else's that's fine for Let's Encrypt... 😉
* So when you ask Let's Encrypt for a certificate, you need to specify which domain it is intended for. There you specify your DuckDNS domain. You might specify a few more things you want to show up in the cert, e.g. your email, etc. In return Let's Encrypt will send you a challenge. That could either be "Place a file at the .well-known/acme endpoint on your web server and fill it with this code I give you" or "Go create a DNS TXT record in your DNS server, that contains that text I send you.". 
* You decide for one option or the other and do as you are told. Let's Encrypt will then either try to download the file and check the code or do a DNS lookup of your domain, retrieving the TXT record and checking for the contents. If the values are correct, Let's Encrypt assumes that you are in control of the server and / or domain you want the certificate for.

All of that happens automatically - no human intervention included - and in this setup we use the DNS TXT record approach, since it does not force us to expose anything on a server (that we might not even be able to control) or open any extra ports.
In return we need a DNS provider that provides an API to add and modify TXT records to DNS probes for our domain. Luckily DuckDNS has a REST API that does just that!

The [dehydrated](https://github.com/dehydrated-io/dehydrated) script does all the communication with Let's Encrypt and provides enough configuration options to let us register, select the type of challenge (`http-01` or `dns-01`) and fetch certificates. Additionally it allows us to define hooks that will be called when a challenge is received from Let's Encrypt or when the certificates were fetched / updated. 

With a simple hook that is included in this image and inspired by work done [here](https://www.splitbrain.org/blog/2017-08/10-homeassistant_duckdns_letsencrypt) we are able to fulfill the DNS TXT record challenge and prove to Let's Encrypt that we are who we claim to be ... well, or at least that we (as opposed to some attacker) control the domain the certificate is for.

That's all there is to it. It is surprisingly easy, once you wrapped your head around it.

Now let's get started.

## Building the image

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

## Image File Structure

The image is based on my [docker-client image](https://github.com/FWinkler79-Raspberry-Pi-Projects/pi-docker-client-image), which is based on alpine.

The files that were added (apart from the installed tools listed above) are:

```bash
/letsencrypt
  |- certs/           # The fetched certificates will be stored here. Make sure to map this to a local folder using a docker volume bind.
  |- configuration/   # Contains the configuration files read by the dehydrated script.
      |- config       # dehydrated configurations. See: https://github.com/dehydrated-io/dehydrated/blob/master/docs/examples/config
      |- domains.txt  # This is where you specify your domain. Make sure you have created on at DuckDNS.
      |- hook.sh      # This is a hook that deals with Let's Encrypt challenges and can be extended by you to trigger actions after fetch.
  |- dehydrated       # The dehydrated script.

/scripts
  |- register.sh      # Uses the dehydrated script to register to Let's Encrypt.
  |- fetch-certs.sh   # Uses the dehydrated script to fetch certs from Let's Encrypt.
  |- run.sh           # Calls register, then fetch and then creates a cron job that periodically fetches new certificates.
  |- unregister.sh    # Unregisters the active account from Let's Encrypt.
```

You should map the `/letsencrypt/certs` and `/letsencrypt/configuration` folders to local folders on your docker host.
In the `certs` folder the fetched certificates will be stored, and you are likely to use them somewhere else.
The `configurations` need to be adjusted to your specific domain and DuckDNS credentials.

See [Usage](#usage) section below.

## Usage

You can use the image with plain `docker`, but it is recommended to use `docker-compose`, since it simplifies usage a lot.

The following docker-compose file shows how the image can / should be used:

```bash
version: "3.7"
services:
  cert-updater:
    image: fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0
    container_name: cert-updater
    volumes:
      # Map the host's docker socket into the container
      # As a result the docker client in the container can
      # interact with the host's docker daemon, thus controlling
      # the host docker from within the container.
      - /var/run/docker.sock:/var/run/docker.sock
      # The configurations of the dehydrated script.
      # Place the following files here:
      # * domains.txt - containing your DNS domain from DuckDNS.
      # * config      - specify the configurations for dehydrated script
      # * hook.sh     - the hook script implementing what should be done when the certs were fetched.
      # Make sure the hook script is executable.
      - ./config:/letsencrypt/configuration
      # Map the folder where the certificates will be stored.
      - ./certs:/letsencrypt/certs
```
This maps the `certs` folder inside the container to the local `./certs` folder.
It also maps the `configuration` folder inside the container to the local `./config` folder.

Additionally, it maps the local docker socket inside the container, so you can use the docker client inside the container to control the docker host's docker daemon. This s optional, but can be handy, if you need to restart _another_ docker container once the certificates were fetched / renewed.

Place the proper configurations into the `./config` folder (see below) and you are ready to start the container using:

```bash
docker-compose up # add -d, if you want to run it in the background.
```

This will start the container which immediately will register with Let's Encrypt, fetch certificates and start a cron job to renew them.
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
### Configuration

In the local `./config` folder you should place at least the following files.

All those files are required by the [dehydrated](https://github.com/dehydrated-io/dehydrated) script and are best described by its author and this blog on [Hass, DuckDNS and Let's Encrypt](https://www.splitbrain.org/blog/2017-08/10-homeassistant_duckdns_letsencrypt).

#### The `config` file:

```bash
# For testing / development use the staging endpoint of let's encrypt.
# See also: https://github.com/dehydrated-io/dehydrated/blob/master/docs/staging.md
# Comment the line below for production
CA="https://acme-staging-v02.api.letsencrypt.org/directory"

# Which challenge should be used? Currently http-01 and dns-01 are supported
# dns-01 means: Let's encrypt will send a challenge with a text that it wants
# us to put into a TXT record of the DNS response for our domain.
# The hook script below will do that by calling an API of DuckDNS where our
# domain is registered. DuckDNS will add the challenge text to the TXT DNS 
# record and when Let's Encrypt does a DNS lookup (dig <domain> TXT) it will find
# the challenge text their and believe us that we are in control of the domain.
# Then it will issue a certificate for us.
CHALLENGETYPE="dns-01"

# Script to execute the DNS challenge and run after cert generation.
# The script calls a REST API of DuckDNS to add a challenge text from 
# Let's encrypt to the TXT records for our DNS domain. Let's encrypt will
# check that TXT record to check if we are in control of our domain.
# Only then will Let's Encypt issue a certificate.
HOOK="/letsencrypt/configuration/hook.sh"

# Location of the domains.txt file.
DOMAINS_TXT="/letsencrypt/configuration/domains.txt" 
```
❗ Here you only need to change the first line normally. Especially, if you are playing around, you should avoid firing too many requests at the production Let's Encrypt endpoint. Otherwise you will suffer from rate limiting. Let's Encrypt provides a staging area, which you can call as often as you want, and which can be used for testing. It vends only fake certificates, of course.

If you comment out the first line, you will be using the production endpoint, giving your real certificates - but beware of the rate limit!

#### The `domains.txt` file:

```bash
<your Duck DNS domain here>
```
❗ Here you need to specify your Duck DNS domain that you want to get signed SSL certificates for.

#### The `hook.sh` file:

```bash
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
        echo "Certificates download succeeded."       # your certificate post-deploy hook goes here!
        echo "Restarting Home Assistant container."   # in this sample we are restarting another container that will read the certs.
        docker container restart hass                 # restarting `hass` container on docker host from within this container!
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
        ;;
esac
```
❗ Note that here you **need to enter your DuckDNS domain and token**. Optionally, you can also add one or more hooks.

## Advanced Usage

You can call all the scripts (including the dehydrated script itself) from the docker container as well.

If the container is not running yet, you can for example use the following command to register manually:

```bash
docker run -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /letsencrypt/scripts/register.sh
```

If you already have a running container, you can use:

```bash
docker exec -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /letsencrypt/scripts/register.sh
```

To run a bash, call:

```bash
docker exec -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /bin/bash
```

To run the dehydrated script yourself, run:

```bash
docker run -it fwinkler79/arm64v8-dehydrated-letsencrypt-updater:1.0.0 /letsencrypt/dehydrated --register --accept-terms --config /letsencrypt/configuration/config
```

❗Note: The dehydrated script also allows to revoke certificates. In case you need that, you can run the script from this image directly.

## Troubleshooting

In case of trouble with the certificate fetch, proceed as follows:

1. Log into the running `cert-updater` container and unregister from Let's Encrypt:
   ```bash
   docker exec -it cert-updater /bin/bash
   $bash%>  /scripts/unregister.sh
   ```
2. Stop the cert-updater container:
   ```bash
   docker-compose down
   # if still necessary do also this:
   docker container rm cert-updater 
   ```
3. Delete local certs:
   ```bash
   sudo rm -rf ./certs/<your domain>
   ```
4. Start cert-updater container again:
   ```bash
   docker-compose up -d
   docker logs -f cert-updater # to see the container boot up.
   ```

This should re-register with Let's Encrypt and re-fetch new certificates. It then should also restart `hass`.

## References

* [Duck DNS](https://www.duckdns.org)
* [Let's Encrypt](https://letsencrypt.org/)
* [dehydrated](https://github.com/dehydrated-io/dehydrated)
* [Alpine docker client](https://github.com/Cethy/alpine-docker-client)
* [Docker Dehydrated](https://github.com/matrix-org/docker-dehydrated)
* [Installing TLS/SSL using Let's Encrypt](https://community.home-assistant.io/t/installing-tls-ssl-using-lets-encrypt/196975)
* [Effortless Encryption with Let's Encrypt and DuckDNS](https://www.home-assistant.io/blog/2017/09/27/effortless-encryption-with-lets-encrypt-and-duckdns/)
* [Hass, DuckDNS and Let's Encrypt](https://www.splitbrain.org/blog/2017-08/10-homeassistant_duckdns_letsencrypt)
* [Simple Let's Encrypt on Debian](https://www.splitbrain.org/blog/2016-05/14-simple_letsencrypt_on_debian_apache)

**Docker Cross-Building Images**
* [Cross-Building Docker Images](https://fwinkler79.github.io/blog/cross-building-docker-images.html)
* [Docker Multi-Arch Builds and Cross Builds](https://docs.docker.com/docker-for-mac/multi-arch/)
* [arm32v7 Docker Images](https://hub.docker.com/u/arm32v7)
* [arm64v8 Docker Images](https://hub.docker.com/u/arm64v8)
* [Docker Official Images](https://github.com/docker-library/official-images?tab=readme-ov-file#architectures-other-than-amd64)
* [Docker Official Alpine arm64v8 Image](https://hub.docker.com/r/arm64v8/alpine)
* [Alpine Official arm64v8 image](https://hub.docker.com/layers/library/alpine/latest/images/sha256-cf7e6d447a6bdf4d1ab120c418c7fd9bdbb9c4e838554fda3ed988592ba02936)

