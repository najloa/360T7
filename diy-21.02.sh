#!/bin/bash

sed -i 's/192.168.1.1/192.168.6.1/' ./package/base-files/files/bin/config_generate
#sed -i 's/ImmortalWrt-2.4G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
#sed -i 's/ImmortalWrt-5G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
#sed -i 's/ImmortalWrt-6G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
#sed -i 's/encryption=none/encryption=sae-mixed/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
#sed -i '/encryption=sae-mixed/a \ \ \ \ set wireless.default_${dev}.key=blue1235' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# sed -i "s/hostname='ImmortalWrt'/hostname='OpenWrt'/" ./package/base-files/files/bin/config_generate
# sed -i 's/immortalwrt.lan/openwrt.lan/' ./feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/flash.js
# sed -i 's/ImmortalWrt/OpenWrt/' ./config/Config-images.in
# sed -i 's/"ImmortalWrt"/"OpenWrt"/' ./package/base-files/image-config.in
# sed -i 's/ImmortalWrt/OpenWrt/' ./package/kernel/mac80211/files/lib/wifi/mac80211.sh
# sed -i 's/ImmortalWrt/OpenWrt/' ./package/mtk/applications/luci-app-mtwifi-cfg/root/usr/share/luci-app-mtwifi-cfg/wireless-mtk.js

# 替换规则
find ./ -type d -iname '*passwall*'
sed -i '/gfwlist\/gfwlist"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/proxy.txt", translate("najloa/proxy"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
# sed -i '/ChinaMax_Domain"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/cdn.txt", translate("najloa/cdn"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/ChinaMax_Domain"/a\o:value("https://github.com/najloa/geoip/releases/latest/download/cn.txt", translate("najloa/cn"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/MetaCubeX\/geosite (CDN)"/a\	o:value("https://github.com/najloa/geoip/releases/latest/download/geosite.dat", translate("najloa/geosite"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i '/MetaCubeX\/geoip (CDN)"/a\	o:value("https://github.com/najloa/geoip/releases/latest/download/geoip.dat", translate("najloa/geoip"))' ./package/passwall-luci/luci-app-passwall/luasrc/model/cbi/passwall/client/rule.lua
sed -i 's|local excluded_domain = {[^}]*}|local excluded_domain = {}|g' ./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rule_update.lua
> ./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rules/chnlist
curl -s https://core.telegram.org/resources/cidr.txt > /tmp/telegram_cidr.txt && grep -Fvxf /tmp/telegram_cidr.txt ./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip > /tmp/proxy_ip_cleaned && cat /tmp/telegram_cidr.txt >> /tmp/proxy_ip_cleaned && mv /tmp/proxy_ip_cleaned ./package/passwall-luci/luci-app-passwall/root/usr/share/passwall/rules/proxy_ip && rm /tmp/telegram_cidr.txt

