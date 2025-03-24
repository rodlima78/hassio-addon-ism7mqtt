ARG BUILD_FROM

FROM ghcr.io/rodlima78/ism7mqtt/ism7mqtt:v0.0.17 AS ism

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



