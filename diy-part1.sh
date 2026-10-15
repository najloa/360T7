#!/bin/bash

# passwall
printf '%s\n' \
"src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" \
"src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main" \
| cat - feeds.conf.default > tmp && mv tmp feeds.conf.default
echo "===== feeds.conf.default 更新成功 ====="
cat feeds.conf.default

# 主题
git clone https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora
