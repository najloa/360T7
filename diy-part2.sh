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

# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone https://github.com/xiaorouji/openwrt-passwall-packages package/passwall-packages
# 移除 openwrt feeds 过时的luci版本
rm -rf feeds/luci/applications/luci-app-passwall
git clone https://github.com/xiaorouji/openwrt-passwall package/passwall-luci
# 移除 openwrt feeds 过时的luci版本
# rm -rf feeds/luci/themes/luci-theme-argon
# git clone https://github.com/jerrykuku/luci-theme-argon.git package/theme-argon

# curl -s https://core.telegram.org/resources/cidr.txt > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip
# : > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/chnlist
# argon主题
# find -type d -name "*argon*"
# git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon && rm -rf ./feeds/luci/themes/luci-theme-argon && \cp -rf ./package/luci-theme-argon ./feeds/luci/themes/ && rm -rf ./package/luci-theme-argon
# git clone https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config && rm -rf ./feeds/luci/applications/luci-app-argon-config && \cp -rf ./package/luci-app-argon-config ./feeds/luci/applications/ && rm -rf ./package/luci-app-argon-config
# 替换背景
# \cp -f $$GITHUB_WORKSPACE/argon/bg1.jpg ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
# 替换字体
rm -f ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/fonts/TypoGraphica*
\cp -f $GITHUB_WORKSPACE/argon/fonts/* ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/fonts
# \cp -f $GITHUB_WORKSPACE/argon/cascade.css ./feeds/luci/themes/luci-theme-argon/less/cascade.less
\cp -f $GITHUB_WORKSPACE/argon/cascade.css ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css

# 登录界面版本信息优化
sed -i 's/ ([<]%=\s*ver\.luciversion\s*%>)//g' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
sed -i '/<%= ver\.distversion %>/d' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
sed -i 's/ |$//' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
# sed -i 's/<%:Log in%>/<%:Login%>/' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/sysauth.htm
sed -i 's|<%=media%>/img/argon\.svg||g' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/sysauth.htm
# golang
git clone --depth 1 https://github.com/immortalwrt/packages.git package/immortalwrt-packages && rm -rf ./feeds/packages/lang/golang && \cp -rf ./package/immortalwrt-packages/lang/golang ./feeds/packages/lang/ && rm -rf ./package/immortalwrt-packages
