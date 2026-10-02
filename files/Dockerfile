FROM debian:bookworm

ARG TARGETARCH

ENV LD_LIBRARY_PATH=/usr/trim/lib/mediasrv \
    LOG_LEVEL=info \
    MEDIA_DIRS=/vol1/1000/media \
    USER_NAME=admin \
    PUID=1000 \
    GUID=1000

RUN apt update && \
    apt install -y --no-install-recommends \
        sqlite3 openssl ca-certificates \
        libass9 libbluray2 libmp3lame0 libopenmpt0 libopus0 \
        libtcmalloc-minimal4 libtheora0 libvorbisenc2 libvpx7 \
        libwebp7 libwebpmux3 libx264-164 libx265-199 libzvbi0 \
        libpci3 libjemalloc2 ocl-icd-libopencl1 libdrm2 \
        libva2 libva-drm2 clinfo && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

ADD ./mediasrv-${TARGETARCH}.tgz /usr/trim/
ADD ./trim.media-${TARGETARCH}.tgz /var/apps/trim.media/

VOLUME ["/vol1/1000/media", "/vol1/@appdata/trim.media", "/vol1/@appmeta/trim.media"]

WORKDIR /var/apps/trim.media

EXPOSE 8005

ENTRYPOINT ["/var/apps/trim.media/start.sh"]

CMD []
