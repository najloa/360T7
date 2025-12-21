#!/bin/bash
#
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Add a feed source
# echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> "feeds.conf.default"
# echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> "feeds.conf.default"


      # - name: feed
      #   run: |
      #     cd immortalwrt-mt798x
      #     echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> "feeds.conf.default"
      #     echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> "feeds.conf.default"

      # - name: del
      #   run: |
      #     cd immortalwrt-mt798x
      #     rm -rf ./feeds/luci/applications/luci-app-passwall
      #     rm -rf ./feeds/packages/net/chinadns-ng
      #     rm -rf ./feeds/packages/net/dns2socks
      #     rm -rf ./feeds/packages/net/ipt2socks
      #     rm -rf ./feeds/packages/net/microsocks
      #     rm -rf ./feeds/packages/net/tcping
      #     ./scripts/feeds install -f -p passwall luci-app-passwall
      #     ./scripts/feeds install -f -p passwall_packages chinadns-ng
      #     ./scripts/feeds install -f -p passwall_packages dns2socks
      #     ./scripts/feeds install -f -p passwall_packages ipt2socks
      #     ./scripts/feeds install -f -p passwall_packages microsocks
      #     ./scripts/feeds install -f -p passwall_packages tcping
