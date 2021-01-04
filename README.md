# pi-dehydrated-letsencrypt-updater

A Docker image for Raspberry Pi including the following components:

* docker client
* [dehydrated / let's encrypt script](https://github.com/dehydrated-io/dehydrated)
* cron

The image can be used to fetch certificates for a specific domain from Let's Encrypt and keep them up to date.

Using the docker client inside this image you can fetch new certificates (Let's Encrypt certs expire after 90 days) and restart docker containers that depend on those certificates on the docker host.

The respository also comes with a Docker-Compose file making it easy to start the image.

# Building

You can build this image on your Ma using Docker's cross-architecture build feature:

```bash
# Listing existing docker buildx builders. You can see which architectures are supported.
docker buildx ls

# Create docker buildx builder named 'raspibuilder'
docker buildx create --name raspibuilder

# Use 'raspibuilder' for docker buildx
docker buildx use raspibuilder

# Cross-building Docker image for Raspi
docker buildx build --platform linux/arm/v7 -t <docker-user-name>/<image-name>:<version> --push .
```

This builds an image for Raspberry Pi and pushes it to the Docker Hub repository you specify.

# Usage

This repo contains a `docker-compose.yml` file which you can use as a base for starting your own image.
By default it will start the image that was built by the author of this repository.

```bash
docker-compose up
```

❗Note: The `docker-compose.yml` maps the `/var/run/docker.sock` into the container. This is necessary to allow the docker client inside the container to interface with the Docker daemon on the host machine. Should your `docker.sock` reside somewhere other than this default, make sure to adjust your `docker-compose.yml` file.