#!/bin/bash

set -euxm

shutdown() {
    echo "Shutting down..." >&2
    kill -9 0 2>/dev/null || true
    exit 0
}

trap shutdown SIGINT SIGTERM

# start mediasrv
/usr/trim/bin/mediasrv -o /var/log/mediasrv.log -a /var/run/mediasrv.socket &
pid1=$!

# start rpcbroker
/usr/trim/bin/rpcbroker -u ${USER_NAME} -f ${MEDIA_DIRS} &
pid2=$!

# init database
if [ ! -f /vol1/mediadata/database/trimmedia.db ]; then
  # make sure folder exists
  mkdir -p /vol1/mediadata/database
  sed "s/___USER_NAME___/${USER_NAME}/g" /usr/trim/init.sql | sqlite3 /vol1/mediadata/database/trimmedia.db
fi

cd /usr/local/apps/@appcenter/trim.media
/usr/local/apps/@appcenter/trim.media/trim-media --port=8005 \
  --static=/usr/local/apps/@appcenter/trim.media \
  --trim-appname=trim.media \
  --trim-username=trim-media \
  --root=/vol1/mediadata \
  --meta=/vol1/@appmeta/trim.media \
  --log-dir=/var/log --log-level=${LOG_LEVEL} &
pid3=$!

tail -vF /var/log/trim-media.log &

wait -n $pid1 $pid2 $pid3
exit_code=$?

echo "One of the apps exited with code $" >&2

kill -9 0

exit $exit_code

