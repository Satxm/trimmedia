FROM debian:bookworm

ENV LD_LIBRARY_PATH=/usr/trim/lib/mediasrv \
    LOG_LEVEL=info \
    MEDIA_DIRS=/vol1/1000/media \
    USER_NAME=admin \
    PUID=1000 \
    GUID=1000

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
    apt update && \
    apt install -y \
        sqlite3 openssl ca-certificates \
        libass9 libbluray2 libmp3lame0 libopenmpt0 libopus0 \
        libtcmalloc-minimal4 libtheora0 libvorbisenc2 libvpx7 \
        libwebp7 libpci3 libwebpmux3 libx264-164 libx265-199 \
        libzvbi0 libjemalloc2 ocl-icd-libopencl1 intel-opencl-icd \
        clinfo && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

ADD ./mediasrv.tgz /usr/trim/
ADD ./trim.media.tgz /var/apps/trim.media/

VOLUME ["/vol1/1000/media", "/vol1/@appdata/trim.media", "/vol1/@appmeta/trim.media"]

WORKDIR /var/apps/trim.media

EXPOSE 8005

ENTRYPOINT ["/var/apps/trim.media/start.sh"]

CMD []
