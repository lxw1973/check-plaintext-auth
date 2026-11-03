# 明文凭据暴露 · 自查清单（10 条）

1. **全站 HTTPS**：所有管理面/后台/内部工具都用 TLS；HTTP 一律 301 到 HTTPS
2. **禁止明文认证**：HTTP 上不得出现 `WWW-Authenticate: Basic`、登录页、JSON 凭据提交
3. **检查 listen**：`nginx -T | grep -E "listen"`，确认没有"非 ssl 的 listen + auth_basic"
4. **检查备份配置**：`*.conf.bak` 不会加载，但 `*_bak.conf` 会——清理误加载的备份
5. **直连 IP**：确认直连 IP 不会绕过域名层鉴权（默认拒绝 + 例外白名单）
6. **HSTS**：`Strict-Transport-Security: max-age=31536000`
7. **凭据传输位置**：只在 POST body；禁止 GET/URL 带账号口令
8. **会话令牌**：`HttpOnly; Secure; SameSite=Lax/Strict` Cookie，不放 URL
9. **口令轮换**：改完必须自检——匿名 401 / 认证 200；失败自动回滚
10. **限速与审计**：登录失败限速；保留访问日志与鉴权日志

## 一条命令自查

```bash
./check-plaintext-auth.sh <host>[:port]
sudo ./check-plaintext-auth.sh --nginx
```
退出码：0=无风险 / 1=有风险。
