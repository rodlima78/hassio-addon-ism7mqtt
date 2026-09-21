ARG BUILD_FROM=ghcr.io/home-assistant/base:3.24-2026.08.0

FROM ghcr.io/rodlima78/ism7mqtt/ism7mqtt:master AS ism

FROM $BUILD_FROM

COPY run.sh /
RUN \
    apk add \
        icu-libs \
        moreutils \
        mosquitto-clients \
    && chmod a+x /run.sh

COPY --from=ism /app /app/


CMD [ "/run.sh" ]



