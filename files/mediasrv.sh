#!/bin/bash

arch="${1:-amd64}"

case "$arch" in
  amd64)
    platform="x86"
    ;;
  arm64)
    platform="arm"
    ;;
  *)
    echo "Usage: $0 {amd64|arm64}"
    exit 1
    ;;
esac

echo "Building for platform: $arch"

set -eux

cat > fakebroker.go <<'EOF'
package main

import (
  "bytes"
  "encoding/binary"
  "encoding/json"
  "flag"
  "fmt"
  "io"
  "log"
  "net"
  "net/http"
  "os"
  "path"
  "path/filepath"
  "strings"
  "golang.org/x/sys/unix"
)

const (
  appCenterAddr  = "/run/com.trim.app.center.sock"
  brokerAddr     = "/run/trim_app_cgi/rpcbroker"
  defaultToken   = "reserved"
  magicNumber    = "CPRT" // magic number for rpc protocol
  headerSize     = 80
  payloadLenPos  = 18
  payloadLenSize = 2
)

type (
  Service struct {
    Id    string `json:"id"`
    Name  string `json:"name"`
    IP    string `json:"ip"`
    Uds   string `json:"uds"`
    Type  int    `json:"type"`
    Token string `json:"token"`
  }

  Request struct {
    Header []byte `json:"-"`
    Data   struct {
      Uid      uint32   `json:"uid"`
      Pid      uint32   `json:"pid"`
      Req      string   `json:"req"`
      ReqId    string   `json:"reqid"`
      AppName  string   `json:"appName"`
      UserName string   `json:"user"`
      Services []string `json:"services,omitempty"`
    } `json:"data"`
  }

  BaseResp struct {
    Data   any    `json:"data,omitempty"`
    ReqId  string `json:"reqid"`
    Result string `json:"result"`
    Rev    string `json:"rev"`
    Req    string `json:"req,omitempty"`
  }

  Response struct {
    Data BaseResp `json:"data"`
  }

  AppAuthorizedDir struct {
    Type     int    `json:"storageType"`
    Path     string `json:"path"`
    UserName string `json:"uname"`
  }

  AuthPath struct {
    Editable bool   `json:"isEditable"`
    Perm     int    `json:"perm"`
    Status   int    `json:"status"`
    Path     string `json:"path"`
  }
)

var (
  username          string
  logPath           string
  folders           string
  authPathResp      []byte
  appAuthorizedDirs []AppAuthorizedDir
  marshaledUserId   = json.RawMessage(`{"uid": 1000}`)
  marshaledVolsInfo json.RawMessage

  services = []Service{
    {Id: "com.trim.main", Name: "TRIM Service", Uds: brokerAddr, Token: defaultToken, Type: 1},
    {Id: "com.trim.sysinfo", Name: "System Info Provider Service", Uds: brokerAddr, Token: defaultToken},
    {Id: "com.trim.filestor", Name: "File Storage Service", Uds: brokerAddr, Token: defaultToken},
    {Id: "com.trim.usersrv", Name: "User Service", Uds: brokerAddr, Token: defaultToken},
  }
)

func GetAvailableSpace(pathStr string) (uint64, error) {
  absPath, err := filepath.Abs(pathStr)
  if err != nil {
    return 0, fmt.Errorf("failed to get absolute path: %w", err)
  }
  absPath, err = filepath.EvalSymlinks(absPath)
  if err != nil {
    return 0, fmt.Errorf("failed to resolve symbolic link: %w", err)
  }
  var stat unix.Statfs_t
  if err := unix.Statfs(pathStr, &stat); err != nil {
    return 0, fmt.Errorf("statfs call failed: %w", err)
  }
  return stat.Bavail * uint64(stat.Bsize), nil
}

func init() {
  flag.StringVar(&username, "u", "admin", "user name")
  flag.StringVar(&logPath, "p", "/var/log/rpcbroker.log", "log file path")
  flag.StringVar(&folders, "f", "/vol1/1000/media:", "media folders")
  flag.Parse()

  splited := strings.Split(folders, ":")
  appAuthorizedDirs = make([]AppAuthorizedDir, 0, len(splited))
  authPaths := make([]AuthPath, 0, len(splited))

  for _, v := range splited {
    if strings.TrimSpace(v) == "" {
      continue
    }
    appAuthorizedDirs = append(appAuthorizedDirs, AppAuthorizedDir{Path: v, Type: 3, UserName: username})
    authPaths = append(authPaths, AuthPath{Path: v, Perm: 6, Editable: true})
  }
  authPathResp, _ = json.Marshal(map[string]any{"code": 0, "msg": "", "data": map[string][]AuthPath{"list": authPaths}})
}

  func getLatestVolsInfo() json.RawMessage {
    var availableSize uint64 = 137438953472 // 默认兜底值 (128 GB)

    splited := strings.Split(folders, ":")
    for _, v := range splited {
      if strings.TrimSpace(v) == "" {
        continue
      }
      size, err := GetAvailableSpace(v)
      if err == nil {
        availableSize = size
        break
      }
    }

    return json.RawMessage(fmt.Sprintf(
      `{"vols":[{"index":1,"state":0,"sysname":"dm-0","uuid":"trim_00000000_1111_2222_3333_444444444444-0","size":%d,"used":0,"voltype":61267}],"count":1}`,
      availableSize,
    ))
  }

