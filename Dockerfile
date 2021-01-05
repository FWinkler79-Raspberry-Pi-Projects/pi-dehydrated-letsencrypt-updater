FROM fwinkler79/arm32v7-docker-client:1.0.0

RUN apk update      \
    && apk upgrade  \
    && apk add curl \
    && apk add bash \
    && apk add openssl \
    && rm -rf /var/cache/apk/*

COPY ./letsencrypt /letsencrypt
COPY ./scripts /scripts

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/scripts/run.sh"]
