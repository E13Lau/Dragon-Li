# README

## 这是什么？

这是一个 IPA 包和 APK 包托管的服务，包含 CA 证书下载，iPhone设备UDID获取等服务。
使用 Vapor 框架开发，Docker 部署，SQLite 作为数据库服务。

``` upload接口
POST /upload HTTP/1.1
Host: imac.local:14145
File-Name: example.ipa
Package-Name: QQ
Package-Version: 1.1.5
Package-BuildNumber: 114
Package-BundleID: com.apple.qq.com.apple.qq.com.apple.qq.com.apple.qq
Content-Type: application/octet-stream
Content-Length: 22

"<file contents here>"
```

## 如何开发？

双击项目根目录下 Package.swift 文件在 Xcode 中打开。
等待 Swift Package resolve。

### 如何清空数据？

只需要删除项目目录下 Uploads 文件夹以及 Database 文件夹重新编译运行即可。

## 如何部署？

### 局域网部署

因为 iOS 安装网络必须 HTTPS，所以局域网这里会使用 mDNS 来部署一个包含域名的服务器。
macOS 包含 Bonjour 服务使得这个过程相对容易一些，所以这里以 macOS 说明。

1. macOS 下，打开 设置.app ，打开共享菜单，你可以看到以 .local 结尾的域名，下面以`xx.local`代替。
2. 使用 OpenSSL 创建自签名根证书，命名为 rootCA_cert.pem。
3. 使用根证书签发 `xx.local` 域名的域证书。
4. 将根证书、域证书放到 certs 文件夹下。
5. 修改 ./config/web.conf 中 server_name 字段为 `xx.local`。
6. 使用指令 `docker-compose up --build -d` 运行容器。
7. 同一局域网下访问`xx.local`打开页面。

### 广域网部署

TODO
