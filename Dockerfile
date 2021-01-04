FROM fwinkler79/arm32v7-docker-client:1.0.0

ARG DOCKER_CLI_VERSION="20.10.1"
ENV DOWNLOAD_URL="https://download.docker.com/linux/static/stable/armhf/docker-$DOCKER_CLI_VERSION.tgz"

# install docker client
RUN apk --update add curl \
    && mkdir -p /tmp/download \
    && curl -L $DOWNLOAD_URL | tar -xz -C /tmp/download \
    && mv /tmp/download/docker/docker /usr/local/bin/ \
    && rm -rf /tmp/download \
    && apk del curl \
    && rm -rf /var/cache/apk/*

ENTRYPOINT ["docker"]
CMD ["-v"]
