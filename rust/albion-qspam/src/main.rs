use evdev::{EventSummary, KeyCode};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::sync::{
    atomic::{AtomicBool, AtomicU64, AtomicU8, Ordering},
    Arc,
};
use std::thread;
use std::time::{Duration, Instant};

// 與 shell.qml 對齊的預設總開關檔案（可用 --flag 覆蓋，或 --no-flag 忽略）
const DEFAULT_FLAG_FILE: &str = "/tmp/q_spam_enabled";

// 預設邏輯時間參數（可用 --delay / --interval 微調）
const DEFAULT_INITIAL_DELAY_MS: u64 = 130; // 按下後持續按住多久開始連發
const DEFAULT_SPAM_INTERVAL_MS: u64 = 30;  // 連發週期：每 30ms 一次
const KEY_HOLD_MS: u64 = 12;               // --key-state 模式下每次 down -> up 的持續時間

/// 單一按鍵的獨立狀態追蹤器
struct KeyState {
    key_str: &'static str,
    held: AtomicBool,
    press_seq: AtomicU64,
}

/// 將參數字串轉換為 (evdev::KeyCode, Hyprland 按鍵名稱)
fn parse_key_name(raw: &str) -> Option<(KeyCode, &'static str)> {
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
        "1" => Some((KeyCode::KEY_1, "1")),
        "2" => Some((KeyCode::KEY_2, "2")),
        "3" => Some((KeyCode::KEY_3, "3")),
        "4" => Some((KeyCode::KEY_4, "4")),
        "5" => Some((KeyCode::KEY_5, "5")),
        "6" => Some((KeyCode::KEY_6, "6")),
        "7" => Some((KeyCode::KEY_7, "7")),
        "8" => Some((KeyCode::KEY_8, "8")),
        "9" => Some((KeyCode::KEY_9, "9")),
        "0" => Some((KeyCode::KEY_0, "0")),
        // 功能鍵與常用鍵
        "f1" => Some((KeyCode::KEY_F1, "F1")),
        "f2" => Some((KeyCode::KEY_F2, "F2")),
        "f3" => Some((KeyCode::KEY_F3, "F3")),
        "f4" => Some((KeyCode::KEY_F4, "F4")),
        "f5" => Some((KeyCode::KEY_F5, "F5")),
        "f6" => Some((KeyCode::KEY_F6, "F6")),
        "f7" => Some((KeyCode::KEY_F7, "F7")),
        "f8" => Some((KeyCode::KEY_F8, "F8")),
        "f9" => Some((KeyCode::KEY_F9, "F9")),
        "f10" => Some((KeyCode::KEY_F10, "F10")),
        "f11" => Some((KeyCode::KEY_F11, "F11")),
        "f12" => Some((KeyCode::KEY_F12, "F12")),
        "space" | "spc" => Some((KeyCode::KEY_SPACE, "space")),
        "tab" => Some((KeyCode::KEY_TAB, "Tab")),
        "enter" | "return" | "ret" => Some((KeyCode::KEY_ENTER, "Return")),
        "esc" | "escape" => Some((KeyCode::KEY_ESC, "Escape")),
        "up" => Some((KeyCode::KEY_UP, "Up")),
        "down" => Some((KeyCode::KEY_DOWN, "Down")),
        "left" => Some((KeyCode::KEY_LEFT, "Left")),
        "right" => Some((KeyCode::KEY_RIGHT, "Right")),
        _ => None,
    }
}

fn mod_bit(code: KeyCode) -> u8 {
    match code {
        KeyCode::KEY_LEFTCTRL => 1 << 0,
        KeyCode::KEY_RIGHTCTRL => 1 << 1,
        KeyCode::KEY_LEFTALT => 1 << 2,
        KeyCode::KEY_RIGHTALT => 1 << 3,
        KeyCode::KEY_LEFTMETA => 1 << 4,
        KeyCode::KEY_RIGHTMETA => 1 << 5,
        _ => 0,
    }
}

fn hypr_socket_path() -> Option<PathBuf> {
    let sig = std::env::var("HYPRLAND_INSTANCE_SIGNATURE").ok()?;
    if let Ok(xdg) = std::env::var("XDG_RUNTIME_DIR") {
        let p = PathBuf::from(xdg)
            .join("hypr")
            .join(&sig)
            .join(".socket.sock");
        if p.exists() {
            return Some(p);
        }
    }
    let fallback = PathBuf::from("/tmp/hypr").join(&sig).join(".socket.sock");
    if fallback.exists() {
        return Some(fallback);
    }
    None
}

