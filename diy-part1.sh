#!/bin/bash
printf '%s\n' \
"src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" \
"src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main" \
"src-git openwrt_smartdns https://github.com/pymumu/openwrt-smartdns.git;master" \
"src-git luci_app_smartdns https://github.com/pymumu/luci-app-smartdns.git;master" \
| cat - feeds.conf.default > tmp && mv tmp feeds.conf.default
echo "===== feeds.conf.default 更新成功 ====="
cat feeds.conf.default