func NewResp(req *Request, data any) BaseResp {
  return BaseResp{ReqId: req.Data.ReqId, Req: req.Data.Req, Data: data, Result: "succ", Rev: "0.1"}
}

func NewErrorResp(req *Request) BaseResp {
  return BaseResp{ReqId: req.Data.ReqId, Req: req.Data.Req, Result: "fail", Rev: "0.1"}
}

func readHeader(conn net.Conn) ([]byte, error) {
  header := make([]byte, headerSize)
  _, err := io.ReadFull(conn, header)
  if err != nil {
    return nil, err
  }

  if !bytes.Equal(header[:4], []byte(magicNumber)) {
    return nil, fmt.Errorf("invalid magic number: %x", header[:4])
  }

  return header, nil
}

func parseRequest(conn net.Conn) (*Request, error) {
  header, err := readHeader(conn)
  if err != nil {
    log.Printf("read header error from %s: %v\n", conn.RemoteAddr(), err)
    return nil, err
  }

  plLen := getPayloadLength(header)
  payload, err := readPayload(conn, plLen)
  if err != nil {
    log.Println("header:", string(header))
    log.Printf("read payload error from %s: %v\n", conn.RemoteAddr(), err)
    log.Println("payload:", string(payload))
    return nil, err
  }

  var req Request
  if err := json.Unmarshal(payload, &req); err != nil {
    log.Println(string(payload))
    return nil, fmt.Errorf("unmarshal payload failed: %w", err)
  }

  log.Println("request:", string(payload))
  req.Header = header
  return &req, nil
}

func getPayloadLength(header []byte) uint16 {
  return binary.LittleEndian.Uint16(header[payloadLenPos : payloadLenPos+payloadLenSize])
}

func readPayload(conn net.Conn, length uint16) ([]byte, error) {
  if length == 0 {
    return nil, fmt.Errorf("payload len is zero")
  }
  payload := make([]byte, length)
  _, err := io.ReadFull(conn, payload)
  return payload, err
}

func writeResponse(conn net.Conn, header []byte, payload []byte) error {
  length := uint16(len(payload))
  binary.LittleEndian.PutUint16(header[payloadLenPos:payloadLenPos+payloadLenSize], length)
  _, err := conn.Write(append(header, payload...))
  return err
}

func processRequest(req *Request) BaseResp {
  switch req.Data.Req {
  case "com.trim.rpcbroker.apply":
    return NewResp(req, services)

  case "com.trim.usersrv.getUserId", "com.trim.sysinfo.getUserId":
    return NewResp(req, marshaledUserId)

  case "com.trim.filestor.getAppAuthorizedDir":
    return NewResp(req, appAuthorizedDirs)

  case "com.trim.sysinfo.getAllVolsInfo":
    return NewResp(req, getLatestVolsInfo()) 

  default:
    log.Println("unknown req:", req.Data.Req)
    return NewErrorResp(req)
  }
}

func handleConnection(conn net.Conn) {
  defer conn.Close()
  addr := conn.RemoteAddr()

  log.Printf("client %s connected\n", addr)

  for {
    req, err := parseRequest(conn)
    if err != nil {
      log.Printf("read request error from %s: %v\n", addr, err)
      return
    }

    resp := processRequest(req)

    data, _ := json.Marshal(Response{Data: resp})
    log.Println("response:", string(data))
    if err := writeResponse(conn, req.Header, data); err != nil {
      log.Printf("write resp error: %v\n", err)
      return
    }
  }
}

func main() {
  log.SetFlags(log.LstdFlags | log.Lshortfile)
  logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
  if err != nil {
    log.Fatalf("cannot open log file: %s: %v", logPath, err)
  }
  defer logFile.Close()
  log.SetOutput(logFile)

  // start auth http server
  os.RemoveAll(appCenterAddr)
  al, err := net.Listen("unix", appCenterAddr)
  if err != nil {
    log.Fatalf("cannot listen http unix: %v", err)
  }
  defer al.Close()

  http.HandleFunc("/rpc/v1/sysconfig/app/auth-path", func(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    w.Write(authPathResp)
  })

  go func() {
    log.Println("app center serve:", http.Serve(al, nil))
  }()

  // start rpc broker
  os.Remove(brokerAddr)
  os.MkdirAll(path.Dir(brokerAddr), 0755)

  listener, err := net.Listen("unix", brokerAddr)
  if err != nil {
    log.Fatalf("listen rpc broker %s failed: %v", brokerAddr, err)
  }
  defer listener.Close()

  log.Printf("rpc broker listening on %s\n", brokerAddr)

  for {
    conn, err := listener.Accept()
    if err != nil {
      log.Printf("accept error: %v\n", err)
      continue
    }
    go handleConnection(conn)
  }
}

EOF

apt update

