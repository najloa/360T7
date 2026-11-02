#!/bin/bash
echo "Firmware version: $FIRMWARE_VERSION"
# Default
sed -i '/192\.168\.1\.1/s/192\.168\.1\.1/192.168.5.1/g' \
    ./package/base-files/files/bin/config_generate

sed -i \
    -e "s/timezone='GMT0'/timezone='CST-8'/" \
    -e "s/zonename='UTC'/zonename='Asia\/Shanghai'/" \
    ./package/base-files/files/bin/config_generate

# 修改 Passwall
if [ "$FIRMWARE_VERSION" = "openwrt-25.12" ]; then
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
# sed -i 's/GO_DEFAULT_VERSION:=1.26/GO_DEFAULT_VERSION:=1.27/g' ./feeds/packages/lang/golang/golang-values.mk
fi

# 替换 SmartDNS
git clone --depth 1 -b master https://github.com/immortalwrt/packages.git immortalwrt-packages && \
rm -rf ./feeds/packages/net/smartdns && \
mkdir -p ./feeds/packages/net && \
cp -a ./immortalwrt-packages/net/smartdns ./feeds/packages/net/ && \
rm -rf ./immortalwrt-packages

git clone --depth 1 -b master https://github.com/immortalwrt/luci.git immortalwrt-luci && \
rm -rf ./feeds/luci/applications/luci-app-smartdns && \
mkdir -p ./feeds/luci/applications && \
cp -a ./immortalwrt-luci/applications/luci-app-smartdns ./feeds/luci/applications/ && \
rm -rf ./immortalwrt-luci

./scripts/feeds install -f smartdns
./scripts/feeds install -f luci-app-smartdns

# 为 dae 和 honk 移除 v2ray
sed -i 's/ +v2ray-geoip +v2ray-geosite//' ./feeds/honk_packages/dae/Makefile ./feeds/honk_packages/honk/Makefile

# 内核配置写入函数
set_kernel_config() {
    local option="$1"
    local value="$2"

    sed -i -E \
        "/^# ${option} is not set$/d; /^${option}=/d" \
        "$CONFIG_FILE"

    echo "${option}=${value}" >> "$CONFIG_FILE"
}

# dae 专属配置
if [ "$FIRMWARE_VERSION" = "openwrt-25.12-dae" ]; then
    CONFIG_FILE=$(find target/linux/mediatek/filogic -maxdepth 1 -name 'config-6.*' | sort -V | tail -n 1)

    set_kernel_config CONFIG_NETKIT y
    set_kernel_config CONFIG_NET_SCH_INGRESS m
    set_kernel_config CONFIG_NET_CLS_BPF m
    set_kernel_config CONFIG_NET_CLS_ACT y
    set_kernel_config CONFIG_BPF_STREAM_PARSER y

    # dae 源码目录
    DAE_DIR="$PWD/feeds/honk_packages/dae"
    
    # 仅在配置中启用了 dae 时准备源码
    if grep -qx 'CONFIG_PACKAGE_dae=y' .config; then
    
        # 从 Makefile 获取 dae 版本
        DAE_VERSION=$(sed -n \
            's/^PKG_VERSION:=$(if $(DAE_VERSION),$(DAE_VERSION),\([^)]*\))$/\1/p' \
            "$DAE_DIR/Makefile")
    
        if [ -z "$DAE_VERSION" ]; then
            echo "Error: Failed to determine DAE_VERSION"
            exit 1
        fi
    
        DAE_TAG="v${DAE_VERSION}"
    
        echo "Preparing dae source: $DAE_TAG"
    
        git clone --depth 1 --recurse-submodules \
            --branch "$DAE_TAG" \
            https://github.com/daeuniverse/dae.git \
            "$DAE_DIR/src"
    fi
fi

