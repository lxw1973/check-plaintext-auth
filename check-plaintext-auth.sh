#!/bin/bash
# check-plaintext-auth.sh —— 自查「明文凭据暴露」：只开了 HTTP 却要求口令的端口
#
# 两种模式：
#   1) 远程模式（默认）：对 host/port 做只读探测 —— 看 HTTP 是否 401/Basic、是否有登录页、是否强制跳 HTTPS
#   2) nginx 模式（--nginx）：审计本机 nginx 配置 —— 找"非 ssl 的 listen + auth_basic"组合
#
# 全程只做 GET/HEAD，不爆破、不提交表单、不修改任何配置。
#
# 用法：
#   ./check-plaintext-auth.sh 192.168.1.1 192.168.1.1:5001 example.com
#   ./check-plaintext-auth.sh --ports 80,8080,5001,8443 10.0.0.0/24   # 只对 /24 逐个展开（可用 --hosts 提供清单）
#   ./check-plaintext-auth.sh --hosts hosts.txt --ports 80,8080
#   ./check-plaintext-auth.sh --nginx                    # 审计本机 nginx（自动 nginx -T）
#   ./check-plaintext-auth.sh --nginx /etc/nginx/conf.d/site.conf
#   ./check-plaintext-auth.sh ... --json out.json
#
# 退出码：0=未发现风险；1=发现风险；2=参数/环境错误
set -uo pipefail

PORTS="80,8080,8081,8000,8008,5001,5002,5010,8082,8443,9000,9090,7001,3000,5000,8888"
TIMEOUT=5
JSON=""
MODE=remote
NGINX_TARGET=""
HOSTS=()
HOSTS_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --ports) PORTS="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --json) JSON="$2"; shift 2 ;;
    --hosts) HOSTS_FILE="$2"; shift 2 ;;
    --nginx) MODE=nginx; if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then NGINX_TARGET="$2"; shift; fi; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) HOSTS+=("$1"); shift ;;
  esac
done

command -v curl >/dev/null || { echo "[!] 需要 curl"; exit 2; }

say() { printf '%s\n' "$*"; }
RISKS=0
ROWS=""

add_row() { ROWS+="$1"$'\n'; }
flag() { RISKS=$((RISKS+1)); }


# ---------- nginx 模式（优先执行） ----------
if [ "$MODE" = "nginx" ]; then
  say "== nginx 配置审计（非 ssl listen + auth_basic） =="
  if [ -n "$NGINX_TARGET" ] && [ -f "$NGINX_TARGET" ]; then
    CONF=$(cat "$NGINX_TARGET")
  elif command -v nginx >/dev/null 2>&1 && nginx -T >/dev/null 2>&1; then
    CONF=$(nginx -T 2>/dev/null)
  else
    say "[!] 拿不到 nginx 配置（可显式传文件路径，或 sudo 运行）"; exit 2
  fi
  AUDIT=$(mktemp /tmp/cpa_nginx.XXXXXX)
  cat > "$AUDIT" <<'PYAUDIT'
import re, sys
text = sys.stdin.read()
blocks = re.findall(r"server\s*\{([^}]*)\}", text, re.S)
risk = 0
print("%-24s%-11s%-6s%-6s%s" % ("listen", "auth_basic", "ssl", "跳转", "判定"))
print("-" * 62)
for b in blocks:
    listen = "; ".join(x.strip() for x in re.findall(r"listen\s+([^;]+);", b))
    if not listen:
        continue
    auth = [x for x in re.findall(r"auth_basic\s+([^;]+);", b) if "off" not in x]
    is_ssl = re.search(r"listen[^;]*\bssl\b", b) is not None
    redirect = re.search(r"return\s+30[12]\s+https://", b) is not None
    if auth and not is_ssl and not redirect:
        risk += 1; verdict = "RISK"
    elif auth and not is_ssl and redirect:
        verdict = "ok"
    else:
        verdict = "-"
    print("%-24s%-11s%-6s%-6s%s" % (listen[:22], "yes" if auth else "no",
          "yes" if is_ssl else "no", "yes" if redirect else "no", verdict))
print("\nnginx 侧风险：%d" % risk)
raise SystemExit(1 if risk else 0)
PYAUDIT
  printf '%s' "$CONF" | python3 "$AUDIT"
  rc=$?
  rm -f "$AUDIT"
  exit $rc
fi

