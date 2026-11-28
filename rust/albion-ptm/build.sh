#!/usr/bin/env bash
cargo build --release && cp target/release/albion-ptm ~/.config/quickshell/albion-ptm ;rm target/ -rf
