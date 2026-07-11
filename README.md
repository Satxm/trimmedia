# 📦 trimmedia

## 🚀 快速部署

### 使用 Docker 命令

```bash
docker run -d \
  -e USER_NAME=admin \
  --device /dev/dri:/dev/dri \
  -v /dev/dri/by-path:/dev/dri/by-path \
  -v <媒体文件夹>:/vol1/1000/media \
  -v <数据文件夹>:/vol1/mediadata \
  -v <元信息文件夹>:/vol1/@appmeta/trim.media \
  --network_mode=host \
  --name trimmedia \
  trimmedia:latest
```
### 使用 Docker Compose

```docker-compose.yml
services:
  trimmedia:
    image: trimmedia:latest
    # 推荐使用完整镜像地址：ghcr.io/satxm/trimmedia:latest
    container_name: trimmedia
    restart: always
    # environment:
    #   USER_NAME: admin
    network_mode: host
    # 如果不使用 host 网络模式，请移除上行，取消下两行注释，修改端口号
    # ports:
    #   - '8005:8005'
    devices:
      - '/dev/dri:/dev/dri'
    volumes:
      - '<媒体文件夹>:/vol1/1000/media'
      - '<数据文件夹>:/vol1/mediadata'
      - '<元信息文件夹>:/vol1/@appmeta/trim.media'
      - '/dev/dri/by-path:/dev/dri/by-path'
```

## ⚙️ 配置说明

### 网络模式
- Host 模式（推荐）：使用 `--network_mode=host` 或 `network_mode: host`。
- - 优点：无需手动映射端口，容器直接使用宿主机网络，性能更好。
- - 注意：启用此模式后，不需要 再配置 `-p` 或 `ports`。

桥接模式：如果必须映射端口，请移除 `network_mode` 配置，并取消 `ports` 的注释，格式为 `-p <宿主机端口>:8005`。

### 登录凭据

- 默认用户名：`admin`
- 默认密码：`123456`
- 修改用户名：可以通过环境变量 `-e USER_NAME=<你的用户名>` 进行修改，但默认密码保持不变。

## 🛠️ 镜像构建

如果你需要自行构建镜像，请按照以下步骤操作：

### 准备文件：

从已安装影视应用的飞牛系统中拷贝以下文件：

```bash
tar -C /usr/trim -czvf mediasrv.tgz ./bin/mediasrv ./lib/mediasrv ./lib/libnebula.so ./lib/libppjson.so
tar -C /usr/local/apps/@appcenter/trim.media -czvf trim.media-app.tgz .
tar -C /var/apps/trim.media -czvf trim.media-var.tgz ./cmd ./config ./i18n ./wizard ./ICON.PNG ./ICON_256.PNG ./manifest
```

### 补充文件：
- 创建临时文件夹 `mediasrv` ，并解压 `mediasrv.tgz` 文件到 `mediasrv` 文件夹；
- 或创建临时文件夹 `mediasrv` ，并拷贝以下文件：

```bash
mkdir -p mediasrv/bin mediasrv/lib mediasrv/etc
cp -r /usr/trim/bin/mediasrv mediasrv/bin/
cp -r /usr/trim/lib/mediasrv /usr/trim/lib/libnebula.so /usr/trim/lib/libppjson.so mediasrv/lib/
```

- 将 `entrypoint.sh` 和 `init.sql` 添加到 `mediasrv` 文件夹；

- 编译 `fakebroker.go` 到 `mediasrv/bin/rpcbroker`，并赋予其可执行权限；

```bash
curl -O https://dl.google.com/go/go1.24.10.linux-amd64.tar.gz && tar -C /opt -xvf go1.24.10.linux-amd64.tar.gz
/opt/go/bin/go build -o mediasrv/bin/rpcbroker fakebroker.go
```

- 重新打包 `mediasrv.tgz`。
```bash
tar -C mediasrv -czvf mediasrv.tgz .
```

### 执行构建：

将上述 3 个压缩包、Dockerfile 以及补充文件放在同一目录下，执行：

```bash
docker build --no-cache -t trimmedia .
```

## 参考来源
[飞牛影视独立化Docker镜像](https://www.nodeseek.com/post-604506-1) 需梯子

[docker中运行飞牛影视](https://qs100371.top/post/docker-zhong-yun-xing-fei-niu-ying-shi/)