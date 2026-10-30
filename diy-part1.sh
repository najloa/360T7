#!/bin/bash

# Passwall & honk feeds
{
  printf '%s\n' \
    'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' \
    'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' \
    'src-git honk_packages https://github.com/daeuniverse/openwrt-packages.git;main'
  cat feeds.conf.default
} > feeds.conf.default.tmp && mv feeds.conf.default.tmp feeds.conf.default

# Aurora 主题
git clone --depth 1 https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora
git clone --depth 1 https://github.com/eamonxg/luci-app-aurora-config.git package/luci-app-aurora-config