# ---------- 远程模式 ----------
probe() {
  local target="$1" port="$2"
  local base="http://$target:$port"
  local http_code www_auth redirect body
  # HTTP 探测
  http_code=$(curl -s -o /tmp/cpa_body_$$ -D /tmp/cpa_hdr_$$ -w '%{http_code}' \
      --max-time "$TIMEOUT" -A 'plaintext-auth-audit/1.0' "$base/" 2>/dev/null)
  http_code=$(printf '%s' "${http_code:-000}" | tr -cd '0-9'); [ -z "$http_code" ] && http_code=000
  www_auth=$(grep -i '^www-authenticate:' /tmp/cpa_hdr_$$ 2>/dev/null | head -1 | tr -d '\r')
  redirect=$(grep -i '^location:' /tmp/cpa_hdr_$$ 2>/dev/null | head -1 | tr -d '\r')
  body=$(head -c 20000 /tmp/cpa_body_$$ 2>/dev/null)

  local tls="no"
  local tls_code
  tls_code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "https://$target:$port/" 2>/dev/null)
  tls_code=$(printf '%s' "${tls_code:-000}" | tr -cd '0-9'); [ -z "$tls_code" ] && tls_code=000
  [ "$tls_code" != "000" ] && tls="yes"

  local verdict="" ev=""
  if [ "$http_code" = "000" ]; then
    if [ "$tls_code" != "000" ]; then
      add_row "$(printf '%-24s %-6s %-5s %-8s %-5s %s' "$target:$port" "$http_code" "$tls" "ok" "$tls_code" "仅 HTTPS 监听（无明文 HTTP）")"
    fi
    rm -f /tmp/cpa_hdr_$$ /tmp/cpa_body_$$
    return
  fi

  # 情况 A：HTTP 上要求 Basic 认证
  if [ "$http_code" = "401" ] && echo "$www_auth" | grep -qi 'basic'; then
    verdict="RISK"; ev="HTTP 401 + Basic 认证头，凭据可明文嗅探"
  # 情况 B：HTTP 登录页（有 password 输入框）且未跳 HTTPS
  elif echo "$body" | grep -qiE 'type=["'"'"']?password'; then
    if echo "$redirect" | grep -qi '^location: *https://'; then
      verdict="ok"; ev="HTTP 跳转到 HTTPS"
    else
      verdict="RISK"; ev="HTTP 直接返回登录页（含密码输入框），未强制 HTTPS"
    fi
  # 情况 C：HTTP 200 且存在 Authorization 头线索（有些站点用 JS 拼 Basic）
  elif echo "$body" | grep -qiE 'basic |btoa\(|Authorization'; then
    verdict="CHECK"; ev="页面出现 Basic/btoa 痕迹，建议人工确认"
  else
    verdict="ok"; ev="未发现明文认证特征（HTTP $http_code）"
  fi

  [ "$verdict" = "RISK" ] && flag
  add_row "$(printf '%-24s %-6s %-5s %-8s %-5s %s' "$target:$port" "$http_code" "$tls" "$verdict" "$tls_code" "$ev")"
  rm -f /tmp/cpa_hdr_$$ /tmp/cpa_body_$$
}

expand_targets() {
  local t p
  for t in "$@"; do
    if [[ "$t" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/24$ ]]; then
      local pfx=${t%.*/*}; pfx=${t%/*}
      local base=${base:-$(echo "$t" | cut -d/ -f1 | awk -F. '{print $1"."$2"."$3}')}
      for i in $(seq 1 254); do echo "$base.$i"; done
    elif [[ "$t" =~ :([0-9]+)$ ]]; then
      echo "${t%:*} ${t##*:}"
    else
      echo "$t"
    fi
  done
}

say "== 明文凭据暴露自查（远程模式） =="
say "端口: $PORTS"
say ""
if [ -n "$HOSTS_FILE" ]; then
  while read -r line; do [ -n "$line" ] && HOSTS+=("$line"); done < "$HOSTS_FILE"
fi
[ ${#HOSTS[@]} -eq 0 ] && { echo "[!] 没有目标（用法见 -h）"; exit 2; }

printf '%-24s %-6s %-5s %-8s %-5s %s\n' "目标" "HTTP" "TLS" "判定" "HTTPS" "说明"
printf '%.0s-' {1..110}; echo

IFS=',' read -ra PORT_ARR <<< "$PORTS"
for raw in "${HOSTS[@]}"; do
  if [[ "$raw" == *:* ]]; then
    h=${raw%:*}; one_port=${raw##*:}
    probe "$h" "$one_port"
  else
    for p in "${PORT_ARR[@]}"; do probe "$raw" "$p"; done
  fi
done

echo "$ROWS" | sed '/^$/d'
echo ""
say "结论：发现 $RISKS 处风险"
[ -n "$JSON" ] && printf '{"risks":%d,"rows":%s}\n' "$RISKS" "$(echo "$ROWS" | sed '/^$/d' | python3 -c 'import sys,json;print(json.dumps([l.strip() for l in sys.stdin]))')" > "$JSON"

[ "$RISKS" -gt 0 ] && exit 1 || exit 0
