#!/usr/bin/env bash
cargo build --release && cp target/release/focus-netmon ~/.config/quickshell/focus-netmon ;rm target/ -rf
