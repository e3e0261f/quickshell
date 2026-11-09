#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(sleep); # Perl 自带的高精度毫秒级延迟

# 关闭输出缓存，让打印更即时
$| = 1; 

print "NixOS X11 鼠标连点器已启动...\n";
print "提示：在终端按 Ctrl + C 可以随时停止连点。\n";
print "将在 3 秒后开始连点，请把鼠标移到需要点击的位置...\n";

sleep(3); # 给用户 3 秒时间准备

while (1) {
    # 核心逻辑：直接通过 system 调用 xdotool 模拟点击
    # 1 代表鼠标左键
    system("xdotool click 1");
    
    # 内存级高精度等待：0.05 秒 = 50 毫秒（每秒点击 20 次）
    sleep(0.05); 
}