command -v curl >/dev/null 2>&1 || apt install -y curl
command -v jq >/dev/null 2>&1 || apt install -y jq
command -v ar >/dev/null 2>&1 || apt install -y binutils
command -v gawk >/dev/null 2>&1 || apt install -y gawk
command -v xz >/dev/null 2>&1 || apt install -y xz-utils
if [ "$arch" = "arm64" ]; then
command -v aarch64-linux-gnu-objdump >/dev/null 2>&1 || apt install -y binutils-aarch64-linux-gnu
fi

data=$(curl -sS "https://apiv2-liveupdate.fnnas.com/?platform=${platform}" | head -c -256 | jq -r '.packages[] | select(.packageName=="trim")')
dlkey=$(echo "$data" | jq -r '.dlkey')
url=$(echo "$data" | jq -r '.url')
version=$(echo "$data" | jq -r '.version')
description=$(echo "$data" | jq -r '.description')
filename=$(basename $url)
t=$(date +%s)

bytes=$(printf '%s' "$dlkey" | base64 -d 2>/dev/null | od -An -tx1 | tr -s ' ' '\n' | sed '/^$/d')
secret=$(printf '%s\n' "$bytes" | gawk '{for(i=1;i<=NF;i++) printf "%c", xor(strtonum("0x"$i), 94)}')
path=$(sed -E 's#^[^/]*//[^/]*([^?]*)?.*$#\1#' <<< "$url")

sign=$(printf '%s' "${secret}${path}${t}" | md5sum | awk '{print $1}')
url="${url}?sign=${sign}&t=${t}"

curl -fL -C - -R -O "$url"

ar x "$filename"
mkdir -p mediasrv mediasrv/etc

tar -C mediasrv -xvf data.tar.xz \
 ./usr/trim/bin/mediasrv \
 ./usr/trim/lib/mediasrv \
 ./usr/trim/lib/libhwinfo.so \
 ./usr/trim/lib/libhwinfo.so.0 \
 ./usr/trim/lib/libhwinfo.so.0.8 \
 ./usr/trim/lib/libigputop.so \
 ./usr/trim/lib/libigputop.so.0 \
 ./usr/trim/lib/libigputop.so.0.7 \
 ./usr/trim/lib/libnebula.so \
 ./usr/trim/lib/libppjson.so \
 --strip-components=3

rm -rf debian-binary control.tar.xz data.tar.xz "$filename"

case "$arch" in
  amd64)
    objdump=(objdump -M intel)
    range=0xad
    pattern='(?:xor\s+esi,esi|mov\s+esi,0x\K[0-9a-f]+)'
    ;;
  arm64)
    objdump=(aarch64-linux-gnu-objdump)
    range=0x150
    pattern='mov\s+w1,\s*#0x\K[0-9a-f]+|mov\s+w1,\s*#\K[0-9]+'
    ;;
esac

addr="0x$($objdump -T "mediasrv/bin/mediasrv" | grep get_srv_version | awk '{print $1}' | sed 's/^0*//')"

version=$("${objdump[@]}" -d --start-address="$addr" --stop-address=$((addr + range)) "mediasrv/bin/mediasrv" \
  | grep -oP "$pattern" \
  | sed 's/^$/0/' \
  | awk '{printf "%s%d", (NR>1?".":""), strtonum("0x"$0)} END{print ""}')

echo mediasrv version is $version

curl -O https://dl.google.com/go/go1.27.1.linux-amd64.tar.gz
tar -xvf go1.27.1.linux-amd64.tar.gz
PATH=$PWD/go/bin:$PATH
go env -w GOPROXY=https://goproxy.cn,direct
go env -w GOSUMDB=sum.golang.org
go mod init fakebroker
go get golang.org/x/sys@v0.48.0
CGO_ENABLED=0 GOOS=linux GOARCH=${arch} go build -trimpath -ldflags="-s -w -buildid=" -o mediasrv/bin/rpcbroker fakebroker.go

touch -m -d "@1785140947" mediasrv/bin/rpcbroker

barch=$(file -b mediasrv/bin/rpcbroker | grep -oP '(x86-64|aarch64)' | head -1)

case "$arch" in
  amd64)  expect="x86-64" ;;
  arm64)  expect="aarch64" ;;
esac

if [ "$barch" != "$expect" ]; then
  echo "Architecture mismatch: expected $expect, but got $barch" >&2
  exit 1
fi

echo buildid executable $expect bin file

find mediasrv -type d | while read dir; do
  newest=$(find "$dir" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
  if [ -n "$newest" ]; then
    touch -m -r "$newest" "$dir"
  fi
done

touch -m -r "$(find mediasrv -type f -printf '%T@ %p\n' | sort -rn | head -n1 | cut -d' ' -f2-)" mediasrv/etc
touch -m -r "$(find mediasrv -type f -printf '%T@ %p\n' | sort -rn | head -n1 | cut -d' ' -f2-)" mediasrv

tar --sort=name --owner=0 --group=0 --numeric-owner -C mediasrv -czf mediasrv-${arch}.tgz .
touch -m -r mediasrv mediasrv-${arch}.tgz

rm -rf mediasrv go* fakebroker.go
