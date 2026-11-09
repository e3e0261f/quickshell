#!/bin/bash
LOCK_FILE="/tmp/clicker.lock"
ACTIVE_FILE="/tmp/clicker_active"

while true; do
    # 只有当【总闸打开】且【按住快捷键】时，才开火！
    if [ -f "$ACTIVE_FILE" ] && [ -f "$LOCK_FILE" ]; then
        ydotool click 0xC8  # 执行连点
        sleep 0.05          # 连点速度（1秒20次）
    else
        sleep 0.02          # 任何一个没满足，低消耗等待
    fi
done
