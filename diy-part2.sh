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

# curl -s https://core.telegram.org/resources/cidr.txt > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip
# : > ./feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/rules/chnlist
# argon主题
find package -type d -name "*argon*"
rm -rf ./feeds/luci/applications/luci-app-argon-config
rm -rf ./feeds/luci/themes/luci-theme-argon
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config
# git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon && rm -rf ./feeds/luci/themes/luci-theme-argon && \cp -rf ./package/luci-theme-argon ./feeds/luci/themes/
# git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config && rm -rf ./feeds/luci/applications/luci-app-argon-config && \cp -rf ./package/luci-app-argon-config ./feeds/luci/applications/
# 替换背景
# \cp -f $$GITHUB_WORKSPACE/argon/bg1.jpg ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
# 替换字体
####rm -f ./package/luci-theme-argon/htdocs/luci-static/argon/fonts/TypoGraphica*
####\cp -f $GITHUB_WORKSPACE/argon/fonts/* ./package/luci-theme-argon/htdocs/luci-static/argon/fonts
####\cp -f $GITHUB_WORKSPACE/argon/cascade.css ./package/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 登录界面版本信息优化
####sed -i 's/ ([<]%=\s*ver\.luciversion\s*%>)//g' ./package/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
####sed -i '/<%= ver\.distversion %>/d' ./package/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
####sed -i 's/ |$//' ./package/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm

####sed -i 's/<%:Log in%>/<%:Login%>/' ./package/luci-theme-argon/luasrc/view/themes/argon/sysauth.htm
####sed -i 's|<%=media%>/img/argon\.svg||g' ./package/luci-theme-argon/luasrc/view/themes/argon/sysauth.htm
# golang
#git clone --depth 1 https://github.com/immortalwrt/packages.git package/immortalwrt-packages && rm -rf ./feeds/packages/lang/golang && \cp -rf ./package/immortalwrt-packages/lang/golang ./feeds/packages/lang/
