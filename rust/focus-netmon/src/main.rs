use serde::Serialize;
use std::collections::{HashMap, HashSet, VecDeque};
use std::fs;
use std::io::{Read, Write};
use std::mem;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};
use std::os::unix::io::{AsRawFd, FromRawFd, OwnedFd};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, RwLock};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const LEVEL_FILE: &str = "/tmp/netmon_level";
const PIN_FILE: &str = "/tmp/netmon_pin";

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize)]
enum Proto {
    TCP,
    UDP,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum PayloadKind {
    Empty,
    Tls,
    Cleartext,
    Mixed,
    Binary,
}

#[derive(Clone, Debug, Eq, PartialEq, Hash)]
struct PortKey {
    proto: Proto,
    port: u16,
}

#[derive(Clone, Debug, Eq, PartialEq, Hash)]
struct EndpointKey {
    proto: Proto,
    remote_ip: IpAddr,
    remote_port: u16,
}

#[derive(Clone, Debug)]
struct ProcConn {
    proto: Proto,
    remote_ip: IpAddr,
    remote_port: u16,
    state: &'static str,
}

#[derive(Default)]
struct EndpointCounters {
    tx_bytes: u64,
    rx_bytes: u64,
    tx_pkts: u64,
    rx_pkts: u64,
    state: &'static str,
    is_new: bool,
    tls_verified: bool,
    cleartext_tx: bool,
    cleartext_rx: bool,
    unsolicited_rx: bool,
    tx_times: VecDeque<Instant>,
    last_pkt_time: Option<Instant>,
    avg_payload_len: f64,
    is_beacon: bool,
}

#[derive(Clone, Serialize)]
struct PacketDigest {
    time: String,
    level: u8,
    dir: &'static str,
    unsolicited: bool,
    proto: Proto,
    remote: String,
    host: String,
    len: usize,
    dt_ms: i64,
    preview: String,
    reason: String,
}

#[derive(Default)]
struct LiveStats {
    tx_bytes: u64,
    rx_bytes: u64,
    tx_pkts: u64,
    rx_pkts: u64,
    endpoints: HashMap<EndpointKey, EndpointCounters>,
    recent_pkts: VecDeque<PacketDigest>,
    anomaly_log: VecDeque<PacketDigest>,
    known_endpoints: HashSet<EndpointKey>,
    tx_initiated_ips: HashSet<IpAddr>,
    recent_new_times: VecDeque<Instant>,
    active_pid: u32,
    active_class: String,
    active_title: String,
}

#[derive(Serialize)]
struct WindowInfo {
    pid: u32,
    class: String,
    title: String,
    proc_count: usize,
    pinned: bool,
}

#[derive(Serialize)]
struct EndpointReport {
    level: u8,
    proto: Proto,
    remote: String,
    host: String,
    state: String,
    tx_kb: f64,
    rx_kb: f64,
    pkts: u64,
    tags: Vec<String>,
}

#[derive(Serialize)]
struct MonitorSnapshot {
    mode: &'static str,
    filter_level: u8,
    window: WindowInfo,
    tx_kbps: f64,
    rx_kbps: f64,
    tx_pps: u64,
    rx_pps: u64,
    alerts: Vec<String>,
    endpoints: Vec<EndpointReport>,
    recent_packets: Vec<PacketDigest>,
    anomaly_log: Vec<PacketDigest>,
}

fn now_hms_ms() -> String {
    let d = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    let secs = d.as_secs() as libc::time_t;
    let ms = d.subsec_millis();
    let mut tm: libc::tm = unsafe { mem::zeroed() };
    unsafe {
        libc::localtime_r(&secs, &mut tm);
    }
    format!(
        "{:02}:{:02}:{:02}.{:03}",
        tm.tm_hour, tm.tm_min, tm.tm_sec, ms
    )
}

fn read_filter_level() -> u8 {
    fs::read_to_string(LEVEL_FILE)
        .ok()
        .and_then(|s| s.trim().parse::<u8>().ok())
        .map(|v| v.clamp(1, 10))
        .unwrap_or(2)
}

fn is_local_or_multicast(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => {
            let o = v4.octets();
            v4.is_loopback()
                || v4.is_private()
                || v4.is_link_local()
                || v4.is_multicast()
                || v4.is_broadcast()
                || (o[0] == 100 && (64..=127).contains(&o[1]))
        }
        IpAddr::V6(v6) => {
            v6.is_loopback()
                || v6.is_multicast()
                || (v6.segments()[0] & 0xfe00) == 0xfc00
                || (v6.segments()[0] & 0xffc0) == 0xfe80
        }
    }
}

fn is_standard_port(p: u16) -> bool {
    matches!(p, 53 | 80 | 443 | 8080 | 8443)
}

