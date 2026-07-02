#!/bin/bash
printf '%s\n' \
"src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" \
"src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main" \
| cat - feeds.conf.default > tmp && mv tmp feeds.conf.default
echo "===== feeds.conf.default 内容如下 ====="
cat feeds.conf.default
