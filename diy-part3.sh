#!/bin/bash
sed -i 's/192.168.6.1/192.168.10.1/' ./package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt-2.4G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/36/auto/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/encryption=none/encryption=sae-mixed/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i '/encryption=sae-mixed/a \ \ \ \ set wireless.default_${dev}.key=blue1235' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

rm -rf ./feeds/packages/lang/golang && git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
# 移除 openwrt feeds 过时的luci版本
rm -rf feeds/luci/applications/luci-app-passwall
git clone https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci
# 替换规则
sed -i '/gfwlist\/gfwlist"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/proxy.txt", translate("najloa/proxy"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/ChinaMax_Domain"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/twitchcdn.txt", translate("najloa/twitch-cdn"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/ChinaMax_Domain"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/cn.txt", translate("najloa/cn"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/MetaCubeX\/geosite (CDN)"/a\	o:value("https://github.com/najloa/geoip/releases/latest/download/geosite.dat", translate("najloa/geosite"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/MetaCubeX\/geoip (CDN)"/a\	o:value("https://github.com/najloa/geoip/releases/latest/download/geoip.dat", translate("najloa/geoip"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|local excluded_domain = {[^}]*}|local excluded_domain = {}|g' ./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rule_update.lua
> ./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rules/chnlist
curl -s https://core.telegram.org/resources/cidr.txt > ./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip

# argon主题
# 替换默认背景
\cp -f $GITHUB_WORKSPACE/argon/bg1.jpg ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