fn check_beacon(times: &VecDeque<Instant>) -> bool {
    if times.len() < 6 {
        return false;
    }
    let mut intervals = Vec::with_capacity(times.len() - 1);
    for w in times.iter().collect::<Vec<_>>().windows(2) {
        intervals.push(w[1].duration_since(*w[0]).as_secs_f64() * 1000.0);
    }
    let avg = intervals.iter().sum::<f64>() / intervals.len() as f64;
    if !(500.0..=60_000.0).contains(&avg) {
        return false;
    }
    let max_dev = intervals
        .iter()
        .map(|&x| (x - avg).abs())
        .fold(0.0_f64, f64::max);
    (max_dev / avg) < 0.18
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

fn query_active_window(sock: &Path) -> Option<(u32, String, String)> {
    let mut stream = UnixStream::connect(sock).ok()?;
    stream
        .set_read_timeout(Some(Duration::from_millis(120)))
        .ok();
    stream.write_all(b"j/activewindow").ok()?;
    let mut body = String::new();
    stream.read_to_string(&mut body).ok()?;
    let v: serde_json::Value = serde_json::from_str(&body).ok()?;
    let pid = v.get("pid")?.as_u64()? as u32;
    if pid == 0 {
        return None;
    }
    let class = v
        .get("class")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    let title = v
        .get("title")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    Some((pid, class, title))
}

fn collect_descendants(root_pid: u32) -> HashSet<u32> {
    let mut pids = HashSet::new();
    let mut stack = vec![root_pid];
    while let Some(pid) = stack.pop() {
        if !pids.insert(pid) {
            continue;
        }
        let task_dir = format!("/proc/{}/task", pid);
        if let Ok(entries) = fs::read_dir(task_dir) {
            for entry in entries.flatten() {
                if let Ok(text) = fs::read_to_string(entry.path().join("children")) {
                    for tok in text.split_whitespace() {
                        if let Ok(child) = tok.parse::<u32>() {
                            if !pids.contains(&child) {
                                stack.push(child);
                            }
                        }
                    }
                }
            }
        }
    }
    pids
}

fn collect_socket_inodes(pids: &HashSet<u32>) -> HashSet<u64> {
    let mut inodes = HashSet::new();
    for &pid in pids {
        let fd_dir = format!("/proc/{}/fd", pid);
        if let Ok(entries) = fs::read_dir(fd_dir) {
            for entry in entries.flatten() {
                if let Ok(target) = fs::read_link(entry.path()) {
                    if let Some(s) = target.to_str() {
                        if let Some(inode) = s
                            .strip_prefix("socket:[")
                            .and_then(|x| x.strip_suffix(']'))
                            .and_then(|x| x.parse::<u64>().ok())
                        {
                            inodes.insert(inode);
                        }
                    }
                }
            }
        }
    }
    inodes
}

fn parse_proc_addr(hex_addr: &str, is_v6: bool) -> Option<(IpAddr, u16)> {
    let (ip_hex, port_hex) = hex_addr.split_once(':')?;
    let port = u16::from_str_radix(port_hex, 16).ok()?;
    if !is_v6 {
        if ip_hex.len() != 8 {
            return None;
        }
        let val = u32::from_str_radix(ip_hex, 16).ok()?;
        Some((IpAddr::V4(Ipv4Addr::from(val.to_ne_bytes())), port))
    } else {
        if ip_hex.len() != 32 {
            return None;
        }
        let mut bytes = [0u8; 16];
        for i in 0..4 {
            let chunk = &ip_hex[i * 8..(i + 1) * 8];
            let w = u32::from_str_radix(chunk, 16).ok()?;
            bytes[i * 4..(i + 1) * 4].copy_from_slice(&w.to_ne_bytes());
        }
        let v6 = Ipv6Addr::from(bytes);
        if let Some(v4) = v6.to_ipv4_mapped() {
            Some((IpAddr::V4(v4), port))
        } else {
            Some((IpAddr::V6(v6), port))
        }
    }
}

fn tcp_state_name(hex_st: &str) -> &'static str {
    match hex_st {
        "01" => "ESTABLISHED",
        "02" => "SYN_SENT",
        "03" => "SYN_RECV",
        "04" => "FIN_WAIT1",
        "05" => "FIN_WAIT2",
        "06" => "TIME_WAIT",
        "07" => "CLOSE",
        "08" => "CLOSE_WAIT",
        "09" => "LAST_ACK",
        "0A" => "LISTEN",
        "0B" => "CLOSING",
        _ => "UNKNOWN",
    }
}

fn scan_proc_sockets(inodes: &HashSet<u64>) -> (HashSet<PortKey>, Vec<ProcConn>) {
    let mut watch_ports = HashSet::new();
    let mut conns = Vec::new();
    if inodes.is_empty() {
        return (watch_ports, conns);
    }

    let tables = [
        ("/proc/net/tcp", Proto::TCP, false),
        ("/proc/net/tcp6", Proto::TCP, true),
        ("/proc/net/udp", Proto::UDP, false),
        ("/proc/net/udp6", Proto::UDP, true),
    ];

    for (path, proto, is_v6) in tables {
        if let Ok(content) = fs::read_to_string(path) {
            for line in content.lines().skip(1) {
                let cols: Vec<&str> = line.split_whitespace().collect();
                if cols.len() < 10 {
                    continue;
                }
                let Ok(inode) = cols[9].parse::<u64>() else {
                    continue;
                };
                if !inodes.contains(&inode) {
                    continue;
                }
                let Some((_lip, lport)) = parse_proc_addr(cols[1], is_v6) else {
                    continue;
                };
                let Some((rip, rport)) = parse_proc_addr(cols[2], is_v6) else {
                    continue;
                };
                let state = if proto == Proto::TCP {
                    tcp_state_name(cols[3])
                } else {
                    "UDP"
                };

                if lport != 0 {
                    watch_ports.insert(PortKey { proto, port: lport });
                }
                if state != "LISTEN" && !rip.is_unspecified() {
                    conns.push(ProcConn {
                        proto,
                        remote_ip: rip,
                        remote_port: rport,
                        state,
                    });
                }
            }
        }
    }
    (watch_ports, conns)
}

