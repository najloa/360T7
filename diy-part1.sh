#!/bin/bash

# passwall & daede
printf '%s\n' \
"src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" \
"src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main" \
"src-git openwrt_daede https://github.com/kenzok8/openwrt-daede.git;main" \
"src-git daeuniverse_packages https://github.com/daeuniverse/openwrt-packages.git;main" \
| cat - feeds.conf.default > tmp && mv tmp feeds.conf.default
echo "===== feeds.conf.default 更新成功 ====="
cat feeds.conf.default

# 主题
git clone --depth 1 https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora
git clone --depth 1 https://github.com/eamonxg/luci-app-aurora-config.git package/luci-app-aurora-config
