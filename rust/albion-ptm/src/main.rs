use evdev::{EventSummary, KeyCode};
use std::io::Write;
use std::process::Command;
use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc,
};
use std::thread;

fn parse_ptm_key(raw: &str) -> Option<(KeyCode, &'static str)> {
    match raw.trim().to_lowercase().as_str() {
        // 字母鍵
        "a" => Some((KeyCode::KEY_A, "a")),
        "b" => Some((KeyCode::KEY_B, "b")),
        "c" => Some((KeyCode::KEY_C, "c")),
        "d" => Some((KeyCode::KEY_D, "d")),
        "e" => Some((KeyCode::KEY_E, "e")),
        "f" => Some((KeyCode::KEY_F, "f")),
        "g" => Some((KeyCode::KEY_G, "g")),
        "h" => Some((KeyCode::KEY_H, "h")),
        "i" => Some((KeyCode::KEY_I, "i")),
        "j" => Some((KeyCode::KEY_J, "j")),
        "k" => Some((KeyCode::KEY_K, "k")),
        "l" => Some((KeyCode::KEY_L, "l")),
        "m" => Some((KeyCode::KEY_M, "m")),
        "n" => Some((KeyCode::KEY_N, "n")),
        "o" => Some((KeyCode::KEY_O, "o")),
        "p" => Some((KeyCode::KEY_P, "p")),
        "q" => Some((KeyCode::KEY_Q, "q")),
        "r" => Some((KeyCode::KEY_R, "r")),
        "s" => Some((KeyCode::KEY_S, "s")),
        "t" => Some((KeyCode::KEY_T, "t")),
        "u" => Some((KeyCode::KEY_U, "u")),
        "v" => Some((KeyCode::KEY_V, "v")),
        "w" => Some((KeyCode::KEY_W, "w")),
        "x" => Some((KeyCode::KEY_X, "x")),
        "y" => Some((KeyCode::KEY_Y, "y")),
        "z" => Some((KeyCode::KEY_Z, "z")),
        // 數字鍵
        "0" => Some((KeyCode::KEY_0, "0")),
        "1" => Some((KeyCode::KEY_1, "1")),
        "2" => Some((KeyCode::KEY_2, "2")),
        "3" => Some((KeyCode::KEY_3, "3")),
        "4" => Some((KeyCode::KEY_4, "4")),
        "5" => Some((KeyCode::KEY_5, "5")),
        "6" => Some((KeyCode::KEY_6, "6")),
        "7" => Some((KeyCode::KEY_7, "7")),
        "8" => Some((KeyCode::KEY_8, "8")),
        "9" => Some((KeyCode::KEY_9, "9")),
        // 功能鍵
        "f1" => Some((KeyCode::KEY_F1, "f1")),
        "f2" => Some((KeyCode::KEY_F2, "f2")),
        "f3" => Some((KeyCode::KEY_F3, "f3")),
        "f4" => Some((KeyCode::KEY_F4, "f4")),
        "f5" => Some((KeyCode::KEY_F5, "f5")),
        "f6" => Some((KeyCode::KEY_F6, "f6")),
        "f7" => Some((KeyCode::KEY_F7, "f7")),
        "f8" => Some((KeyCode::KEY_F8, "f8")),
        "f9" => Some((KeyCode::KEY_F9, "f9")),
        "f10" => Some((KeyCode::KEY_F10, "f10")),
        "f11" => Some((KeyCode::KEY_F11, "f11")),
        "f12" => Some((KeyCode::KEY_F12, "f12")),
        // 常用控制與標點鍵
        "capslock" | "caps" | "caps_lock" => Some((KeyCode::KEY_CAPSLOCK, "capslock")),
        "grave" | "`" => Some((KeyCode::KEY_GRAVE, "grave")),
        "tab" => Some((KeyCode::KEY_TAB, "tab")),
        "space" | "spc" => Some((KeyCode::KEY_SPACE, "space")),
        "enter" | "return" => Some((KeyCode::KEY_ENTER, "enter")),
        "esc" | "escape" => Some((KeyCode::KEY_ESC, "esc")),
        "minus" | "-" => Some((KeyCode::KEY_MINUS, "minus")),
        "equal" | "=" => Some((KeyCode::KEY_EQUAL, "equal")),
        "lshift" => Some((KeyCode::KEY_LEFTSHIFT, "lshift")),
        "rshift" => Some((KeyCode::KEY_RIGHTSHIFT, "rshift")),
        "lctrl" => Some((KeyCode::KEY_LEFTCTRL, "lctrl")),
        "rctrl" => Some((KeyCode::KEY_RIGHTCTRL, "rctrl")),
        "lalt" => Some((KeyCode::KEY_LEFTALT, "lalt")),
        "ralt" => Some((KeyCode::KEY_RIGHTALT, "ralt")),
        "pause" => Some((KeyCode::KEY_PAUSE, "pause")),
        "scrolllock" => Some((KeyCode::KEY_SCROLLLOCK, "scrolllock")),
        "insert" => Some((KeyCode::KEY_INSERT, "insert")),
        "up" => Some((KeyCode::KEY_UP, "up")),
        "down" => Some((KeyCode::KEY_DOWN, "down")),
        "left" => Some((KeyCode::KEY_LEFT, "left")),
        "right" => Some((KeyCode::KEY_RIGHT, "right")),
        // 鼠標側鍵 / 中鍵
        "mousemiddle" | "mmiddle" => Some((KeyCode::BTN_MIDDLE, "mousemiddle")),
        "mouse4" | "mside" | "side" => Some((KeyCode::BTN_SIDE, "mouse4")),
        "mouse5" | "mextra" | "extra" => Some((KeyCode::BTN_EXTRA, "mouse5")),
        _ => None,
    }
}