fn parse_tls_sni(payload: &[u8]) -> Option<String> {
    if payload.len() < 43 || payload[0] != 0x16 || payload[5] != 0x01 {
        return None;
    }
    let mut idx = 43;
    if idx >= payload.len() {
        return None;
    }
    let sid_len = payload[idx] as usize;
    idx += 1 + sid_len;
    if idx + 2 > payload.len() {
        return None;
    }
    let cs_len = u16::from_be_bytes([payload[idx], payload[idx + 1]]) as usize;
    idx += 2 + cs_len;
    if idx + 1 > payload.len() {
        return None;
    }
    let comp_len = payload[idx] as usize;
    idx += 1 + comp_len;
    if idx + 2 > payload.len() {
        return None;
    }
    let ext_total = u16::from_be_bytes([payload[idx], payload[idx + 1]]) as usize;
    idx += 2;
    let ext_end = (idx + ext_total).min(payload.len());

    while idx + 4 <= ext_end {
        let etype = u16::from_be_bytes([payload[idx], payload[idx + 1]]);
        let elen = u16::from_be_bytes([payload[idx + 2], payload[idx + 3]]) as usize;
        idx += 4;
        if idx + elen > ext_end {
            break;
        }
        if etype == 0x0000 && elen >= 5 {
            let sni_data = &payload[idx..idx + elen];
            let name_type = sni_data[2];
            let name_len = u16::from_be_bytes([sni_data[3], sni_data[4]]) as usize;
            if name_type == 0 && 5 + name_len <= sni_data.len() {
                if let Ok(host) = std::str::from_utf8(&sni_data[5..5 + name_len]) {
                    return Some(host.to_string());
                }
            }
        }
        idx += elen;
    }
    None
}

fn read_dns_name(pkt: &[u8], mut offset: usize) -> Option<(String, usize)> {
    let mut labels = Vec::new();
    let mut jumped = false;
    let mut next_after = offset;
    let mut steps = 0;

    while offset < pkt.len() && steps < 32 {
        steps += 1;
        let len = pkt[offset];
        if len == 0 {
            if !jumped {
                next_after = offset + 1;
            }
            return Some((labels.join("."), next_after));
        }
        if (len & 0xC0) == 0xC0 {
            if offset + 1 >= pkt.len() {
                return None;
            }
            if !jumped {
                next_after = offset + 2;
            }
            offset = (((len & 0x3F) as usize) << 8) | (pkt[offset + 1] as usize);
            jumped = true;
            continue;
        }
        let l = len as usize;
        offset += 1;
        if offset + l > pkt.len() {
            return None;
        }
        if let Ok(s) = std::str::from_utf8(&pkt[offset..offset + l]) {
            labels.push(s.to_string());
        }
        offset += l;
    }
    None
}

fn parse_dns_answers(payload: &[u8], cache: &mut HashMap<IpAddr, String>) {
    if payload.len() < 12 {
        return;
    }
    let flags = u16::from_be_bytes([payload[2], payload[3]]);
    if (flags & 0x8000) == 0 {
        return;
    }
    let qdcount = u16::from_be_bytes([payload[4], payload[5]]);
    let ancount = u16::from_be_bytes([payload[6], payload[7]]);
    if ancount == 0 {
        return;
    }

    let mut idx = 12;
    let mut qname = String::new();
    for i in 0..qdcount {
        let Some((name, next)) = read_dns_name(payload, idx) else {
            return;
        };
        if i == 0 {
            qname = name;
        }
        idx = next + 4;
        if idx > payload.len() {
            return;
        }
    }

    for _ in 0..ancount {
        let Some((aname, next)) = read_dns_name(payload, idx) else {
            return;
        };
        idx = next;
        if idx + 10 > payload.len() {
            return;
        }
        let rtype = u16::from_be_bytes([payload[idx], payload[idx + 1]]);
        let rdlen = u16::from_be_bytes([payload[idx + 8], payload[idx + 9]]) as usize;
        idx += 10;
        if idx + rdlen > payload.len() {
            return;
        }
        let host = if !qname.is_empty() { &qname } else { &aname };
        if rtype == 1 && rdlen == 4 {
            let ip = IpAddr::V4(Ipv4Addr::new(
                payload[idx],
                payload[idx + 1],
                payload[idx + 2],
                payload[idx + 3],
            ));
            cache.insert(ip, host.clone());
        } else if rtype == 28 && rdlen == 16 {
            let mut b = [0u8; 16];
            b.copy_from_slice(&payload[idx..idx + 16]);
            cache.insert(IpAddr::V6(Ipv6Addr::from(b)), host.clone());
        }
        idx += rdlen;
    }
}

