#!/bin/bash

set -euxm

shutdown() {
    echo "Shutting down..." >&2
    kill -9 0 2>/dev/null || true
    exit 0
}

trap shutdown SIGINT SIGTERM

# start mediasrv
/usr/trim/bin/mediasrv -o /usr/trim/logs/mediasrv.log -a /var/run/mediasrv.socket &
pid1=$!

# start rpcbroker
/usr/trim/bin/rpcbroker -u ${USER_NAME} -f ${MEDIA_DIRS} &
pid2=$!

# init database
if [ ! -f /vol1/@appdata/trim.media/database/trimmedia.db ]; then
  # make sure folder exists
  mkdir -p /vol1/@appdata/trim.media/database
  sed "s/___USER_NAME___/${USER_NAME}/g" /var/apps/trim.media/media.sql | sqlite3 /vol1/@appdata/trim.media/database/trimmedia.db
fi

# change owner
chown -R ${PUID}:${GUID} ${MEDIA_DIRS}

# start trim-media
/var/apps/trim.media/target/trim-media --port=8005 \
  --root=/vol1/@appdata/trim.media \
  --meta=/vol1/@appmeta/trim.media \
  --static=/var/apps/trim.media/target \
  --trim-appname=trim.media \
  --trim-username=trim-media \
  --log-dir=/var/apps/trim.media/logs \
  --log-level=${LOG_LEVEL} &
pid3=$!

tail -vF /var/apps/trim.media/logs/trim-media.log &
wait -n $pid1 $pid2 $pid3

exit_code=$?

echo "One of the apps exited with code $" >&2

kill -9 0

exit $exit_code

