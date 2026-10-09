#!/bin/bash

sed -i 's/192.168.1.1/192.168.6.1/' ./package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt-2.4G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# 替换规则
# find ./ -type d -iname '*passwall*'
sed -i '/MetaCubeX\/geosite (CDN)"/a\	o:value("https://github.com/najloa/geoip/releases/latest/download/geosite.dat", translate("najloa/geosite"))' ./package/feeds/passwall_luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/MetaCubeX\/geoip (CDN)"/a\	o:value("https://github.com/najloa/geoip/releases/latest/download/geoip.dat", translate("najloa/geoip"))' ./package/feeds/passwall_luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
> ./package/feeds/passwall_luci/luci-app-passwall/root/usr/share/passwall/rules/chnlist
curl -s https://core.telegram.org/resources/cidr.txt > /tmp/telegram_cidr.txt && grep -Fvxf /tmp/telegram_cidr.txt ./package/feeds/passwall_luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip > /tmp/proxy_ip_cleaned && cat /tmp/telegram_cidr.txt >> /tmp/proxy_ip_cleaned && mv /tmp/proxy_ip_cleaned ./package/feeds/passwall_luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip && rm /tmp/telegram_cidr.txt

sed -i '/\$(1)\/usr\/bin\//a \\t-upx $(1)/usr/bin/geoview' package/passwall-packages/geoview/Makefile
sed -i '/^GO_PKG_TAGS:=/,/^))$/c\GO_PKG_TAGS:=with_quic' ./package/feeds/passwall_packages/sing-box/Makefile
sed -i '38s/.*/GO_PKG_LDFLAGS:=-s -w -buildid=\nGO_PKG_LDFLAGS_X:=$(GO_PKG)\/constant.Version=$(PKG_VERSION)/' ./package/feeds/passwall_packages/sing-box/Makefile