fn summarize_payload(payload: &[u8]) -> (String, PayloadKind) {
    if payload.is_empty() {
        return ("EMPTY".to_string(), PayloadKind::Empty);
    }
    if payload.len() >= 3
        && matches!(payload[0], 0x14..=0x17)
        && payload[1] == 0x03
        && payload[2] <= 0x04
    {
        return ("TLS".to_string(), PayloadKind::Tls);
    }
    let slice = &payload[..payload.len().min(72)];
    let mut printable = 0usize;
    let mut max_run = 0usize;
    let mut cur_run = 0usize;
    for &b in slice {
        if (0x20..=0x7e).contains(&b) {
            printable += 1;
            cur_run += 1;
            if cur_run > max_run {
                max_run = cur_run;
            }
        } else {
            cur_run = 0;
        }
    }
    let ratio = printable * 100 / slice.len();
    if ratio >= 80 && slice.len() >= 4 {
        let text: String = slice
            .iter()
            .take(56)
            .map(|&b| {
                if (0x20..=0x7e).contains(&b) {
                    b as char
                } else {
                    '.'
                }
            })
            .collect();
        return (format!("TXT \"{}\"", text), PayloadKind::Cleartext);
    }
    // 只有出現連續 >= 6 個可讀 ASCII 字符串且混雜二進制控制字節，才判定為「混合異構格式」（排除純加密隨機密文誤報）
    if max_run >= 6 && slice.len() >= 10 {
        let text: String = slice
            .iter()
            .take(40)
            .map(|&b| {
                if (0x20..=0x7e).contains(&b) {
                    b as char
                } else {
                    '.'
                }
            })
            .collect();
        let hex: Vec<String> = slice.iter().take(6).map(|b| format!("{:02x}", b)).collect();
        return (
            format!("MIX [{}] \"{}\"", hex.join(" "), text),
            PayloadKind::Mixed,
        );
    }
    let hex: Vec<String> = slice
        .iter()
        .take(12)
        .map(|b| format!("{:02x}", b))
        .collect();
    (format!("HEX {}", hex.join(" ")), PayloadKind::Binary)
}

fn open_raw_packet_socket() -> Option<OwnedFd> {
    unsafe {
        let proto = (libc::ETH_P_ALL as u16).to_be() as i32;
        let fd = libc::socket(libc::AF_PACKET, libc::SOCK_DGRAM, proto);
        if fd < 0 {
            return None;
        }
        let tv = libc::timeval {
            tv_sec: 0,
            tv_usec: 200_000,
        };
        libc::setsockopt(
            fd,
            libc::SOL_SOCKET,
            libc::SO_RCVTIMEO,
            &tv as *const _ as *const libc::c_void,
            mem::size_of::<libc::timeval>() as libc::socklen_t,
        );
        let rcvbuf: libc::c_int = 4 * 1024 * 1024;
        libc::setsockopt(
            fd,
            libc::SOL_SOCKET,
            libc::SO_RCVBUF,
            &rcvbuf as *const _ as *const libc::c_void,
            mem::size_of::<libc::c_int>() as libc::socklen_t,
        );
        Some(OwnedFd::from_raw_fd(fd))
    }
}

