本文修改 System项目 - ingress-nginx 命名空间 - nginx-configration ConfigMap

**使用外部7层代理 `X-Forwarded-*`请求头**

请先确保外部是7层代理，添加配置：

```txt
use-forwarded-headers: true
```

**使用外部4层代理 `proxy_protocol on`;**

请先确保外部是4层代理，添加配置：

```txt
use-proxy-protocol: true
```

**SSL 1.2版本支持 `ssl`**

请先确保程序支持并保证安全性，添加配置：

```txt
 ssl-ciphers: ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA
  ssl-protocols: TLSv1 TLSv1.1 TLSv1.2 TLSv1.3
```

**关闭access log**

关闭access log可以使你专注于error日志，添加配置：

```txt
disable-access-log: true
```

**开启压缩**

开启压缩可以减少传输尺寸，添加配置：

```txt
enable-brotli: true
```

参考文档：[NGINX Ingress Controller - ConfigMap](