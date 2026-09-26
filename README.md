# 📦 trimmedia

## 📝 更新说明

2026.9.25❗**更新镜像时请替换容器路径**❗

修改容器内数据文件夹路径 `/vol1/mediadata` 为 `/vol1/@appdata/trim.media`；
支持指定 `PUID` `GUID` 以设定媒体文件夹所有者权限。

❗**更新镜像时请替换容器路径**❗

## 🚀 快速部署

### 使用 Docker 命令

```bash
docker run -d \
  -e PUID=$(id -u) \
  -e GUID=$(id -g) \
  -e USER_NAME=admin \
  --device /dev/dri:/dev/dri \
  -v /dev/dri/by-path:/dev/dri/by-path \
  -v <媒体文件夹>:/vol1/1000/media \
  -v <数据文件夹>:/vol1/@appdata/trim.media \
  -v <元信息文件夹>:/vol1/@appmeta/trim.media \
  --network host \
  --name trimmedia \
  ghcr.io/satxm/trimmedia:latest # ghcr.io
  # satxm/trimmedia:latest # docker hub
  # trimmedia:latest # localbuild
```
### 使用 Docker Compose

```docker-compose.yml
services:
  trimmedia:
    image: ghcr.io/satxm/trimmedia:latest # ghcr.io
    # image: satxm/trimmedia:latest # docker hub
    # image: trimmedia:latest # localbuild
    container_name: trimmedia
    restart: always
    environment:
      PUID=${PUID:-1000}
      GUID=${GUID:-1000}
      # USER_NAME=${USER_NAME:-admin}
    network_mode: host
    # 如果不使用 host 网络模式，请移除上行，并取消下方 ports 的注释
    # ports:
      # - '8005:8005'
    devices:
      - '/dev/dri:/dev/dri'
    volumes:
      - '<媒体文件夹>:/vol1/1000/media'
      - '<数据文件夹>:/vol1/@appdata/trim.media'
      - '<元信息文件夹>:/vol1/@appmeta/trim.media'
      - '/dev/dri/by-path:/dev/dri/by-path'
```

### 镜像

```
docker pull ghcr.io/satxm/trimmedia:latest # ghcr.io
docker pull satxm/trimmedia:latest # docker hub
```

## ⚙️ 配置说明

### 网络模式
- Host 模式（推荐）：使用 `--network host` 或 `network_mode: host`。
- - 优点：无需手动映射端口，容器直接使用宿主机网络，性能更好。
- - 注意：启用此模式后，不需要 再配置 `-p` 或 `ports`。

- 桥接模式：如果必须映射端口，请移除 `network` 配置，并取消 `ports` 的注释，格式为 `-p <宿主机端口>:8005`。

### 登录凭据

- 默认用户名：`admin`
- 默认密码：`123456`
- 修改用户名：可以通过环境变量 `USER_NAME` 进行修改，但默认密码保持不变。

### 硬件映射

- `--device /dev/dri:/dev/dri` : 显卡设备映射，将宿主机上的 `/dev/dri` 整个目录挂载到容器内的相同路径
- `-v /dev/dri/by-path:/dev/dri/by-path` : 必须映射，`by-path` 目录包含了通过系统总线路径（如 PCI 总线）链接到实际 DRI 设备的符号链接

## 🛠️ 镜像构建

如果你需要自行构建镜像，请按照以下步骤操作：

### 准备文件：

从已安装影视应用的飞牛系统中拷贝并打包以下文件：

- 创建临时文件夹 `mediasrv` ，并拷贝以下文件：

```bash
mkdir -p mediasrv/bin mediasrv/lib mediasrv/etc;
cp -rp /usr/trim/bin/mediasrv mediasrv/bin/;
cp -rp /usr/trim/lib/{mediasrv,libhwinfo.so,libhwinfo.so.0,libhwinfo.so.0.8,libigputop.so,libigputop.so.0,libigputop.so.0.7,libnebula.so,libppjson.so} mediasrv/lib/
mkdir trim.media
cp -rp /var/apps/trim.media/{cmd,config,i18n,wizard,ICON.PNG,ICON_256.PNG,manifest} trim.media/
cp -rp /usr/local/apps/@appcenter/trim.media trim.media/target
```

- 将 `entrypoint.sh` 和 `media.sql` 添加到 `trim.media` 文件夹，并赋予其可执行权限；

- 编译 `fakebroker.go` 到 `mediasrv/bin/rpcbroker`，并赋予其可执行权限；

```bash
curl -O https://dl.google.com/go/go1.26.8.linux-amd64.tar.gz && tar -xvf go1.26.8.linux-amd64.tar.gz && export PATH=$PWD/go/bin:$PATH
go env -w GOPROXY=https://goproxy.cn,direct
go env -w GOSUMDB=sum.golang.org
go mod init fakebroker
go get golang.org/x/sys/unix
go build -o mediasrv/bin/rpcbroker fakebroker.go
```

- 重新打包 `mediasrv.tgz` 和 `trim.media.tgz`。

```bash
tar -C mediasrv -czvf mediasrv.tgz .
tar -C trim.media -czvf trim.media.tgz .
```

### 执行构建：

将上述 tgz 压缩包及 `Dockerfile` 放在同一目录下，执行：

```bash
docker build --no-cache -t trimmedia .
```

## 参考来源
[飞牛影视独立化Docker镜像](https://www.nodeseek.com/post-604506-1) 需梯子

[docker中运行飞牛影视](https://qs100371.top/post/docker-zhong-yun-xing-fei-niu-ying-shi/)
