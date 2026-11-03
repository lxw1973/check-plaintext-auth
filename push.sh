#!/bin/bash
# 一次性推送脚本：仓库建好后运行（把 REPO 改成实际名字）
REPO="${1:-check-plaintext-auth}"
git remote remove origin 2>/dev/null
git remote add origin "git@github.com:lxw1973/${REPO}.git"
git push -u origin main
git tag -a v1.0.0 -m "v1.0.0 首个版本：明文凭据自查脚本 + 清单 + nginx 模板 + 靶场复现" 2>/dev/null || true
git push origin v1.0.0
echo "[+] 已推送：https://github.com/lxw1973/${REPO}"