fn send_hypr_cmd(sock: &Path, cmd: &str) -> std::io::Result<String> {
    let mut stream = UnixStream::connect(sock)?;
    stream.write_all(cmd.as_bytes())?;
    let mut buf = [0u8; 256];
    let n = stream.read(&mut buf)?;
    Ok(String::from_utf8_lossy(&buf[..n]).trim().to_string())
}

fn send_one_key(sock_path: &Path, key_str: &str, use_key_state: bool, debug: bool) {
    if use_key_state {
        let cmd_down = format!(
            r#"dispatch hl.dsp.send_key_state({{ state = "down", mods = "", key = "{}", window = "activewindow" }})"#,
            key_str
        );
        let cmd_up = format!(
            r#"dispatch hl.dsp.send_key_state({{ state = "up", mods = "", key = "{}", window = "activewindow" }})"#,
            key_str
        );
        let r1 = send_hypr_cmd(sock_path, &cmd_down);
        thread::sleep(Duration::from_millis(KEY_HOLD_MS));
        let r2 = send_hypr_cmd(sock_path, &cmd_up);
        if debug {
            eprintln!("[DEBUG] IPC key_state [{}] -> down={:?}, up={:?}", key_str, r1, r2);
        }
    } else {
        let cmd = format!(
            r#"dispatch hl.dsp.send_shortcut({{ mods = "", key = "{}" }})"#,
            key_str
        );
        let r = send_hypr_cmd(sock_path, &cmd);
        if debug {
            eprintln!("[DEBUG] IPC shortcut [{}] -> {:?}", key_str, r);
        }
    }
}

fn is_active_hold(
    state: &KeyState,
    mod_mask: &AtomicU8,
    expected_seq: u64,
    flag_enabled: &AtomicBool,
) -> bool {
    state.held.load(Ordering::SeqCst)
        && mod_mask.load(Ordering::SeqCst) == 0
        && state.press_seq.load(Ordering::SeqCst) == expected_seq
        && flag_enabled.load(Ordering::SeqCst)
}

/// 等待到 deadline，期間只要鬆開對應按鍵 / 按下修飾鍵 / 關閉開關文件就立刻返回 false
fn wait_until_or_stop(
    deadline: Instant,
    state: &KeyState,
    mod_mask: &AtomicU8,
    expected_seq: u64,
    flag_enabled: &AtomicBool,
) -> bool {
    loop {
        if !is_active_hold(state, mod_mask, expected_seq, flag_enabled) {
            return false;
        }
        let now = Instant::now();
        if now >= deadline {
            return true;
        }
        let rem = deadline.saturating_duration_since(now);
        thread::park_timeout(rem.min(Duration::from_millis(15)));
    }
}

fn print_usage(prog: &str) {
    eprintln!(
        "用法: {} [選項] [按鍵1 按鍵2 ...]\n\
         範例:\n\
         \t{} --keys q,e,1         # 同時啟用 Q, E, 1 的獨立按住連發\n\
         \t{} q e space            # 位置參數指定多個按鍵\n\
         \t{}                      # 預設僅啟用 q\n\
         選項:\n\
         \t--keys <k1,k2,...>       指定要連發的按鍵列表 (支援逗號分隔，預設 q)\n\
         \t--flag <路徑>            指定開關檔案路徑 (預設: {})\n\
         \t--no-flag                忽略開關檔案，只要程式運行就生效\n\
         \t--delay <ms>             按住多久開始連發 (預設: {}ms)\n\
         \t--interval <ms>          連發週期 (預設: {}ms)\n\
         \t--key-state              使用 down/up 狀態模式發送按鍵\n\
         \t-d, --debug              印出除錯日誌",
        prog, prog, prog, prog, DEFAULT_FLAG_FILE, DEFAULT_INITIAL_DELAY_MS, DEFAULT_SPAM_INTERVAL_MS
    );
}

