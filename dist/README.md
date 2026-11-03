# 明文凭据自查 · 资料包

包含：

| 文件 | 说明 |
|---|---|
| `01-明文凭据自查清单.md` | 10 条可照抄的自查项 |
| `02-nginx-加固模板.conf` | 统一鉴权 + TLS + 301 + 例外白名单模板 |
| `03-靶场与复现.md` | 本地靶场启动与 Burp 复现步骤 |
| `check-plaintext-auth.sh` | 一条命令自查脚本（远程 + nginx 两种模式） |

## 快速开始

```bash
chmod +x check-plaintext-auth.sh
./check-plaintext-auth.sh <你的内网IP>
sudo ./check-plaintext-auth.sh --nginx
```

## 使用边界

仅限自有或已书面授权的资产；脚本只做 GET/HEAD，不爆破、不提交表单、不改配置。
