#!/bin/bash
#
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
sed -i 's/192.168.1.1/192.168.10.1/' ./package/base-files/files/bin/config_generate
sed -i "s/hostname='ImmortalWrt'/hostname='OpenWrt'/" ./package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt-2.4G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/36/auto/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/immortalwrt.lan/openwrt.lan/' ./feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/flash.js
sed -i 's/encryption=none/encryption=sae-mixed/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i '/encryption=sae-mixed/a \ \ \ \ set wireless.default_${dev}.key=blue1235' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
#
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
# argon主题更新
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon && rm -rf ./feeds/luci/themes/luci-theme-argon && \cp -rf ./package/luci-theme-argon ./feeds/luci/themes/
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config && rm -rf ./feeds/luci/applications/luci-app-argon-config && \cp -rf ./package/luci-app-argon-config ./feeds/luci/applications/
# argon主题美化
find ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/fonts -type f -name "*"
#sed -i 's/TypoGraphica/Monoton/' ./feeds/luci/themes/luci-theme-argon/less/fonts.less
#\cp -f $GITHUB_WORKSPACE/cascade.less ./feeds/luci/themes/luci-theme-argon/less/cascade.less
# 替换字体
rm -f ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/fonts/TypoGraphica*
\cp -f $GITHUB_WORKSPACE/argon/fonts/* ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/fonts
\cp -f $GITHUB_WORKSPACE/argon/cascade.css ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 登录界面版本信息优化
\cp -f $GITHUB_WORKSPACE/argon/footer_login.htm ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
sed -i 's/<%:Log in%>/<%:Login%>/' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/sysauth.htm
grep "cbi-button-apply" ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/sysauth.htm