# honk 专属配置
if [ "$FIRMWARE_VERSION" = "openwrt-main-honk" ]; then
    CONFIG_FILE=$(find target/linux/mediatek/filogic -maxdepth 1 -name 'config-6.*' | sort -V | tail -n 1)

    for option in \
        CONFIG_NET_CLS_ACT \
        CONFIG_NETKIT \
        CONFIG_NF_TABLES_INET \
        CONFIG_NF_CONNTRACK \
        CONFIG_NETFILTER_ADVANCED
    do
        set_kernel_config "$option" y
    done

    for option in \
        CONFIG_NF_TABLES \
        CONFIG_NFT_CT \
        CONFIG_NFT_QUEUE \
        CONFIG_NETFILTER_NETLINK_QUEUE
    do
        set_kernel_config "$option" m
    done

    # honk 源码目录
    HONK_DIR="$PWD/feeds/honk_packages/honk"

    # 仅在配置中启用了 honk 时准备源码和编译环境
    if grep -qx 'CONFIG_PACKAGE_honk=y' .config; then

        # Prepare honk source
        HONK_TAG=$(sed -n \
            's/^HONK_GIT_TAG:=$(if $(HONK_GIT_TAG),$(HONK_GIT_TAG),\([^)]*\))$/\1/p' \
            "$HONK_DIR/Makefile")

        if [ -z "$HONK_TAG" ]; then
            echo "Error: Failed to determine HONK_GIT_TAG"
            exit 1
        fi

        echo "Preparing honk source: $HONK_TAG"

        git clone --depth 1 --branch "$HONK_TAG" \
            https://github.com/daeuniverse/honk.git \
            "$HONK_DIR/src"

        # Prepare honk build environment
        HONK_SRC="$HONK_DIR/src"
        CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
        export CARGO_HOME
        export PATH="$CARGO_HOME/bin:$PATH"

        # Install rustup if missing
        if ! command -v rustup >/dev/null 2>&1; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
                | sh -s -- -y --profile minimal --default-toolchain none
        fi

        # Read pinned toolchain versions
        STABLE_TOOLCHAIN=$(sed -n \
            's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
            "$HONK_SRC/rust-toolchain.toml" | head -n1)

        NIGHTLY_TOOLCHAIN=$(sed -n \
            's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
            "$HONK_SRC/crates/honk-ebpf/rust-toolchain.toml" | head -n1)

        if [ -z "$STABLE_TOOLCHAIN" ] || [ -z "$NIGHTLY_TOOLCHAIN" ]; then
            echo "Error: Failed to read honk Rust toolchain versions"
            exit 1
        fi

        # Install stable Rust and the OpenWrt target standard library
        rustup toolchain install "$STABLE_TOOLCHAIN" \
            --profile minimal --component rustfmt --component clippy

        rustup target add --toolchain "$STABLE_TOOLCHAIN" \
            aarch64-unknown-linux-musl

        # Install nightly Rust for eBPF compilation
        rustup toolchain install "$NIGHTLY_TOOLCHAIN" \
            --profile minimal --component rust-src --component llvm-tools

        # Install the pinned bpf-linker
        sudo apt-get install -y zstd

        source "$HONK_SRC/.github/ci/pins.env"

        mkdir -p "$CARGO_HOME/bin"

        curl -fsSL --retry 3 \
            -o "$RUNNER_TEMP/bpf-linker.tar.zst" \
            "https://github.com/aya-rs/bpf-linker/releases/download/v${BPF_LINKER_VERSION}/bpf-linker-x86_64-unknown-linux-musl.tar.zst"

        echo "${BPF_LINKER_SHA256}  $RUNNER_TEMP/bpf-linker.tar.zst" \
            | sha256sum -c -

        zstd -dc "$RUNNER_TEMP/bpf-linker.tar.zst" \
            | tar -xf - -C "$CARGO_HOME/bin"

        chmod +x "$CARGO_HOME/bin/bpf-linker"

        # Make Cargo and bpf-linker available in subsequent workflow steps
        echo "$CARGO_HOME/bin" >> "$GITHUB_PATH"

        echo "honk Rust build environment ready"
        rustc "+$STABLE_TOOLCHAIN" --version
        rustc "+$NIGHTLY_TOOLCHAIN" --version
        bpf-linker --version
    fi
fi

# ==========================================
# GeoIP / GeoSite 更新功能
# ==========================================

set -e

# 自动定位 feed 中的三个包
find_package_dir() {
    find feeds -path "*/$1/Makefile" -print -quit 2>/dev/null |
        sed 's#/Makefile$##'
}

LIB_DIR="$(find_package_dir luci-lib-daeuniverse)"
DAE_DIR="$(find_package_dir luci-app-dae)"
HONK_DIR="$(find_package_dir luci-app-honk)"

if [ -z "$LIB_DIR" ] || [ -z "$DAE_DIR" ] || [ -z "$HONK_DIR" ]; then
    echo "错误：找不到 luci-lib-daeuniverse、luci-app-dae 或 luci-app-honk"
    exit 1
