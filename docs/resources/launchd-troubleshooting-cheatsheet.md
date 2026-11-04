# launchd 服务排查小抄

## 一分钟排查

```bash
launchctl print gui/$(id -u)/com.example.app | head -30   # 状态与环境
launchctl kickstart -k gui/$(id -u)/com.example.app        # 重启
plutil -lint ~/Library/LaunchAgents/com.example.app.plist  # 语法
tail -20 ~/Library/Logs/app.log                            # 日志
```

## 最常见的三个坑

| 坑 | 现象 | 修法 |
|---|---|---|
| PATH 缺 Homebrew | `command not found` / 功能静默失效 | 启动时补 PATH，或绝对路径 + `shutil.which` |
| 工作目录不对 | 读不到相对路径文件 | plist 配 `WorkingDirectory` |
| 改完没重启 | 代码改了没生效 | `launchctl kickstart -k` |

## plist 模板

```xml
<key>Label</key><string>com.example.app</string>
<key>ProgramArguments</key>
<array>
  <string>/opt/homebrew/bin/python3</string>
  <string>/path/to/app.py</string>
</array>
<key>WorkingDirectory</key><string>/path/to</string>
<key>EnvironmentVariables</key>
<dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
<key>KeepAlive</key><true/>
<key>StandardOutPath</key><string>/Users/you/Library/Logs/app.log</string>
<key>StandardErrorPath</key><string>/Users/you/Library/Logs/app.log</string>
```

## 启动自检（避免静默失败）

```python
for tool in ("pdftotext", "node", "ffmpeg"):
    log.info("依赖 %s: %s", tool, shutil.which(tool) or "缺失")
```

> 仅用于本人设备/自有服务。
