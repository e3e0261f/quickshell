#!/bin/bash
FIFO="/tmp/bt_ctl_fifo"
REQUEST_FILE="/tmp/bt_pair_request"
rm -f "$FIFO" "$REQUEST_FILE"
mkfifo "$FIFO"

exec 3<>"$FIFO"

CURRENT_MAC=""

bluetoothctl < "$FIFO" 2>&1 | while IFS= read -r line; do
    # 捕獲發起連接的設備 MAC
    if echo "$line" | grep -q "Device .* Connected: yes"; then
        CURRENT_MAC=$(echo "$line" | grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")
    fi

    # 遇到配對碼確認請求：將密鑰寫入臨時文件，通知界面彈出按鈕
    if echo "$line" | grep -q "Confirm passkey"; then
        PASSKEY=$(echo "$line" | grep -oE "[0-9]{6}")
        echo "$CURRENT_MAC|$PASSKEY" > "$REQUEST_FILE"
        notify-send -u critical -a "藍牙配對" "收到設備配對請求" "設備: ${CURRENT_MAC} 密鑰: ${PASSKEY}\n請在左下角面板點擊確認" 2>/dev/null
    fi

    # 遇到授權服務請求：自動允許音頻與傳輸流
    if echo "$line" | grep -q "Authorize service"; then
        echo "yes" > "$FIFO"
    fi

    # 一旦配對成功，抹除請求文件並自動信任
    if echo "$line" | grep -q "Paired: yes"; then
        rm -f "$REQUEST_FILE"
        MAC=$(echo "$line" | grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")
        [ -n "$MAC" ] && bluetoothctl trust "$MAC" >/dev/null 2>&1
    fi
done &

echo "power on" > "$FIFO"
echo "pairable on" > "$FIFO"
echo "discoverable on" > "$FIFO"
echo "default-agent" > "$FIFO"