fi

JS="$LIB_DIR/htdocs/luci-static/resources/daeuniverse/service.js"
ACL_DAE="$DAE_DIR/root/usr/share/rpcd/acl.d/luci-app-dae.json"
ACL_HONK="$HONK_DIR/root/usr/share/rpcd/acl.d/luci-app-honk.json"
GEO="$LIB_DIR/root/usr/libexec/daeuniverse-geo"

for f in "$JS" "$ACL_DAE" "$ACL_HONK"; do
    [ -f "$f" ] || {
        echo "错误：找不到文件 $f"
        exit 1
    }
done

# 新增 GeoIP / GeoSite 后端脚本
mkdir -p "$(dirname "$GEO")"

cat > "$GEO" <<'EOF'
#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
umask 077

. /usr/share/libubox/jshn.sh

CONFIG='daeuniverse-geo'
SECTION='config'
DIR='/usr/share/v2ray'
CRON='/etc/crontabs/root'
LOCK='/var/lock/daeuniverse-geo.lock'

DEFAULT_GEOIP='https://gh-proxy.com/https://raw.githubusercontent.com/najloa/rules/release/geoip.dat'
DEFAULT_GEOSITE='https://gh-proxy.com/https://raw.githubusercontent.com/najloa/rules/release/geosite.dat'

fail() {
    echo "$*" >&2
    exit 1
}

init_config() {
    if ! uci -q get "$CONFIG.$SECTION" >/dev/null 2>&1; then
        uci -q set "$CONFIG.$SECTION=geo"
    fi

    [ -n "$(uci -q get "$CONFIG.$SECTION.geoip_url")" ] ||
        uci -q set "$CONFIG.$SECTION.geoip_url=$DEFAULT_GEOIP"

    [ -n "$(uci -q get "$CONFIG.$SECTION.geosite_url")" ] ||
        uci -q set "$CONFIG.$SECTION.geosite_url=$DEFAULT_GEOSITE"

    [ -n "$(uci -q get "$CONFIG.$SECTION.auto_update")" ] ||
        uci -q set "$CONFIG.$SECTION.auto_update=0"

    uci -q commit "$CONFIG"
}

get_url() {
    uci -q get "$CONFIG.$SECTION.$1_url"
}

valid_url() {
    case "$1" in
        https://*|http://*) return 0 ;;
        *) return 1 ;;
    esac
}

json_status() {
    json_init

    for kind in geoip geosite; do
        file="$DIR/$kind.dat"

        if [ -s "$file" ]; then
            json_add_boolean "${kind}_exists" 1
            json_add_int "${kind}_size" "$(wc -c < "$file")"
            json_add_string "${kind}_mtime" \
                "$(date -r "$file" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '-')"
        else
            json_add_boolean "${kind}_exists" 0
            json_add_int "${kind}_size" 0
            json_add_string "${kind}_mtime" '-'
        fi

        json_add_string "${kind}_url" "$(get_url "$kind")"
    done

    json_add_boolean auto_update \
        "$(uci -q get "$CONFIG.$SECTION.auto_update" || echo 0)"

    json_dump
}

update_one() {
    kind="$1"

    case "$kind" in
        geoip|geosite) ;;
        *) fail 'Invalid database name.' ;;
    esac

    url="$(get_url "$kind")"
    valid_url "$url" || fail "Invalid $kind URL."

    mkdir -p "$DIR" || fail "Cannot create $DIR."

    tmp="$(mktemp "$DIR/.$kind.dat.XXXXXX")" ||
        fail 'Cannot create temporary file.'

    if ! curl -fL --retry 2 --connect-timeout 15 --max-time 300 \
        "$url" -o "$tmp"; then
        rm -f "$tmp"
        fail "$kind download failed; existing file was kept."
    fi

    # 基本文件检查：非空、至少 1 KB、不是明显的 HTML 错误页面
    if [ ! -s "$tmp" ] ||
        [ "$(wc -c < "$tmp")" -lt 1024 ] ||
        head -c 512 "$tmp" |
            grep -Eiq '<!doctype[[:space:]]+html|<html'; then
        rm -f "$tmp"
        fail "$kind validation failed; existing file was kept."
    fi

    chmod 0644 "$tmp"

    if ! mv -f "$tmp" "$DIR/$kind.dat"; then
        rm -f "$tmp"
        fail "$kind replacement failed; existing file was kept."
    fi

    echo "$kind updated successfully."
}

