FROM fwinkler79/arm64v8-docker-client:1.0.0

RUN apk update      \
    && apk upgrade  \
    && apk add curl \
    && apk add bash \
    && apk add openssl \
    && rm -rf /var/cache/apk/*

COPY ./dehydrated /dehydrated

# The Duck DNS API token to use for API calls.
ENV DUCK_DNS_TOKEN="unspecified"
# The Let's Encrypt API URL to be used.
# Options are: 
# - Staging:    "https://acme-staging-v02.api.letsencrypt.org/directory"
# - Production: "https://acme-v02.api.letsencrypt.org/directory"
ENV CA_URL=https://acme-staging-v02.api.letsencrypt.org/directory
# Number of days before expiry that cert should be refreshed.
ENV RENEW_DAYS_BEFORE_EXPIRY=35
# Seconds to wait for the DNS challenge to have propagated.
ENV DNS_CHALLENGE_PROPAGATION_TIME=60

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/dehydrated/scripts/run.sh"]
