FROM debian:12.15

ENV LD_LIBRARY_PATH=/usr/trim/lib/mediasrv LOG_LEVEL=info MEDIA_DIRS=/vol1/1000/media USER_NAME=admin

ADD ./mediasrv.tgz /usr/trim/
ADD ./trim.media-app.tgz /usr/local/apps/@appcenter/trim.media/
ADD ./trim.media-var.tgz /var/apps/trim.media/

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
  apt update && apt install -y sqlite3 openssl ca-certificates libass9 libbluray2 libmp3lame0 \
  libopenmpt0 libopus0 libtcmalloc-minimal4 libtheora0 libvorbisenc2 libvpx7 libwebp7 \
  libwebpmux3 libx264-164 libx265-199 libzvbi0 libjemalloc2 ocl-icd-libopencl1 intel-opencl-icd clinfo && \
  apt clean && rm -rf /var/lib/apt/lists/*

VOLUME ["/vol1/1000/media", "/vol1/mediadata", "/vol1/@appmeta/trim.media"]

WORKDIR /usr/trim

EXPOSE 8005

ENTRYPOINT ["/bin/bash"]

CMD ["/usr/trim/entrypoint.sh"]
