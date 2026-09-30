---
name: experiment-watchdog
description: Server-side watchdog daemon that monitors registered training/download/loop tasks and surfaces DEAD/STALLED/IDLE anomalies. Use when running unattended or overnight experiments and you want silent deaths or stalls to be detected instead of discovered hours later. Wraps the ARIS watchdog.py (stdlib-only).
argument-hint: [start|register|status|unregister]
---

# Experiment Watchdog

来源：ARIS（MIT License）的 `watchdog.py`，stdlib 单文件，无需安装依赖。

**原则：watchdog 只检测，不裁判。** 它能说"这个任务卡死了/进程没了"，永远不说"这个结果够好"。

## 用法

```bash
W=<skill-dir>/scripts/watchdog.py

# 1. 启动守护进程（前台运行，用 tmux/screen 挂后台）
python3 $W --interval 60 &        # 每 60 秒巡检一次

# 2. 注册训练任务（screen 会话里的训练）
python3 $W --register '{"name":"exp01","type":"training","session":"exp01","session_type":"screen","gpus":[0,1]}'

# 3. 注册下载任务
python3 $W --register '{"name":"dl01","type":"download","session":"dl01","session_type":"tmux","target_path":"/path/to/file"}'

# 4. 随时看状态（汇总，一行一个任务）
python3 $W --status

# 5. 任务结束注销
python3 $W --unregister exp01
```

## 输出

- `/tmp/aris-watchdog/status/summary.txt` —— 每任务一行，适合 `/loop` 或 CronCreate 定时读取
- `/tmp/aris-watchdog/alerts.log` —— DEAD/STALLED/IDLE 异常日志，跨会话恢复时先读这个
- `/tmp/aris-watchdog/status/<task>.json` —— 单任务详细状态

## 与工作流配合

- 跑 `experiment-queue` 或过夜实验时：启动 watchdog + 注册任务，然后可以用 CronCreate 每 10-30 分钟读一次 `summary.txt`，有异常再深入。
- 无人值守循环（karpathy 模式）开始前注册为 `loop` 类型任务 —— 静默死亡会在下次巡检时暴露为 STALE，而不是几小时后才被你发现。
