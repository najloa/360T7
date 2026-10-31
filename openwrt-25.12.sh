#!/bin/bash

sed -i 's/192.168.1.1/192.168.5.1/' ./package/base-files/files/bin/config_generate

# 修改 Passwall
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

# 移除 v2ray
sed -i 's/ +v2ray-geoip +v2ray-geosite//' ./feeds/honk_packages/honk/Makefile




# honk 依赖

CONFIG_FILE="target/linux/mediatek/filogic/config-6.18"

set_kernel_config() {
    local option="$1"

    sed -i -E \
        "/^# ${option} is not set$/d; /^${option}=/d" \
        "$CONFIG_FILE"

    echo "${option}=y" >> "$CONFIG_FILE"
}

for option in \
    CONFIG_NET_CLS_ACT \
    CONFIG_NETKIT \
    CONFIG_NF_TABLES \
    CONFIG_NF_TABLES_INET \
    CONFIG_NF_CONNTRACK \
    CONFIG_NFT_CT \
    CONFIG_NETFILTER_ADVANCED \
    CONFIG_NETFILTER_NETLINK_QUEUE \
    CONFIG_NFT_QUEUE
do
    set_kernel_config "$option"
done

# Prepare honk source
HONK_DIR="$GITHUB_WORKSPACE/openwrt/feeds/honk_packages/honk"

if grep -q '^CONFIG_PACKAGE_honk=y$' "$GITHUB_WORKSPACE/openwrt/.config"; then
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
fi

# Prepare honk build environment
if grep -qx 'CONFIG_PACKAGE_honk=y' .config; then
    HONK_SRC="$PWD/feeds/honk_packages/honk/src"
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
