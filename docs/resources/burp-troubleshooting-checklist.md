# Burp 抓不到包 · 6 步排查清单

## 顺序（按这个查，别乱试）

| # | 检查 | 命令 / 位置 | 通过标准 |
|---|---|---|---|
| 1 | 代理在监听 | `lsof -nP -iTCP:8080 -sTCP:LISTEN` | 有 java 进程监听 |
| 2 | 流量进 Burp | `curl -x http://127.0.0.1:8080 -v http://example.com/` | 打印 Connected 且在 HTTP history 出现 |
| 3 | HTTPS 解密 | 浏览器访问 http://burp 装 CA；`curl -sk` 对比 | HTTPS 请求在 history 里可读 |
| 4 | 拦截 / Scope | Intercept 按钮、Filter 是否只看 in-scope | Intercept 关、目标加进 Scope |
| 5 | 客户端代理 | `HTTP_PROXY` 环境变量 / Proxifier / 透明代理 | `curl -x` 能抓、应用也能抓 |
| 6 | REST API 401 | `lsof -iTCP:1337` 看端口归属 | key 与实例匹配、改完重启 Burp |

## 常见判断

- HTTP 能抓、HTTPS 不能 → 证书没装 / 证书固定
- history 一条没有，但 curl -x 正常 → Intercept 开着或 Filter 过滤
- 桌面应用抓不到 → 不读系统代理，用环境变量或 Proxifier
- REST API 返回 401 → 先确认端口上是哪个 Burp 实例

## 常用命令

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
curl -x http://127.0.0.1:8080 -v http://example.com/
curl -sk -o /dev/null -w '%{http_code}\n' https://example.com/
curl -H "Authorization: Bearer <key>" http://127.0.0.1:1337/burp/versions
```

> 仅用于自有或已授权资产的安全测试。
