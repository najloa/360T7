#!/bin/bash
#
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
# find . -type d -name "passwall"
sed -i 's/3/7/' package/network/services/ppp/files/lib/netifd/ppp-down
sed -i 's/192.168.1.1/192.168.10.1/' package/base-files/files/bin/config_generate
sed -i "s/hostname='[^']*'/hostname='OpenWrt'/" package/base-files/files/bin/config_generate
sed -i 's/immortalwrt.lan/OpenWrt.lan/' feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/flash.js
grep ".lan" ./feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/flash.js
cat /proc/version
sed -i 's/ImmortalWrt-2.4G/NW2.4G/' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/NW/' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-6G/NW6G/' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/encryption=none/encryption=sae-mixed/' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i '/encryption=sae-mixed/a \ \ \ \ set wireless.default_${dev}.key=blue1235' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
#passwall
git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall-packages.git package/passwall-packages
#passwall2
#git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall2.git package/passwall2
#sed -i 's/+xray-core*[ ]//g; s/[ ]*+v2ray-geoip//g; s/[ ]*+v2ray-geosite//g' package/passwall2/luci-app-passwall2/Makefile
#sed -i 's|https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest|https://api.github.com/repos/najloa/geoip/releases/latest|g' package/passwall2/luci-app-passwall2/luasrc/model/cbi/passwall2/client/rule.lua
#sed -i 's|https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest|https://api.github.com/repos/najloa/geoip/releases/latest|g' package/passwall2/luci-app-passwall2/root/usr/share/passwall2/rule_update.lua
#passwall
git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall.git package/passwall
rm -rf ./feeds/luci/applications/luci-app-passwall && \cp -rf ./package/passwall/luci-app-passwall ./feeds/luci/applications/
rm -rf ./feeds/packages/net/chinadns-ng && \cp -rf ./package/passwall-packages/chinadns-ng ./feeds/packages/net/
rm -rf ./feeds/packages/net/dns2socks && \cp -rf ./package/passwall-packages/dns2socks ./feeds/packages/net/
rm -rf ./feeds/packages/net/ipt2socks && \cp -rf ./package/passwall-packages/ipt2socks ./feeds/packages/net/
rm -rf ./feeds/packages/net/microsocks && \cp -rf ./package/passwall-packages/microsocks ./feeds/packages/net/
rm -rf ./feeds/packages/net/tcping && \cp -rf ./package/passwall-packages/tcping ./feeds/packages/net/
rm -rf ./feeds/packages/net/sing-box && \cp -rf ./package/passwall-packages/sing-box ./feeds/packages/net/
rm -rf ./feeds/packages/net/xray-core && \cp -rf ./package/passwall-packages/xray-core ./feeds/packages/net/
rm -rf ./feeds/packages/net/v2ray-geodata && \cp -rf ./package/passwall-packages/v2ray-geodata ./feeds/packages/net/
rm -rf ./feeds/packages/net/v2ray-plugin && \cp -rf ./package/passwall-packages/v2ray-plugin ./feeds/packages/net/
rm -rf ./feeds/packages/net/hysteria && \cp -rf ./package/passwall-packages/hysteria ./feeds/packages/net/
rm -rf ./feeds/packages/net/naiveproxy && \cp -rf ./package/passwall-packages/naiveproxy ./feeds/packages/net/
rm -rf ./feeds/packages/net/shadowsocks-libev && \cp -rf ./package/passwall-packages/shadowsocks-libev ./feeds/packages/net/
rm -rf ./feeds/packages/net/shadowsocks-rust && \cp -rf ./package/passwall-packages/shadowsocks-rust ./feeds/packages/net/
rm -rf ./feeds/packages/net/shadowsocksr-libev && \cp -rf ./package/passwall-packages/shadowsocksr-libev ./feeds/packages/net/
rm -rf ./feeds/packages/net/simple-obfs && \cp -rf ./package/passwall-packages/simple-obfs ./feeds/packages/net/
rm -rf ./feeds/packages/net/trojan-plus && \cp -rf ./package/passwall-packages/trojan-plus ./feeds/packages/net/
rm -rf ./feeds/packages/net/tuic-client && \cp -rf ./package/passwall-packages/tuic-client ./feeds/packages/net/
rm -rf ./feeds/packages/net/xray-plugin && \cp -rf ./package/passwall-packages/xray-plugin ./feeds/packages/net/
\cp -rf ./package/passwall-packages/geoview ./feeds/packages/net/
# 修改 ./feeds/luci/applications/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat|https://github.com/najloa/geoip/releases/latest/download/geoip.dat|g' ./feeds/luci/applications/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat|https://github.com/najloa/geoip/releases/latest/download/geosite.dat|g' ./feeds/luci/applications/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|translate("Loyalsoldier/geosite")|translate("najloa/geosite")|g' ./feeds/luci/applications/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|translate("Loyalsoldier/geoip")|translate("najloa/geoip")|g' ./feeds/luci/applications/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|translate("Loyalsoldier/v2ray-rules-dat")|translate("najloa/v2ray-rules-dat")|g' ./feeds/luci/applications/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt|https://raw.githubusercontent.com/najloa/geoip/rules/proxy-list.txt|g' ./feeds/luci/applications/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
# 修改 ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/0_default_config
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat|https://github.com/najloa/geoip/releases/latest/download/geoip.dat|g' ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/0_default_config
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat|https://github.com/najloa/geoip/releases/latest/download/geosite.dat|g' ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/0_default_config
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt|https://raw.githubusercontent.com/najloa/geoip/rules/proxy-list.txt|g' ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/0_default_config
# 修改 ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rule_update.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat|https://github.com/najloa/geoip/releases/latest/download/geoip.dat|g' ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rule_update.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat|https://github.com/najloa/geoip/releases/latest/download/geosite.dat|g' ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rule_update.lua
sed -i 's|https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt|https://raw.githubusercontent.com/najloa/geoip/rules/proxy-list.txt|g' ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rule_update.lua
sed -i 's|local excluded_domain = {[^}]*}|local excluded_domain = {}|g' ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rule_update.lua
curl -s https://core.telegram.org/resources/cidr.txt > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip
: > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/chnlist
: > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/proxy_host
: > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/direct_host
: > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/direct_ip
# echo "路径为：$GITHUB_WORKSPACE"
# 更新 argon主题
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
# 更新 go
git clone --depth 1 https://github.com/immortalwrt/packages.git package/immortalwrt-packages && rm -rf ./feeds/packages/lang/golang && \cp -rf ./package/immortalwrt-packages/lang/golang ./feeds/packages/lang/
# 更新 haproxy
cd ./package/immortalwrt-packages && git fetch origin 0c43aa312737634bd564c1ea46e74582c4bdf550 && git checkout 0c43aa312737634bd564c1ea46e74582c4bdf550 && cd .. && cd .. && rm -rf ./feeds/packages/net/haproxy && \cp -rf ./package/immortalwrt-packages/net/haproxy ./feeds/packages/net/ && rm -rf ./package/immortalwrt-packages