# argon主题 https://github.com/immortalwrt/luci/tree/openwrt-21.02/themes/luci-theme-argon
# 替换默认背景
#\cp -f $GITHUB_WORKSPACE/argon/bg1.jpg ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
# 替换字体
#rm -f ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/fonts/TypoGraphica*
#\cp -f $GITHUB_WORKSPACE/argon/fonts/* ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/fonts
# 修改界面
# 多彩效果
#sed -i 's|@keyframes anim-fade-in|@keyframes shine{0%{background-position:-200% center;}100%{background-position:200% center;}}@keyframes anim-fade-in|g' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 主页标识
#sed -i 's|.main-left .sidenav-header .brand{display:block;font-size:1.8rem;color:#5e72e4;color:var(--primary);font-family:"TypoGraphica";text-decoration:none;text-align:center;cursor:default;margin:0 2rem}|.main-left .sidenav-header .brand{display:block;margin:0;font-size:1.8rem;font-family:"TypoGraphica";text-decoration:none;text-align:center;cursor:default;background:linear-gradient(120deg, #00fff7, #007cf0, #ff4ecd, #00fff7);background-size:300% 300%;-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:shine 5s linear infinite;}|g' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 登录页标识
# 居中
#sed -i 's|.login-page .login-container .login-form .brand{display:flex;-webkit-box-align:center;align-items:center;margin:50px auto 100px 50px;color:#525461;color:var(--default);justify-content:center}|.login-page .login-container .login-form .brand{display:flex;align-items:center;justify-content:center;margin:50px auto 100px auto;color:var(--default);}|g' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 删除图标
#sed -i 's|.login-page .login-container .login-form .brand .icon{width:50px;height:auto;margin-right:25px}||g' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
#sed -i 's|.login-page .login-container .login-form .brand .brand-text{font-size:1.25rem;font-weight:700;font-family:"TypoGraphica"}|.login-page .login-container .login-form .brand .brand-text{margin-right:0px;font-size:2.6rem;font-weight:400;font-family:"TypoGraphica",sans-serif;word-break:break-word;background:linear-gradient(120deg, #00fff7, #007cf0, #ff4ecd, #00fff7);background-size:300% 300%;-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:shine 5s linear infinite;}|g' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
#sed -i 's|.login-page .login-container .login-form .cbi-button-apply{width:100% !important;box-shadow:rgba(0,0,0,0.1) 0 0 50px 0;font-weight:600;font-size:15px;color:#fff;color:var(--white);text-align:center;width:100%;cursor:pointer;min-height:50px;background-color:#5e72e4 !important;background-color:var(--primary) !important;border-radius:6px;outline:none;border-width:initial;border-style:none;border-color:initial;border-image:initial;padding:10px 0px;margin:30px 0px 100px;transition:all .3s !important;letter-spacing:.8rem}.login-page .login-container .login-form .cbi-button-apply:hover,|.login-page .login-container .login-form .cbi-button-apply{width:100% !important;min-height:45px;margin:30px 0 100px;padding:10px 0;font-size:15px;font-weight:600;text-align:center;letter-spacing:.35rem;background:rgba(0,0,0,0);backdrop-filter:blur(8px);border:none;border-radius:9999px;outline:none;cursor:pointer;transition:all 0.25s ease;position:relative}.login-page .login-container .login-form .cbi-button-apply:hover{box-shadow:0 0 0 2px rgba(255,255,255,0.5)}|g' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 底部
#sed -i 's|a:link,a:visited,a:active{color:#5e72e4;color:var(--primary)|a:link,a:visited,a:active{color:#dddddd|g' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 登录界面版本信息优化
#sed -i 's|<%= ver.luciname %> (<%= ver.luciversion %>)|Openwrt 21.02|g' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
# sed -i 's/ (<%= ver\.luciversion %>)//g' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
#sed -i 's/[[:space:]]*<%= ver\.distversion %>[[:space:]]*//g' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
#sed -i 's#</a>[[:space:]]*/[[:space:]]*#</a>#g' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
#sed -i 's|<%=media%>/img/argon\.svg||g' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/sysauth.htm
# find . -type f -name "luci.mk"
# sed -i 's/LuCI \$\$branch branch/LuCI \$\$branch/' ./feeds/luci/luci.mk
# sed -i 's/<%:Log in%>/<%:Login%>/' ./feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/sysauth.htm

# golang
rm -rf ./feeds/packages/lang/golang && git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
# git clone --depth 1 https://github.com/immortalwrt/packages.git package/immortalwrt-packages && rm -rf ./feeds/packages/lang/golang && \cp -rf ./package/immortalwrt-packages/lang/golang ./feeds/packages/lang/ && rm -rf ./package/immortalwrt-packages
# upx
# upx --version
# sed -i '/\$(1)\/usr\/bin\//a \\t-upx $(1)/usr/bin/geoview' package/passwall-packages/geoview/Makefile
# sed -i '/\$(1)\/usr\/bin\//a \\t-upx $(1)/usr/bin/xray' package/passwall-packages/xray-core/Makefile
# sed -i '/define Package\/sing-box\/install/a \\\tupx $(1)/usr/bin/sing-box' package/passwall-packages/sing-box/Makefile
