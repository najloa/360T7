#!/bin/bash
#
# File name: diy-part2.sh
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

# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone https://github.com/xiaorouji/openwrt-passwall-packages package/passwall-packages
# 移除 openwrt feeds 过时的luci版本
rm -rf feeds/luci/applications/luci-app-passwall
git clone https://github.com/xiaorouji/openwrt-passwall package/passwall-luci

# 替换规则
find . -type f -name "rule.lua"
sed -i '/ChinaMax_Domain"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/twitch-cdn.txt", translate("najloa/twitch-cdn"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/ChinaMax_Domain"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/google-cn.txt", translate("najloa/google-cn"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/ChinaMax_Domain"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/cn.txt", translate("najloa/cn"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/MetaCubeX\/geosite (CDN)"/a\	o:value("https://github.com/najloa/geoip/releases/latest/download/geosite.dat", translate("najloa/geosite"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/MetaCubeX\/geoip (CDN)"/a\	o:value("https://github.com/najloa/geoip/releases/latest/download/geoip.dat", translate("najloa/geoip"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/gfwlist\/gfwlist"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/proxy.txt", translate("najloa/proxy"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|local excluded_domain = {[^}]*}|local excluded_domain = {}|g' ./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rule_update.lua

curl -s https://core.telegram.org/resources/cidr.txt | \
grep -vxFf ./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip >> \
./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip

# argon主题
# find -type d -name "*argon*"
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config
# 替换默认背景
\cp -f $GITHUB_WORKSPACE/argon/bg1.jpg ./package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
# 替换字体
rm -f ./package/luci-theme-argon/htdocs/luci-static/argon/fonts/TypoGraphica*
\cp -f $GITHUB_WORKSPACE/argon/fonts/* ./package/luci-theme-argon/htdocs/luci-static/argon/fonts
# 修改界面
sed -i 's|@keyframes anim-fade-in|@keyframes shine{0%{background-position:-200% center;}100%{background-position:200% center;}}@keyframes anim-fade-in|g' ./package/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
sed -i 's|.main-left .sidenav-header .brand{display:block;margin:0 2rem;font-size:1.8rem;font-family:"TypoGraphica";color:var(--primary);text-decoration:none;text-align:center;cursor:default}|.main-left .sidenav-header .brand{display:block;margin:0 2rem;font-size:1.8rem;font-family:"TypoGraphica";text-decoration:none;text-align:center;cursor:default;background:linear-gradient(120deg, #00fff7, #007cf0, #ff4ecd, #00fff7);background-size:300% 300%;-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:shine 5s linear infinite;}|g' ./package/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
sed -i 's|.login-page .login-container .login-form .brand .brand-text{margin-right:45px;font-size:1.25rem;font-weight:700;font-family:"TypoGraphica";word-break:break-word}|.login-page .login-container .login-form .brand .brand-text{margin-right:45px;font-size:2.55rem;font-weight:400;font-family:"TypoGraphica",sans-serif;margin-right:45px;word-break:break-word;background:linear-gradient(120deg, #00fff7, #007cf0, #ff4ecd, #00fff7);background-size:300% 300%;-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:shine 5s linear infinite;}|g' ./package/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
sed -i 's|.login-page .login-container .login-form .cbi-button-apply{width:100% !important;min-height:50px;margin:30px 0 100px;padding:10px 0;font-size:15px;font-weight:600;color:var(--white);text-align:center;letter-spacing:.8rem;background-color:var(--primary) !important;border:none;border-radius:6px;outline:none;cursor:pointer;box-shadow:rgba(0,0,0,0.1) 0 0 50px 0;transition:all .3s ease !important}.login-page .login-container .login-form .cbi-button-apply:hover,|.login-page .login-container .login-form .cbi-button-apply{width:100% !important;min-height:45px;margin:30px 0 100px;padding:10px 0;font-size:15px;font-weight:600;text-align:center;letter-spacing:.35rem;background:rgba(0,0,0,0);backdrop-filter:blur(8px);border:none;border-radius:9999px;outline:none;cursor:pointer;transition:all 0.25s ease;position:relative}.login-page .login-container .login-form .cbi-button-apply:hover{box-shadow:0 0 0 2px rgba(255,255,255,0.5)}|g' ./package/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
sed -i 's|a:link,a:visited,a:active{color:var(--primary)|a:link,a:visited,a:active{color:#dddddd|g' ./package/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css

# 登录界面版本信息优化
sed -i '/version\.distversion/d' ./package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut
sed -i 's|https://github.com/openwrt/luci|{{ version.disturl }}|g; s|{{ version.luciname }} ({{ version.luciversion }})|Openwrt 24.10|g' ./package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut
sed -i 's|{{ media }}/img/argon\.svg||g' ./package/luci-theme-argon/ucode/template/themes/argon/sysauth.ut
sed -i 's/UHD/1920x1080/d' ./package/luci-theme-argon/root/usr/libexec/rpcd/luci.argon_wallpaper

# golang
git clone --depth 1 https://github.com/immortalwrt/packages.git package/immortalwrt-packages && rm -rf ./feeds/packages/lang/golang && \cp -rf ./package/immortalwrt-packages/lang/golang ./feeds/packages/lang/ && rm -rf ./package/immortalwrt-packages
# upx
upx --version
sed -i '/\$(1)\/usr\/bin\//a \\t-upx -6 $(1)/usr/bin/geoview' package/passwall-packages/geoview/Makefile

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