fn spawn_capture_thread(
    fd: OwnedFd,
    watch_ports: Arc<RwLock<HashSet<PortKey>>>,
    dns_cache: Arc<RwLock<HashMap<IpAddr, String>>>,
    stats: Arc<Mutex<LiveStats>>,
) {
    thread::spawn(move || {
        let raw_fd = fd.as_raw_fd();
        let mut buf = [0u8; 65535];
        loop {
            let mut sll: libc::sockaddr_ll = unsafe { mem::zeroed() };
            let mut addr_len = mem::size_of::<libc::sockaddr_ll>() as libc::socklen_t;
            let n = unsafe {
                libc::recvfrom(
                    raw_fd,
                    buf.as_mut_ptr() as *mut libc::c_void,
                    buf.len(),
                    0,
                    &mut sll as *mut libc::sockaddr_ll as *mut libc::sockaddr,
                    &mut addr_len,
                )
            };
            if n <= 0 {
                continue;
            }
            let pkt = &buf[..n as usize];
            let is_tx = sll.sll_pkttype == libc::PACKET_OUTGOING;

            let (src_ip, dst_ip, proto_num, l4) = match pkt[0] >> 4 {
                4 => {
                    let ihl = ((pkt[0] & 0x0F) as usize) * 4;
                    if ihl < 20 || pkt.len() < ihl {
                        continue;
                    }
                    let sip = IpAddr::V4(Ipv4Addr::new(pkt[12], pkt[13], pkt[14], pkt[15]));
                    let dip = IpAddr::V4(Ipv4Addr::new(pkt[16], pkt[17], pkt[18], pkt[19]));
                    (sip, dip, pkt[9], &pkt[ihl..])
                }
                6 => {
                    if pkt.len() < 40 {
                        continue;
                    }
                    let mut sb = [0u8; 16];
                    let mut db = [0u8; 16];
                    sb.copy_from_slice(&pkt[8..24]);
                    db.copy_from_slice(&pkt[24..40]);
                    (
                        IpAddr::V6(Ipv6Addr::from(sb)),
                        IpAddr::V6(Ipv6Addr::from(db)),
                        pkt[6],
                        &pkt[40..],
                    )
                }
                _ => continue,
            };

            let (proto, src_port, dst_port, tcp_flags, payload) = match proto_num {
                6 => {
                    if l4.len() < 20 {
                        continue;
                    }
                    let sp = u16::from_be_bytes([l4[0], l4[1]]);
                    let dp = u16::from_be_bytes([l4[2], l4[3]]);
                    let flags = l4[13];
                    let doff = ((l4[12] >> 4) as usize) * 4;
                    let pl = if doff >= 20 && l4.len() >= doff {
                        &l4[doff..]
                    } else {
                        &[]
                    };
                    (Proto::TCP, sp, dp, flags, pl)
                }
                17 => {
                    if l4.len() < 8 {
                        continue;
                    }
                    let sp = u16::from_be_bytes([l4[0], l4[1]]);
                    let dp = u16::from_be_bytes([l4[2], l4[3]]);
                    (Proto::UDP, sp, dp, 0, &l4[8..])
                }
                _ => continue,
            };

            if proto == Proto::UDP && src_port == 53 && !payload.is_empty() {
                if let Ok(mut cache) = dns_cache.write() {
                    if cache.len() > 4096 {
                        cache.clear();
                    }
                    parse_dns_answers(payload, &mut cache);
                }
            }

            let (local_port, remote_ip, remote_port) = if is_tx {
                (src_port, dst_ip, dst_port)
            } else {
                (dst_port, src_ip, src_port)
            };

            let matched = watch_ports
                .read()
                .map(|w| {
                    w.contains(&PortKey {
                        proto,
                        port: local_port,
                    })
                })
                .unwrap_or(false);
            if !matched {
                continue;
            }

            let mut sni_hit = false;
            if is_tx && proto == Proto::TCP {
                if let Some(sni) = parse_tls_sni(payload) {
                    sni_hit = true;
                    if let Ok(mut cache) = dns_cache.write() {
                        cache.insert(remote_ip, sni);
                    }
                }
            }

            let host = dns_cache
                .read()
                .ok()
                .and_then(|c| c.get(&remote_ip).cloned())
                .unwrap_or_default();

            let (mut preview, kind) = summarize_payload(payload);
            let is_empty = kind == PayloadKind::Empty;
            let is_cleartext = kind == PayloadKind::Cleartext;
            let is_mixed = kind == PayloadKind::Mixed;
            let ekey = EndpointKey {
                proto,
                remote_ip,
                remote_port,
            };

            if let Ok(mut st) = stats.lock() {
                let now = Instant::now();
                let pkt_len = pkt.len() as u64;
                if is_tx {
                    st.tx_bytes += pkt_len;
                    st.tx_pkts += 1;
                    st.tx_initiated_ips.insert(remote_ip);
                } else {
                    st.rx_bytes += pkt_len;
                    st.rx_pkts += 1;
                }

                let local_net = is_local_or_multicast(remote_ip);
                let inbound_syn = !is_tx
                    && proto == Proto::TCP
                    && (tcp_flags & 0x02 != 0)
                    && (tcp_flags & 0x10 == 0);
                let unsolicited_rx = !is_tx
                    && !local_net
                    && (!st.tx_initiated_ips.contains(&remote_ip) || inbound_syn);

                let is_new = !st.known_endpoints.contains(&ekey);
                if is_new {
                    st.known_endpoints.insert(ekey.clone());
                    if !local_net {
                        st.recent_new_times.push_back(now);
                        while let Some(&t) = st.recent_new_times.front() {
                            if now.duration_since(t) > Duration::from_secs(5) {
                                st.recent_new_times.pop_front();
                            } else {
                                break;
                            }
                        }
                    }
                }
                let port_fanout = st.recent_new_times.len() >= 8;

                let entry = st.endpoints.entry(ekey).or_default();
                if kind == PayloadKind::Tls
                    || sni_hit
                    || (proto == Proto::TCP
                        && remote_port == 443
                        && !host.is_empty()
                        && kind == PayloadKind::Binary)
                {
                    entry.tls_verified = true;
                }
                if entry.tls_verified && kind == PayloadKind::Binary {
                    preview = format!("TLS-DATA ({})", preview);
                }

                let dt_ms: i64 = entry
                    .last_pkt_time
                    .map(|prev| now.duration_since(prev).as_millis() as i64)
                    .unwrap_or(-1);
                entry.last_pkt_time = Some(now);

                let total_ep_pkts = entry.tx_pkts + entry.rx_pkts;
                let size_spike = total_ep_pkts >= 10
                    && payload.len() >= 16
                    && !entry.tls_verified
                    && ((payload.len() as f64) > entry.avg_payload_len * 3.5
                        || (entry.avg_payload_len > 200.0
                            && (payload.len() as f64) < entry.avg_payload_len * 0.2));

                if !is_empty {
                    if total_ep_pkts == 0 {
                        entry.avg_payload_len = payload.len() as f64;
                    } else {
                        entry.avg_payload_len =
                            entry.avg_payload_len * 0.85 + (payload.len() as f64) * 0.15;
                    }
                }

                if is_tx {
                    entry.tx_bytes += pkt_len;
                    entry.tx_pkts += 1;
                    if !is_empty {
                        if entry.tx_times.len() >= 12 {
                            entry.tx_times.pop_front();
                        }
                        entry.tx_times.push_back(now);
                        entry.is_beacon = check_beacon(&entry.tx_times);
                    }
                } else {
                    entry.rx_bytes += pkt_len;
                    entry.rx_pkts += 1;
                }
                if is_new {
                    entry.is_new = true;
                }
                if is_cleartext && is_tx {
                    entry.cleartext_tx = true;
                }
                if is_cleartext && !is_tx {
                    entry.cleartext_rx = true;
                }
                if unsolicited_rx {
                    entry.unsolicited_rx = true;
                }

                let std_port = is_standard_port(remote_port);
                let no_dns = !local_net && host.is_empty();
                let tx_only = entry.tx_pkts >= 5 && entry.rx_pkts == 0 && !local_net;
                let tx_heavy =
                    entry.tx_bytes > 8192 && entry.tx_bytes > entry.rx_bytes.saturating_mul(3);
                let is_beacon =
                    entry.is_beacon && (entry.rx_bytes == 0 || entry.tx_bytes > entry.rx_bytes);
                let rapid_burst = !is_empty
                    && is_tx
                    && (!std_port || host.is_empty())
                    && dt_ms >= 0
                    && dt_ms <= 2;
                let fake_443 = proto == Proto::TCP
                    && remote_port == 443
                    && !entry.tls_verified
                    && !matches!(kind, PayloadKind::Tls | PayloadKind::Empty);

                let mut level: u8 = if is_empty && !inbound_syn {
                    1
                } else if local_net {
                    2
                } else if !is_tx && std_port && (!host.is_empty() || entry.tls_verified) {
                    3
                } else if is_tx && std_port && (!host.is_empty() || entry.tls_verified) {
                    4
                } else {
                    5
                };

                let mut reasons = Vec::new();
                if inbound_syn {
                    level = 10;
                    reasons.push("外來主動建連SYN");
                } else if unsolicited_rx && !is_empty {
                    level = level.max(8);
                    reasons.push("外來主動包");
                }

                if !is_empty {
                    if !std_port && !local_net {
                        level = level.max(6);
                        reasons.push("異端口");
                    }
                    if rapid_burst && !local_net {
                        level = level.max(6);
                        reasons.push("急發連包");
                    }
                    if size_spike && !local_net {
                        level = level.max(7);
                        reasons.push("尺寸突變");
                    }
                    if tx_heavy {
                        level = level.max(6);
                        reasons.push("上傳偏高");
                    }
                    if no_dns {
                        level = level.max(7);
                        reasons.push("無域名直連");
                    }
                    if is_new && !local_net {
                        level = level.max(7);
                        reasons.push("新目標");
                    }
                    if is_mixed && !local_net && !entry.tls_verified {
                        level = level.max(8);
                        reasons.push("混合異構格式");
                    }
                    if tx_only {
                        level = level.max(8);
                        reasons.push("純上傳");
                    }
                    if fake_443 {
                        level = level.max(9);
                        reasons.push("偽裝443");
                    }
                    if is_cleartext && remote_port != 80 && !local_net {
                        level = level.max(9);
                        reasons.push(if is_tx {
                            "明文外發"
                        } else {
                            "外來明文"
                        });
                    }
                    if is_new && no_dns {
                        level = level.max(9);
                    }
                    if (is_cleartext && !std_port && !local_net)
                        || (no_dns && tx_only && entry.tx_bytes > 4096)
                        || is_beacon
                        || port_fanout
                        || (unsolicited_rx && (is_mixed || is_cleartext || !std_port))
                    {
                        level = 10;
                        if is_beacon {
                            reasons.push("週期心跳");
                        }
                        if port_fanout {
                            reasons.push("多目標發散");
                        }
                    }
                }

                let digest = PacketDigest {
                    time: now_hms_ms(),
                    level,
                    dir: if is_tx { "TX" } else { "RX" },
                    unsolicited: unsolicited_rx,
                    proto,
                    remote: format!("{}:{}", remote_ip, remote_port),
                    host,
                    len: pkt.len(),
                    dt_ms,
                    preview,
                    reason: reasons.join("+"),
                };

                if level >= 6 {
                    if st.anomaly_log.len() >= 20 {
                        st.anomaly_log.pop_front();
                    }
                    st.anomaly_log.push_back(digest.clone());
                }

                if level >= 4 || st.recent_pkts.len() < 60 || (st.tx_pkts + st.rx_pkts) % 3 == 0 {
                    if st.recent_pkts.len() >= 180 {
                        st.recent_pkts.pop_front();
                    }
                    st.recent_pkts.push_back(digest);
                }
            }
        }
    });
}