set_url() {
    kind="$1"
    url="$2"

    case "$kind" in
        geoip|geosite) ;;
        *) fail 'Invalid database name.' ;;
    esac

    valid_url "$url" || fail 'URL must start with http:// or https://.'

    uci -q set "$CONFIG.$SECTION.${kind}_url=$url" ||
        fail 'Unable to save URL.'

    uci -q commit "$CONFIG" || fail 'Unable to commit URL.'
    echo 'URL saved.'
}

set_auto() {
    value="$1"

    case "$value" in
        0|1) ;;
        *) fail 'Invalid auto-update value.' ;;
    esac

    uci -q set "$CONFIG.$SECTION.auto_update=$value"
    uci -q commit "$CONFIG" || fail 'Unable to save auto-update setting.'

    mkdir -p /etc/crontabs
    touch "$CRON"

    tmp="$(mktemp /tmp/daeuniverse-geo-cron.XXXXXX)" ||
        fail 'Cannot create cron temporary file.'

    grep -vF '/usr/libexec/daeuniverse-geo update-all' "$CRON" > "$tmp" || true

    if [ "$value" = 1 ]; then
        echo '0 4 * * * /usr/libexec/daeuniverse-geo update-all' >> "$tmp"
    fi

    cat "$tmp" > "$CRON"
    rm -f "$tmp"

    /etc/init.d/cron restart >/dev/null 2>&1 || true
    echo 'Auto-update setting saved.'
}

init_config

case "$1" in
    status)
        json_status
        ;;
    update)
        [ "$#" -eq 2 ] || fail 'Usage: update geoip|geosite'
        exec 9>"$LOCK"
        flock -x 9 || fail 'Cannot acquire update lock.'
        update_one "$2"
        ;;
    update-all)
        exec 9>"$LOCK"
        flock -x 9 || fail 'Cannot acquire update lock.'
        update_one geoip && update_one geosite
        ;;
    set-url)
        [ "$#" -eq 3 ] || fail 'Usage: set-url geoip|geosite URL'
        set_url "$2" "$3"
        ;;
    set-auto)
        [ "$#" -eq 2 ] || fail 'Usage: set-auto 0|1'
        set_auto "$2"
        ;;
    *)
        fail 'Commands: status, update, update-all, set-url, set-auto'
        ;;
esac
EOF

chmod 0755 "$GEO"

# 修改共享 LuCI 页面
python3 - "$JS" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()

def replace_once(old, new, label):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(
            f"{label}: 预期匹配 1 次，实际 {count} 次；停止修改 service.js。"
        )
    s = s.replace(old, new, 1)

