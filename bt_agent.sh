#!/bin/bash
FIFO="/tmp/bt_ctl_fifo"
rm -f "$FIFO"
mkfifo "$FIFO"

# 保持 FIFO 始終處於開啟狀態
exec 3<>"$FIFO"

# 啟動 bluetoothctl 監聽，自動識別關鍵字並秒回 yes
bluetoothctl < "$FIFO" 2>&1 | while IFS= read -r line; do
    # 1. 遇到 Passkey 確認請求，瞬間自動回覆 yes
    if echo "$line" | grep -q "Confirm passkey"; then
        echo "yes" > "$FIFO"
    fi

    # 2. 遇到音頻/傳輸服務授權請求，瞬間自動回覆 yes
    if echo "$line" | grep -q "Authorize service"; then
        echo "yes" > "$FIFO"
    fi

    # 3. 新設備一旦配對成功，立馬自動將其標記為 Trust 信任設備
    if echo "$line" | grep -q "Paired: yes"; then
        MAC=$(echo "$line" | grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")
        [ -n "$MAC" ] && bluetoothctl trust "$MAC" >/dev/null 2>&1
    fi
done &

# 初始化藍牙可發現與配對環境
echo "power on" > "$FIFO"
echo "pairable on" > "$FIFO"
echo "discoverable on" > "$FIFO"
echo "default-agent" > "$FIFO"
