# 靶场与复现说明

## 靶场一：登录 / 隐藏注册动作

```bash
cd ~/Documents/deepseek-harness/security-lab/login-register-lab
./start.sh          # 默认 127.0.0.1:1234（只回环）
```

- 现象：前端只有"登录"，后端保留 `register` 动作 → 抓包把 `login` 改 `register` 即可注册
- 预置账号：`admin / Admin@123`（仅靶场）
- 用途：练接口 fuzz、越权、未授权注册

## 靶场二：明文凭据（Burp 复现）

```bash
# 先启动靶场一，然后把流量走 Burp 代理
curl -x http://127.0.0.1:8080 -X POST http://127.0.0.1:1234/login \
     -d "u=demo&p=Demo%232026"
```

- Burp → Proxy → HTTP history 里能直接看到明文 `u/p`
- 响应直接下发 token，可用 `GET /profile?token=...` 访问
- 边界：只读、只 GET/HEAD、不提交真实凭据、不改配置

## 边界声明

所有复现只在本地回环靶场进行；真实环境测试需书面授权，且只做只读探测。
