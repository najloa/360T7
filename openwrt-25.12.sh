#!/bin/bash

sed -i 's/192.168.1.1/192.168.5.1/' ./package/base-files/files/bin/config_generate

# 修改 Passwall 配置
sed -i '/MetaCubeX\/geosite (CDN)"/a\	o:value("https://github.com/najloa/rules/releases/latest/download/geosite.dat", translate("najloa/geosite"))' ./package/feeds/passwall_luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/MetaCubeX\/geoip (CDN)"/a\	o:value("https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat", translate("Loyalsoldier/geoip-only-cn-private"))' ./package/feeds/passwall_luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
> ./package/feeds/passwall_luci/luci-app-passwall/root/usr/share/passwall/rules/chnlist
telegram_ips=$(curl -s https://core.telegram.org/resources/cidr.txt) && \
[ -n "$telegram_ips" ] && \
rules_file="./package/feeds/passwall_luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip" && \
awk -v ips="$telegram_ips" 'BEGIN{split(ips, a, "\n"); for(i in a) if(a[i]!="") skip[a[i]]=1} !skip[$0]' "$rules_file" > "${rules_file}.tmp" && \
echo "$telegram_ips" >> "${rules_file}.tmp" && \
mv "${rules_file}.tmp" "$rules_file"

# 替换 Go 版本
sed -i 's/GO_DEFAULT_VERSION:=1.26/GO_DEFAULT_VERSION:=1.27/g' ./feeds/packages/lang/golang/golang-values.mk

# 替换 SmartDNS 包
git clone --depth 1 -b openwrt-25.12 https://github.com/immortalwrt/packages.git immortalwrt-packages && \
rm -rf ./feeds/packages/net/smartdns && \
mkdir -p ./feeds/packages/net && \
cp -a ./immortalwrt-packages/net/smartdns ./feeds/packages/net/ && \
rm -rf ./immortalwrt-packages

git clone --depth 1 -b openwrt-25.12 https://github.com/immortalwrt/luci.git immortalwrt-luci && \
rm -rf ./feeds/luci/applications/luci-app-smartdns && \
mkdir -p ./feeds/luci/applications && \
cp -a ./immortalwrt-luci/applications/luci-app-smartdns ./feeds/luci/applications/ && \
rm -rf ./immortalwrt-luci

./scripts/feeds install -f smartdns
./scripts/feeds install -f luci-app-smartdns
