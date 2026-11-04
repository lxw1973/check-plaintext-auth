# check-plaintext-auth

[![](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![](https://img.shields.io/badge/bash-%E5%8D%95%E6%96%87%E4%BB%B6-blue.svg)]()
[![](https://img.shields.io/badge/%E4%BB%85%E9%99%90%E8%87%AA%E6%9C%89%2F%E6%8E%88%E6%9D%83%E8%B5%84%E4%BA%A7-orange.svg)]()

> 一条命令扫出内网「裸奔端口」：只开了 HTTP 却要求口令的入口。
> 只读探测，不爆破、不提交表单、不修改任何配置。

## 为什么写它

内部工具、管理后台常见一个组合：**端口只开了 HTTP，却加了 Basic 认证 / 登录页**。
Base64 不是加密，表单和 JSON 也是明文——同一广播域（同 Wi-Fi、同交换机、镜像口）里，任何人都能把账号口令抓走。

这个脚本就是把这类入口找出来，输出可复制的表格 + 退出码，方便接进 CI 或巡检任务。

## 用法

```bash
chmod +x check-plaintext-auth.sh

# 远程模式：探测指定主机/端口（只读 GET）
./check-plaintext-auth.sh 192.168.1.1
./check-plaintext-auth.sh 10.0.0.5:5001 10.0.0.6:8080
./check-plaintext-auth.sh --hosts hosts.txt --ports 80,8080,5001 --json out.json

# nginx 配置审计：找「非 ssl listen + auth_basic」
./check-plaintext-auth.sh --nginx
sudo ./check-plaintext-auth.sh --nginx
```

退出码：`0` 无风险 · `1` 发现风险 · `2` 参数/环境问题。

## 输出示例

```
目标                   HTTP   TLS   判定   HTTPS 说明
--------------------------------------------------------------------------
192.168.1.1:80           401    no    RISK     000   HTTP 401 + Basic 认证头，凭据可明文嗅探
192.168.1.1:1234         200    no    RISK     000   HTTP 直接返回登录页（含密码输入框），未强制 HTTPS
192.168.1.1:443          000    yes   ok       200   仅 HTTPS 监听（无明文 HTTP）
```

## 判定逻辑

| 现象 | 判定 |
|---|---|
| HTTP 401 + `WWW-Authenticate: Basic` | **RISK**：Basic 凭据可明文嗅探 |
| HTTP 登录页（`type=password`）且不跳 HTTPS | **RISK**：登录口令明文传输 |
| HTTP 301 到 HTTPS | ok |
| 仅 HTTPS 监听 | ok |

## 下载

- 仓库：https://github.com/lxw1973/check-plaintext-auth
- 源码打包（含 zip 资料包）：https://github.com/lxw1973/check-plaintext-auth/archive/refs/tags/v1.0.0.zip
- 版本：v1.0.0

## 分主题清单（PDF）

| 清单 | 文件 |
|---|---|
| Burp 抓不到包 · 6 步排查 | [PDF](docs/resources/burp-troubleshooting-checklist.pdf) |
| nginx 鉴权/权限排查 | [PDF](docs/resources/nginx-auth-permission-checklist.pdf) |
| launchd 排查小抄 + plist 模板 | [PDF](docs/resources/launchd-troubleshooting-cheatsheet.pdf) |

## 资料包

- [自查清单（10 条）](docs/checklist.md)
- [nginx 加固模板](docs/nginx-hardening.conf)
- [靶场与 Burp 复现步骤](docs/lab-and-repro.md)
- [打包下载 dist/资料包-明文凭据自查.zip](dist/)

## 边界与免责

- 仅用于**自有或已获得书面授权**的资产自查；
- 脚本只做 GET/HEAD，不爆破、不提交表单、不修改配置；
- 扫描结果可能受代理、WAF、验证码影响，误报请人工复核。

## License

[MIT](LICENSE)