fn set_mic_mute(muted: bool, debug: bool) {
    let val_num = if muted { "1" } else { "0" };
    let val_pamixer = if muted { "-m" } else { "-u" };
    // 同時靜音 PipeWire (wpctl 預設輸入源 + 所有 Audio/Source 節點) 與 PulseAudio/PipeWire-Pulse (pactl 所有非 monitor 輸入源)，避免多麥克風或藍牙耳麥漏音
    let cmd = format!(
        "if command -v wpctl >/dev/null 2>&1; then \
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ {v} 2>/dev/null || true; \
            for id in $(wpctl status 2>/dev/null | awk '/^Audio/{{a=1}} /^Video|^Settings/{{a=0}} a && /Sources:/{{f=1;next}} f && /(Filters|Streams|Sinks|Endpoints):/{{f=0}} f{{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\\.$/){{sub(/\\.$/,\"\",$i); print $i; break}}}}'); do \
                wpctl set-mute \"$id\" {v} 2>/dev/null || true; \
            done; \
         fi; \
         if command -v pactl >/dev/null 2>&1; then \
            pactl set-source-mute @DEFAULT_SOURCE@ {v} 2>/dev/null || true; \
            for s in $(pactl list short sources 2>/dev/null | awk '$2 !~ /\\.monitor$/ {{print $1}}'); do \
                pactl set-source-mute \"$s\" {v} 2>/dev/null || true; \
            done; \
         fi; \
         if ! command -v wpctl >/dev/null 2>&1 && ! command -v pactl >/dev/null 2>&1 && command -v pamixer >/dev/null 2>&1; then \
            pamixer --default-source {p} 2>/dev/null || true; \
         fi",
        v = val_num,
        p = val_pamixer
    );
    let st = Command::new("sh").args(["-c", &cmd]).status();
    println!("STATE|{}", if muted { "MUTED" } else { "LIVE" });
    let _ = std::io::stdout().flush();
    if debug {
        eprintln!(
            "[PTM-DEBUG] mic -> {} (sh={:?})",
            if muted { "MUTED" } else { "LIVE" },
            st.map(|s| s.code())
        );
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut key_arg = String::from("v");
    let mut debug = false;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "-d" | "--debug" => debug = true,
            "--key" => {
                i += 1;
                if i < args.len() {
                    key_arg = args[i].clone();
                } else {
                    eprintln!("ERR|missing_key_arg");
                    std::process::exit(1);
                }
            }
            arg if !arg.starts_with('-') => {
                key_arg = arg.to_string();
            }
            _ => {}
        }
        i += 1;
    }

    let (target_code, target_name) = match parse_ptm_key(&key_arg) {
        Some(pair) => pair,
        None => {
            eprintln!("ERR|unsupported_key:{}", key_arg);
            std::process::exit(1);
        }
    };

    // 啟動時確保麥克風處於可通話初始狀態
    set_mic_mute(false, debug);

    let held_count = Arc::new(AtomicUsize::new(0));
    let mut dev_count: usize = 0;

    for (path, mut dev) in evdev::enumerate() {
        let name = dev.name().unwrap_or("unknown").to_string();
        if name.contains("ydotool")
            || name.contains("hl-virtual-keyboard")
            || name.contains("albion-qspam")
            || name.contains("albion-clicker")
        {
            continue;
        }
        let supports_target = dev
            .supported_keys()
            .map_or(false, |s| s.contains(target_code));
        if !supports_target {
            continue;
        }

        dev_count += 1;
        if debug {
            eprintln!(
                "[PTM-DEBUG] 監聽設備 [{}]: {} ({})",
                target_name,
                name,
                path.display()
            );
        }

        let count = Arc::clone(&held_count);
        thread::spawn(move || {
            let mut dev_held = false;
            loop {
                match dev.fetch_events() {
                    Ok(events) => {
                        for ev in events {
                            if let EventSummary::Key(_, code, val) = ev.destructure() {
                                if code == target_code {
                                    if val == 1 && !dev_held {
                                        dev_held = true;
                                        if count.fetch_add(1, Ordering::SeqCst) == 0 {
                                            set_mic_mute(true, debug);
                                        }
                                    } else if val == 0 && dev_held {
                                        dev_held = false;
                                        if count.fetch_sub(1, Ordering::SeqCst) == 1 {
                                            set_mic_mute(false, debug);
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Err(_) => {
                        if dev_held {
                            dev_held = false;
                            if count.fetch_sub(1, Ordering::SeqCst) == 1 {
                                set_mic_mute(false, debug);
                            }
                        }
                        break;
                    }
                }
            }
        });
    }

    if dev_count == 0 {
        eprintln!("ERR|no_evdev_device_for:{}", target_name);
        std::process::exit(1);
    }

    println!("READY|{}|rust_evdev|devs={}", target_name, dev_count);
    let _ = std::io::stdout().flush();
    loop {
        thread::park();
    }
}