fn main() -> std::io::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let mut debug = false;
    let mut use_key_state = false;
    let mut no_flag = false;
    let mut flag_file = DEFAULT_FLAG_FILE.to_string();
    let mut initial_delay_ms = DEFAULT_INITIAL_DELAY_MS;
    let mut spam_interval_ms = DEFAULT_SPAM_INTERVAL_MS;
    let mut raw_keys: Vec<String> = Vec::new();

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "-h" | "--help" => {
                print_usage(&args[0]);
                return Ok(());
            }
            "-d" | "--debug" => debug = true,
            "--key-state" => use_key_state = true,
            "--no-flag" => no_flag = true,
            "--flag" => {
                i += 1;
                if i < args.len() {
                    flag_file = args[i].clone();
                } else {
                    eprintln!("錯誤: --flag 需要指定檔案路徑");
                    std::process::exit(1);
                }
            }
            "--delay" => {
                i += 1;
                if i < args.len() {
                    initial_delay_ms = args[i].parse::<u64>().unwrap_or(DEFAULT_INITIAL_DELAY_MS).max(20);
                } else {
                    eprintln!("錯誤: --delay 需要指定毫秒數");
                    std::process::exit(1);
                }
            }
            "--interval" => {
                i += 1;
                if i < args.len() {
                    spam_interval_ms = args[i].parse::<u64>().unwrap_or(DEFAULT_SPAM_INTERVAL_MS).max(10);
                } else {
                    eprintln!("錯誤: --interval 需要指定毫秒數");
                    std::process::exit(1);
                }
            }
            "--keys" => {
                i += 1;
                if i < args.len() {
                    raw_keys.extend(args[i].split(',').map(|s| s.to_string()));
                } else {
                    eprintln!("錯誤: --keys 需要指定按鍵列表");
                    std::process::exit(1);
                }
            }
            arg if arg.starts_with('-') => {
                eprintln!("未知選項: {}", arg);
                print_usage(&args[0]);
                std::process::exit(1);
            }
            arg => {
                raw_keys.extend(arg.split(',').map(|s| s.to_string()));
            }
        }
        i += 1;
    }

    // 相容舊版無參數啟動（預設為 q）
    if raw_keys.is_empty() {
        raw_keys.push("q".to_string());
    }

    let mut key_map: HashMap<u16, Arc<KeyState>> = HashMap::new();
    let mut registered_names: Vec<&'static str> = Vec::new();

    for rk in raw_keys {
        if rk.trim().is_empty() {
            continue;
        }
        match parse_key_name(&rk) {
            Some((kc, kstr)) => {
                if !key_map.contains_key(&kc.code()) {
                    key_map.insert(
                        kc.code(),
                        Arc::new(KeyState {
                            key_str: kstr,
                            held: AtomicBool::new(false),
                            press_seq: AtomicU64::new(0),
                        }),
                    );
                    registered_names.push(kstr);
                }
            }
            None => {
                eprintln!("警告: 不支援的按鍵名稱 '{}'，已忽略", rk);
            }
        }
    }

    if key_map.is_empty() {
        eprintln!("錯誤: 未指定任何有效的連發按鍵！");
        std::process::exit(1);
    }

    let sock_path = match hypr_socket_path() {
        Some(p) => p,
        None => {
            eprintln!("找不到 Hyprland IPC socket（請確認在 Hyprland 會話中運行）");
            std::process::exit(1);
        }
    };

    if debug {
        eprintln!(
            "[DEBUG] 已註冊連發按鍵: {:?} | mode={} | delay={}ms | interval={}ms | flag={}",
            registered_names,
            if use_key_state { "send_key_state" } else { "send_shortcut" },
            initial_delay_ms,
            spam_interval_ms,
            if no_flag { "DISABLED (--no-flag)" } else { &flag_file }
        );
    }

    let mod_mask = Arc::new(AtomicU8::new(0));
    let flag_enabled = Arc::new(AtomicBool::new(no_flag || Path::new(&flag_file).exists()));
    let key_map = Arc::new(key_map);

    // 1. 為「每一個目標按鍵」啟動獨立的連發工作執行緒（實現真正互不干擾的多鍵同時連發）
    let mut worker_handles: HashMap<u16, thread::Thread> = HashMap::new();
    for (&code, state_arc) in key_map.iter() {
        let state = Arc::clone(state_arc);
        let mods = Arc::clone(&mod_mask);
        let f_enabled = Arc::clone(&flag_enabled);
        let sock = sock_path.clone();

        let join_handle = thread::spawn(move || {
            let mut handled_seq = state.press_seq.load(Ordering::SeqCst);
            loop {
                let current_seq = state.press_seq.load(Ordering::SeqCst);
                if current_seq == handled_seq {
                    thread::park_timeout(Duration::from_millis(50));
                    continue;
                }
                handled_seq = current_seq;

                if !is_active_hold(&state, &mods, current_seq, &f_enabled) {
                    continue;
                }

                // 實體按下時系統已發出第 1 下，等待啟動閾值後進入高頻連發
                let press_start = Instant::now();
                let spam_start_at = press_start + Duration::from_millis(initial_delay_ms);
                if !wait_until_or_stop(spam_start_at, &state, &mods, current_seq, &f_enabled) {
                    continue;
                }

                if debug {
                    eprintln!("[DEBUG] >>> 開始連發 [{}]", state.key_str);
                }

                loop {
                    if !is_active_hold(&state, &mods, current_seq, &f_enabled) {
                        break;
                    }
                    let cycle_start = Instant::now();
                    send_one_key(&sock, state.key_str, use_key_state, debug);

                    let next_cycle = cycle_start + Duration::from_millis(spam_interval_ms);
                    if !wait_until_or_stop(next_cycle, &state, &mods, current_seq, &f_enabled) {
                        break;
                    }
                }

                if debug {
                    eprintln!("[DEBUG] <<< 停止連發 [{}]", state.key_str);
                }
            }
        });
        worker_handles.insert(code, join_handle.thread().clone());
    }

    let worker_handles = Arc::new(worker_handles);

    // 2. 若未指定 --no-flag，啟動低開銷背景執行緒監控開關檔案（狀態變化時即時喚醒工作執行緒）
    if !no_flag {
        let f_enabled = Arc::clone(&flag_enabled);
        let f_path = flag_file.clone();
        let workers = Arc::clone(&worker_handles);
        thread::spawn(move || {
            let mut prev = f_enabled.load(Ordering::SeqCst);
            loop {
                let exists = Path::new(&f_path).exists();
                if exists != prev {
                    f_enabled.store(exists, Ordering::SeqCst);
                    prev = exists;
                    for t in workers.values() {
                        t.unpark();
                    }
                }
                thread::sleep(Duration::from_millis(50));
            }
        });
    }

    // 3. 被動監聽物理鍵盤（不 grab、不建虛擬設備）並精準喚醒對應按鍵的工作執行緒
    let mut found_kbd = false;
    for (path, mut dev) in evdev::enumerate() {
        let name = dev.name().unwrap_or("unknown").to_string();
        if name.contains("ydotool")
            || name.contains("hl-virtual-keyboard")
            || name.contains("albion-qspam")
        {
            continue;
        }
        let is_pure_kbd = dev.supported_keys().map_or(false, |s| {
            s.contains(KeyCode::KEY_Q)
                && s.contains(KeyCode::KEY_ENTER)
                && !s.contains(KeyCode::BTN_LEFT)
        });
        if !is_pure_kbd {
            continue;
        }

        found_kbd = true;
        if debug {
            eprintln!("[DEBUG] 被動監聽鍵盤: {} ({})", name, path.display());
        }

        let kmap = Arc::clone(&key_map);
        let workers = Arc::clone(&worker_handles);
        let mods = Arc::clone(&mod_mask);

        thread::spawn(move || loop {
            match dev.fetch_events() {
                Ok(events) => {
                    for ev in events {
                        if let EventSummary::Key(_, code, val) = ev.destructure() {
                            if let Some(state) = kmap.get(&code.code()) {
                                match val {
                                    1 => {
                                        state.held.store(true, Ordering::SeqCst);
                                        state.press_seq.fetch_add(1, Ordering::SeqCst);
                                        if let Some(t) = workers.get(&code.code()) {
                                            t.unpark();
                                        }
                                    }
                                    0 => {
                                        state.held.store(false, Ordering::SeqCst);
                                        if let Some(t) = workers.get(&code.code()) {
                                            t.unpark();
                                        }
                                    }
                                    _ => {}
                                }
                            } else {
                                let bit = mod_bit(code);
                                if bit != 0 {
                                    if val == 1 {
                                        mods.fetch_or(bit, Ordering::SeqCst);
                                        for t in workers.values() {
                                            t.unpark();
                                        }
                                    } else if val == 0 {
                                        mods.fetch_and(!bit, Ordering::SeqCst);
                                        for t in workers.values() {
                                            t.unpark();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Err(_) => {
                    for state in kmap.values() {
                        state.held.store(false, Ordering::SeqCst);
                    }
                    mods.store(0, Ordering::SeqCst);
                    for t in workers.values() {
                        t.unpark();
                    }
                    break;
                }
            }
        });
    }

    if !found_kbd {
        eprintln!("未找到可用物理鍵盤設備");
        std::process::exit(1);
    }

    loop {
        thread::park();
    }
}
