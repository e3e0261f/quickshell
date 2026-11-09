#!/bin/bash
LOCK_FILE="/tmp/clicker.lock"
ACTIVE_FILE="/tmp/clicker_active"
BTN_FILE="/tmp/clicker_btn"

rm -f "$LOCK_FILE" "$ACTIVE_FILE"
echo "0xC0" > "$BTN_FILE"

while true; do
    if [ -f "$ACTIVE_FILE" ] && [ -f "$LOCK_FILE" ]; then
        BTN=$(cat "$BTN_FILE" 2>/dev/null || echo "0xC0")
        ydotool click "$BTN"
        sleep 0.05
    else
        sleep 0.05
    fi
done
