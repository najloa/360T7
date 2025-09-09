#!/bin/bash
#
# File name: diy-part3.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
sed -i 's/192.168.6.1/192.168.10.1/' ./package/base-files/files/bin/config_generate
sed -i "s/hostname='ImmortalWrt'/hostname='OpenWrt'/" ./package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt-2.4G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/36/auto/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/immortalwrt.lan/openwrt.lan/' ./feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/flash.js
sed -i 's/encryption=none/encryption=sae-mixed/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i '/encryption=sae-mixed/a \ \ \ \ set wireless.default_${dev}.key=blue1235' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
#
# find ./ -type f -name 'wrtbwmon'
# sed -i "/option enabled '1'/d" ./package/mtk/applications/wrtbwmon/net/etc/config/wrtbwmon
# rm -rf feeds/packages/net/chinadns-ng
#
# find ./ -type d -name "passwall"
# find ./ -type f -name 'rule.lua'
# find ./ -type f -name '0_default_config'
# find ./ -type f -name 'rule_update.lua'
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat|https://github.com/najloa/geoip/releases/latest/download/geoip.dat|g' ./feeds/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat|https://github.com/najloa/geoip/releases/latest/download/geosite.dat|g' ./feeds/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|translate("Loyalsoldier/geosite")|translate("najloa/geosite")|g' ./feeds/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|translate("Loyalsoldier/geoip")|translate("najloa/geoip")|g' ./feeds/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|translate("Loyalsoldier/v2ray-rules-dat")|translate("najloa/v2ray-rules-dat")|g' ./feeds/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt|https://raw.githubusercontent.com/najloa/geoip/rules/proxy-list.txt|g' ./feeds/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
#
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat|https://github.com/najloa/geoip/releases/latest/download/geoip.dat|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/0_default_config
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat|https://github.com/najloa/geoip/releases/latest/download/geosite.dat|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/0_default_config
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt|https://raw.githubusercontent.com/najloa/geoip/rules/proxy-list.txt|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/0_default_config
#
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat|https://github.com/najloa/geoip/releases/latest/download/geoip.dat|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rule_update.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat|https://github.com/najloa/geoip/releases/latest/download/geosite.dat|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rule_update.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt|https://raw.githubusercontent.com/najloa/geoip/rules/proxy-list.txt|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rule_update.lua
sed -i 's|local excluded_domain = {[^}]*}|local excluded_domain = {}|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rule_update.lua
# curl -s https://core.telegram.org/resources/cidr.txt > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip
# : > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/chnlist



    - name: Load custom passwall
      run: |
        cd openwrt
        # 删除旧包
        # find . -type d -name "*passwall*"
        # grep PKG_VERSION feeds/passwall/luci-app-passwall/Makefile
        # rm -rf ./feeds/luci/applications/luci-app-passwall
        # rm -rf ./feeds/packages/net/chinadns-ng
        # rm -rf ./feeds/packages/net/dns2socks
        # rm -rf ./feeds/packages/net/ipt2socks
        # rm -rf ./feeds/packages/net/microsocks
        # rm -rf ./feeds/packages/net/tcping
        # 指定版本
        # cd feeds/passwall && ls && git fetch --unshallow && git checkout 3466fbc849ffca621bbb141360b7b486522d4212 && cd ../../
        # sed -i '/^GO_PKG_LDFLAGS_X:=/a\GO_PKG_LDFLAGS_EXTRA := -s -w -buildid=\nGO_PKG_LDFLAGS := $(GO_PKG_LDFLAGS_X) $(GO_PKG_LDFLAGS_EXTRA)' ./feeds/passwall_packages/sing-box/Makefile
        # 强制新包
        # ./scripts/feeds install -f -p passwall luci-app-passwall
        # ./scripts/feeds install -f -p passwall_packages chinadns-ng
        # ./scripts/feeds install -f -p passwall_packages dns2socks
        # ./scripts/feeds install -f -p passwall_packages ipt2socks
        # ./scripts/feeds install -f -p passwall_packages microsocks
        # ./scripts/feeds install -f -p passwall_packages tcping
        # 替换规则
        # find . -type f -name "rule.lua"
        # sed -i 's|https://github.com/Loyalsoldier/geoip/releases/latest/download/geoip.dat|https://github.com/najloa/geoip/releases/latest/download/geoip.dat|g' ./feeds/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
        # sed -i 's|https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat|https://github.com/najloa/geoip/releases/latest/download/geosite.dat|g' ./feeds/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
        # sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt|https://github.com/najloa/geoip/releases/latest/download/proxy-list.txt|g' ./feeds/passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
        # sed -i 's|https://github.com/Loyalsoldier/geoip/releases/latest/download/geoip.dat|https://github.com/najloa/geoip/releases/latest/download/geoip.dat|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/0_default_config
        # sed -i 's|https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat|https://github.com/najloa/geoip/releases/latest/download/geosite.dat|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/0_default_config
        # sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt|https://github.com/najloa/geoip/releases/latest/download/proxy-list.txt|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/0_default_config
        # sed -i 's|https://github.com/Loyalsoldier/geoip/releases/latest/download/geoip.dat|https://github.com/najloa/geoip/releases/latest/download/geoip.dat|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rule_update.lua
        # sed -i 's|https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat|https://github.com/najloa/geoip/releases/latest/download/geosite.dat|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rule_update.lua
        # sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt|https://github.com/najloa/geoip/releases/latest/download/proxy-list.txt|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rule_update.lua
        # sed -i 's|local excluded_domain = {[^}]*}|local excluded_domain = {}|g' ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rule_update.lua
        # curl -s https://core.telegram.org/resources/cidr.txt > ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip
        # : > ./feeds/passwall/luci-app-passwall/root/usr/share/passwall/rules/proxy_host