fn main() {
    let pretty = std::env::args().any(|a| a == "--pretty" || a == "-p");
    let sock_path = match hypr_socket_path() {
        Some(p) => p,
        None => {
            eprintln!("找不到 Hyprland IPC socket");
            std::process::exit(1);
        }
    };

    let watch_ports = Arc::new(RwLock::new(HashSet::<PortKey>::new()));
    let dns_cache = Arc::new(RwLock::new(HashMap::<IpAddr, String>::new()));
    let stats = Arc::new(Mutex::new(LiveStats::default()));

    let capture_mode = if let Some(fd) = open_raw_packet_socket() {
        spawn_capture_thread(
            fd,
            Arc::clone(&watch_ports),
            Arc::clone(&dns_cache),
            Arc::clone(&stats),
        );
        "raw_socket+proc"
    } else {
        eprintln!("[WARN] 無 cap_net_raw 權限，降級為 proc_only 模式");
        "proc_only"
    };

    let mut last_tick = Instant::now();

    loop {
        thread::sleep(Duration::from_millis(400));
        let dt = last_tick.elapsed().as_secs_f64().max(0.05);
        last_tick = Instant::now();

        let filter_level = read_filter_level();
        let pinned = Path::new(PIN_FILE).exists();

        let queried = query_active_window(&sock_path);
        let target = {
            let st = stats.lock().unwrap();
            if pinned && st.active_pid > 0 {
                (
                    st.active_pid,
                    st.active_class.clone(),
                    st.active_title.clone(),
                )
            } else if let Some((pid, class, title)) = queried {
                if class.to_lowercase().contains("quickshell") && st.active_pid > 0 {
                    (
                        st.active_pid,
                        st.active_class.clone(),
                        st.active_title.clone(),
                    )
                } else {
                    (pid, class, title)
                }
            } else if st.active_pid > 0 {
                (
                    st.active_pid,
                    st.active_class.clone(),
                    st.active_title.clone(),
                )
            } else {
                (0, "none".to_string(), "No active window".to_string())
            }
        };

        let (pid, class, title) = target;
        let pids = if pid > 0 {
            collect_descendants(pid)
        } else {
            HashSet::new()
        };
        let inodes = collect_socket_inodes(&pids);
        let (new_ports, proc_conns) = scan_proc_sockets(&inodes);

        if let Ok(mut wp) = watch_ports.write() {
            *wp = new_ports;
        }

        let snapshot = if let Ok(mut st) = stats.lock() {
            if st.active_pid != pid {
                st.active_pid = pid;
                st.active_class = class.clone();
                st.active_title = title.clone();
                st.endpoints.clear();
                st.recent_pkts.clear();
                st.anomaly_log.clear();
                st.known_endpoints.clear();
                st.tx_initiated_ips.clear();
                st.recent_new_times.clear();
                for c in &proc_conns {
                    if c.state == "ESTABLISHED" {
                        st.tx_initiated_ips.insert(c.remote_ip);
                    }
                }
            }

            for c in &proc_conns {
                let ek = EndpointKey {
                    proto: c.proto,
                    remote_ip: c.remote_ip,
                    remote_port: c.remote_port,
                };
                let is_new = !st.known_endpoints.contains(&ek);
                if is_new {
                    st.known_endpoints.insert(ek.clone());
                }
                let e = st.endpoints.entry(ek).or_default();
                e.state = c.state;
                if is_new {
                    e.is_new = true;
                }
            }

            let tx_kbps = (st.tx_bytes as f64 * 8.0) / 1000.0 / dt;
            let rx_kbps = (st.rx_bytes as f64 * 8.0) / 1000.0 / dt;
            let tx_pps = (st.tx_pkts as f64 / dt).round() as u64;
            let rx_pps = (st.rx_pkts as f64 / dt).round() as u64;

            let mut alerts = Vec::new();
            let high_pps = tx_pps + rx_pps > 300;
            if high_pps {
                alerts.push(format!("高頻突發 ({} pps)", tx_pps + rx_pps));
            }
            if st.tx_bytes > 16 * 1024 && st.tx_bytes > st.rx_bytes.saturating_mul(3) {
                alerts.push("整體上傳遠高於下載".to_string());
            }
            if st.recent_new_times.len() >= 8 {
                alerts.push("5秒內多目標發散建連".to_string());
            }

            let dns_ro = dns_cache.read().ok();
            let mut ep_list: Vec<EndpointReport> = st
                .endpoints
                .iter()
                .filter_map(|(k, v)| {
                    let host = dns_ro
                        .as_ref()
                        .and_then(|c| c.get(&k.remote_ip).cloned())
                        .unwrap_or_default();
                    let local_net = is_local_or_multicast(k.remote_ip);
                    let std_port = is_standard_port(k.remote_port);
                    let no_dns = !local_net && host.is_empty();
                    let tx_only = v.tx_pkts >= 5 && v.rx_pkts == 0 && !local_net;
                    let tx_heavy = v.tx_bytes > 8192 && v.tx_bytes > v.rx_bytes.saturating_mul(3);
                    let beacon = v.is_beacon && (v.rx_bytes == 0 || v.tx_bytes > v.rx_bytes);

                    let mut ep_lvl: u8 = if local_net {
                        2
                    } else if std_port && (!host.is_empty() || v.tls_verified) && !tx_heavy {
                        3
                    } else {
                        5
                    };

                    let mut tags = Vec::new();
                    if local_net {
                        tags.push("本地/組播".to_string());
                    }
                    if !std_port && !local_net {
                        ep_lvl = ep_lvl.max(6);
                        tags.push("異端口".to_string());
                    }
                    if tx_heavy {
                        ep_lvl = ep_lvl.max(6);
                        tags.push("上傳偏高".to_string());
                    }
                    if no_dns {
                        ep_lvl = ep_lvl.max(7);
                        tags.push("無域名".to_string());
                    }
                    if v.is_new && !local_net {
                        ep_lvl = ep_lvl.max(7);
                        tags.push("新目標".to_string());
                    }
                    if v.unsolicited_rx {
                        ep_lvl = ep_lvl.max(8);
                        tags.push("外來主動包".to_string());
                    }
                    if tx_only {
                        ep_lvl = ep_lvl.max(8);
                        tags.push("純上傳".to_string());
                    }
                    if high_pps && (v.tx_pkts + v.rx_pkts) > 50 {
                        ep_lvl = ep_lvl.max(8);
                        tags.push("高頻".to_string());
                    }
                    if (v.cleartext_tx || v.cleartext_rx) && k.remote_port != 80 && !local_net {
                        ep_lvl = ep_lvl.max(9);
                        tags.push(
                            if v.cleartext_rx {
                                "外來明文"
                            } else {
                                "明文外發"
                            }
                            .to_string(),
                        );
                    }
                    if v.is_new && no_dns {
                        ep_lvl = ep_lvl.max(9);
                    }
                    if ((v.cleartext_tx || v.cleartext_rx) && !std_port && !local_net)
                        || (no_dns && tx_only && v.tx_bytes > 4096)
                        || beacon
                        || (v.unsolicited_rx && !std_port)
                    {
                        ep_lvl = 10;
                        if beacon {
                            tags.push("週期心跳".to_string());
                        }
                    }

                    if ep_lvl >= 8 {
                        let label = if host.is_empty() {
                            format!("{}:{}", k.remote_ip, k.remote_port)
                        } else {
                            host.clone()
                        };
                        alerts.push(format!("Lv{} {} ({})", ep_lvl, label, tags.join("/")));
                    }

                    if ep_lvl < filter_level {
                        return None;
                    }

                    Some(EndpointReport {
                        level: ep_lvl,
                        proto: k.proto,
                        remote: format!("{}:{}", k.remote_ip, k.remote_port),
                        host,
                        state: if v.state.is_empty() {
                            "ACTIVE".to_string()
                        } else {
                            v.state.to_string()
                        },
                        tx_kb: (v.tx_bytes as f64 / 1024.0 * 10.0).round() / 10.0,
                        rx_kb: (v.rx_bytes as f64 / 1024.0 * 10.0).round() / 10.0,
                        pkts: v.tx_pkts + v.rx_pkts,
                        tags,
                    })
                })
                .collect();

            ep_list.sort_by(|a, b| b.level.cmp(&a.level).then_with(|| b.pkts.cmp(&a.pkts)));
            ep_list.truncate(40);
            alerts.truncate(4);

            let recent: Vec<PacketDigest> = st
                .recent_pkts
                .iter()
                .rev()
                .filter(|p| p.level >= filter_level)
                .take(60)
                .cloned()
                .collect();

            let anomaly_log: Vec<PacketDigest> = st.anomaly_log.iter().rev().cloned().collect();

            st.tx_bytes = 0;
            st.rx_bytes = 0;
            st.tx_pkts = 0;
            st.rx_pkts = 0;
            for v in st.endpoints.values_mut() {
                v.is_new = false;
            }

            MonitorSnapshot {
                mode: capture_mode,
                filter_level,
                window: WindowInfo {
                    pid,
                    class,
                    title,
                    proc_count: pids.len(),
                    pinned,
                },
                tx_kbps: (tx_kbps * 10.0).round() / 10.0,
                rx_kbps: (rx_kbps * 10.0).round() / 10.0,
                tx_pps,
                rx_pps,
                alerts,
                endpoints: ep_list,
                recent_packets: recent,
                anomaly_log,
            }
        } else {
            continue;
        };

        if pretty {
            println!(
                "\x1B[2J\x1B[H[{} | Lv>={}] {} (PID:{} | 子進程:{}) ↑{:.1}kbps ↓{:.1}kbps",
                snapshot.mode,
                snapshot.filter_level,
                snapshot.window.class,
                snapshot.window.pid,
                snapshot.window.proc_count,
                snapshot.tx_kbps,
                snapshot.rx_kbps
            );
            for p in &snapshot.anomaly_log {
                println!(
                    "  {} [L{}] {} {:?} {:22} len={:<4} [{}] {}",
                    p.time, p.level, p.dir, p.proto, p.remote, p.len, p.reason, p.preview
                );
            }
        } else if let Ok(line) = serde_json::to_string(&snapshot) {
            println!("{}", line);
        }
    }
}
