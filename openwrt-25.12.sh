#!/bin/bash

sed -i 's/192.168.1.1/192.168.5.1/' ./package/base-files/files/bin/config_generate

# 替换规则
#sed -i '/MetaCubeX\/geosite (CDN)"/a\	o:value("https://github.com/najloa/rules/releases/latest/download/geosite.dat", translate("najloa/geosite"))' ./package/feeds/passwall_luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
#sed -i '/MetaCubeX\/geoip (CDN)"/a\	o:value("https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat", translate("Loyalsoldier/geoip-only-cn-private"))' ./package/feeds/passwall_luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
#> ./package/feeds/passwall_luci/luci-app-passwall/root/usr/share/passwall/rules/chnlist
#curl -s https://core.telegram.org/resources/cidr.txt > /tmp/telegram_cidr.txt && grep -Fvxf /tmp/telegram_cidr.txt ./package/feeds/passwall_luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip > /tmp/proxy_ip_cleaned && cat /tmp/telegram_cidr.txt >> /tmp/proxy_ip_cleaned && mv /tmp/proxy_ip_cleaned ./package/feeds/passwall_luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip && rm /tmp/telegram_cidr.txt

#git clone --depth 1 https://github.com/openwrt/packages.git package/openwrt-packages && rm -rf ./feeds/packages/lang/golang && \cp -rf ./package/openwrt-packages/lang/golang ./feeds/packages/lang/ && rm -rf ./package/openwrt-packages
