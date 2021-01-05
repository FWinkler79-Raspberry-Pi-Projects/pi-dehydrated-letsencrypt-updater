#!/bin/bash
docker buildx create --name raspibuilder
docker buildx use raspibuilder
docker buildx build --platform linux/arm/v7,linux/x86_64 -t fwinkler79/arm32v7-dehydrated-letsencrypt-updater:1.0.0 --push .