methods = r'''
        /* GeoIP / GeoSite databases */
        async geoCommand(args) {
                const result = await fs.exec('/usr/libexec/daeuniverse-geo', args);
                if (result.code !== 0)
                        throw new Error((result.stderr || result.stdout ||
                                _('Geo database operation failed.')).trim());
                return (result.stdout || '').trim();
        },

        async updateGeoStatus() {
                try {
                        const data = JSON.parse(await this.geoCommand([ 'status' ]));
                        const rows = [];

                        for (const kind of [ 'geoip', 'geosite' ]) {
                                const title = kind === 'geoip' ? 'GeoIP' : 'GeoSite';
                                const input = E('input', {
                                        'type': 'url',
                                        'class': 'cbi-input-text',
                                        'style': 'width: min(100%, 650px)',
                                        'value': data[kind + '_url'] || ''
                                });

                                const status = data[kind + '_exists']
                                        ? _('Available') + ' · ' + data[kind + '_size'] +
                                                ' bytes · ' + data[kind + '_mtime']
                                        : _('File not found');

                                const save = E('button', {
                                        'class': 'btn cbi-button',
                                        'click': async () => {
                                                save.disabled = true;
                                                try {
                                                        await this.geoCommand([
                                                                'set-url', kind, input.value
                                                        ]);
                                                        ui.addTimeLimitedNotification(null,
                                                                E('p', _('Download URL saved.')),
                                                                4000, 'info');
                                                }
                                                catch (err) {
                                                        ui.addNotification(null,
                                                                E('p', err.message), 'error');
                                                }
                                                finally {
                                                        save.disabled = false;
                                                }
                                        }
                                }, _('Save URL'));

                                const update = E('button', {
                                        'class': 'btn cbi-button-action',
                                        'click': async () => {
                                                update.disabled = true;
                                                try {
                                                        await this.geoCommand([
                                                                'set-url', kind, input.value
                                                        ]);
                                                        await this.geoCommand([ 'update', kind ]);
                                                        ui.addTimeLimitedNotification(null,
                                                                E('p', title + ' ' +
                                                                        _('updated successfully.')),
                                                                5000, 'info');
                                                        await this.updateGeoStatus();
                                                }
                                                catch (err) {
                                                        ui.addNotification(null,
                                                                E('p', err.message), 'error');
                                                }
                                                finally {
                                                        update.disabled = false;
                                                }
                                        }
                                }, _('Update now'));

                                rows.push(E('div', { 'class': 'cbi-value' }, [
                                        E('label', { 'class': 'cbi-value-title' }, title),
                                        E('div', { 'class': 'cbi-value-field' }, [
                                                E('div', {}, status),
                                                E('div', { 'style': 'margin: 6px 0' }, input),
                                                save, ' ', update
                                        ])
                                ]));
                        }

                        const auto = E('input', {
                                'type': 'checkbox',
                                'checked': !!data.auto_update,
                                'change': async () => {
                                        auto.disabled = true;
                                        try {
                                                await this.geoCommand([
                                                        'set-auto', auto.checked ? '1' : '0'
                                                ]);
                                                ui.addTimeLimitedNotification(null,
                                                        E('p', _('Auto-update setting saved.')),
                                                        4000, 'info');
                                        }
                                        catch (err) {
                                                auto.checked = !auto.checked;
                                                ui.addNotification(null,
                                                        E('p', err.message), 'error');
                                        }
                                        finally {
                                                auto.disabled = false;
                                        }
                                }
                        });

                        rows.push(E('div', { 'class': 'cbi-value' }, [
                                E('label', { 'class': 'cbi-value-title' },
                                        _('Automatic daily updates')),
                                E('div', { 'class': 'cbi-value-field' }, [
                                        auto, ' ', _('Update every day at 04:00')
                                ])
                        ]));

                        this.geoBox.replaceChildren(...rows);
                }
                catch (err) {
                        this.geoBox.replaceChildren(E('p',
                                { 'class': 'alert-message' },
                                _('Unable to read GeoIP/GeoSite status: %s')
                                        .format(err.message)));
                }
        },

'''

replace_once(
    '        /* Packages */\n',
    methods + '        /* Packages */\n',
    '插入 Geo 更新方法'
)

replace_once(
    "            this.packageStatus = E('div', { 'aria-live': 'polite' });\n",
    "            this.packageStatus = E('div', { 'aria-live': 'polite' });\n"
    "            this.geoBox = E('div', { 'class': 'cbi-section' });\n",
    '初始化 Geo 状态容器'
)

replace_once(
    "            o = s.option(form.Flag, 'enabled', _('Enable'),\n",
    "            o = s.option(form.DummyValue, '_geo_databases', _('GeoIP / GeoSite'));\n"
    "            o.renderWidget = () => this.geoBox;\n\n"
    "            o = s.option(form.Flag, 'enabled', _('Enable'),\n",
    '插入 Geo 状态选项'
)

replace_once(
    "            this.updateStatus();\n            this.packagePolling = true;\n",
    "            this.updateStatus();\n            this.updateGeoStatus();\n"
    "            this.packagePolling = true;\n",
    '页面加载 Geo 状态'
)

p.write_text(s)
print('service.js 已修改')
PY

# 修改 dae / honk ACL
python3 - "$ACL_DAE" "$ACL_HONK" <<'PY'
from pathlib import Path
import json
import sys

for name in sys.argv[1:]:
    p = Path(name)
    data = json.loads(p.read_text())
    app = next(iter(data.values()))

    app.setdefault('read', {}).setdefault('file', {})[
        '/usr/libexec/daeuniverse-geo status'
    ] = ['exec']

    write = app.setdefault('write', {}).setdefault('file', {})
    for command in ('update *', 'update-all', 'set-url *', 'set-auto *'):
        write['/usr/libexec/daeuniverse-geo ' + command] = ['exec']

    p.write_text(json.dumps(data, ensure_ascii=False, indent='\t') + '\n')
    print(p, 'ACL 已修改')
PY

echo "GeoIP / GeoSite 更新功能已加入"
