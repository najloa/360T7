#!/bin/bash

sed -i '/192\.168\.1\.1/s/192\.168\.1\.1/192.168.5.1/g' \
    ./package/base-files/files/bin/config_generate

sed -i \
    -e "s/timezone='GMT0'/timezone='CST-8'/" \
    -e "s/zonename='UTC'/zonename='Asia\/Shanghai'/" \
    ./package/base-files/files/bin/config_generate

# WED
echo 'options mt7915e wed_enable=Y' >> package/system/ubox/files/modules.conf

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

# 为 dae 和 honk 移除 v2ray
sed -i 's/ +v2ray-geoip +v2ray-geosite//' ./feeds/honk_packages/dae/Makefile ./feeds/honk_packages/honk/Makefile

# dae 规则集更新功能
sh "$GITHUB_WORKSPACE/patch-dae-geodata.sh" "$PWD/feeds/honk_packages"

# Kernel configuration
set_kernel_config() {
    local option="$1"
    local value="$2"

    sed -i -E \
        "/^# ${option} is not set$/d; /^${option}=/d" \
        "$CONFIG_FILE"

    echo "${option}=${value}" >> "$CONFIG_FILE"
}

# Locate the latest kernel configuration
get_kernel_config() {
    CONFIG_FILE=$(find target/linux/mediatek/filogic \
        -maxdepth 1 -name 'config-6.*' | sort -V | tail -n 1)

    if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Kernel config not found"
        exit 1
    fi
}

# Prepare source from package Makefile
prepare_source() {
    local package_dir="$1"
    local repo="$2"
    local pattern="$3"
    shift 3

    local tag
    tag=$(sed -n "$pattern" "$package_dir/Makefile")

    if [ -z "$tag" ]; then
        echo "Error: Failed to determine source tag: $package_dir"
        exit 1
    fi

    echo "Preparing $package_dir source: $tag"

    if [ ! -d "$package_dir/src" ]; then
        git clone "$@" --depth 1 \
            --branch "$tag" "$repo" "$package_dir/src"
    fi
}

# dae
if [ "$FIRMWARE_VERSION" = "openwrt-25.12-dae" ]; then
    get_kernel_config

    set_kernel_config CONFIG_NETKIT y
    set_kernel_config CONFIG_NET_SCH_INGRESS m
    set_kernel_config CONFIG_NET_CLS_BPF m
    set_kernel_config CONFIG_NET_CLS_ACT y
    set_kernel_config CONFIG_BPF_STREAM_PARSER y

    if grep -qx 'CONFIG_PACKAGE_dae=y' .config; then
        prepare_source \
            "$PWD/feeds/honk_packages/dae" \
            https://github.com/daeuniverse/dae.git \
            's/^PKG_VERSION:=$(if $(DAE_VERSION),$(DAE_VERSION),\([^)]*\))$/\1/p' \
            --recurse-submodules \
            --shallow-submodules
    fi
fi

# honk
if [ "$FIRMWARE_VERSION" = "openwrt-25.12-honk" ]; then
    get_kernel_config

    # eBPF / TCX datapath
    for option in \
        CONFIG_BPF \
        CONFIG_BPF_SYSCALL \
        CONFIG_BPF_JIT \
        CONFIG_CGROUPS \
        CONFIG_CGROUP_BPF \
        CONFIG_NET_SCHED \
        CONFIG_NET_CLS_ACT \
        CONFIG_NET_NS
    do
        set_kernel_config "$option" y
    done

    # Optional: netkit (honk falls back to veth)
    set_kernel_config CONFIG_NETKIT y

    # Netfilter / NAT / flow table
    set_kernel_config CONFIG_NETFILTER y
    set_kernel_config CONFIG_NF_CONNTRACK m
    set_kernel_config CONFIG_NF_NAT m
    set_kernel_config CONFIG_NF_FLOW_TABLE m

    # NFQUEUE / nftables
    for option in \
        CONFIG_NF_TABLES \
        CONFIG_NF_TABLES_INET \
        CONFIG_NFT_CT \
        CONFIG_NFT_QUEUE \
        CONFIG_NETFILTER_NETLINK_QUEUE
    do
        set_kernel_config "$option" m
    done

    # honk source and build environment
    if grep -qx 'CONFIG_PACKAGE_honk=y' .config; then
        HONK_DIR="$PWD/feeds/honk_packages/honk"

        prepare_source \
            "$HONK_DIR" \
            https://github.com/daeuniverse/honk.git \
            's/^HONK_GIT_TAG:=$(if $(HONK_GIT_TAG),$(HONK_GIT_TAG),\([^)]*\))$/\1/p'

        HONK_SRC="$HONK_DIR/src"
        CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
        export CARGO_HOME
        export PATH="$CARGO_HOME/bin:$PATH"

        # Install rustup if missing
        if ! command -v rustup >/dev/null 2>&1; then
            curl --proto '=https' --tlsv1.2 -sSf \
                https://sh.rustup.rs | sh -s -- -y \
                --profile minimal --default-toolchain none
        fi

        # Read pinned toolchains
        STABLE_TOOLCHAIN=$(sed -n \
            's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
            "$HONK_SRC/rust-toolchain.toml" | head -n 1)

        NIGHTLY_TOOLCHAIN=$(sed -n \
            's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
            "$HONK_SRC/crates/honk-ebpf/rust-toolchain.toml" | head -n 1)

        if [ -z "$STABLE_TOOLCHAIN" ] || [ -z "$NIGHTLY_TOOLCHAIN" ]; then
            echo "Error: Failed to read honk Rust toolchains"
            exit 1
        fi

        # Install stable toolchain for honk userspace
        rustup toolchain install "$STABLE_TOOLCHAIN" \
            --profile minimal

        rustup component add \
            --toolchain "$STABLE_TOOLCHAIN" \
            rustfmt clippy

        rustup target add \
            --toolchain "$STABLE_TOOLCHAIN" \
            aarch64-unknown-linux-musl

        # Install nightly toolchain for eBPF
        rustup toolchain install "$NIGHTLY_TOOLCHAIN" \
            --profile minimal \
            --component rust-src \
            --component llvm-tools

        # Install zstd only when missing
        if ! command -v zstd >/dev/null 2>&1; then
            sudo apt-get install -y zstd
        fi

        # Install pinned bpf-linker
        . "$HONK_SRC/.github/ci/pins.env"

        mkdir -p "$CARGO_HOME/bin"

        curl -fsSL --retry 3 \
            -o "$RUNNER_TEMP/bpf-linker.tar.zst" \
            "https://github.com/aya-rs/bpf-linker/releases/download/v${BPF_LINKER_VERSION}/bpf-linker-x86_64-unknown-linux-musl.tar.zst"

        echo "${BPF_LINKER_SHA256}  $RUNNER_TEMP/bpf-linker.tar.zst" \
            | sha256sum -c -

        zstd -dc "$RUNNER_TEMP/bpf-linker.tar.zst" \
            | tar -xf - -C "$CARGO_HOME/bin"

        chmod +x "$CARGO_HOME/bin/bpf-linker"

        echo "$CARGO_HOME/bin" >> "$GITHUB_PATH"

        echo "honk build environment ready"
        rustc "+$STABLE_TOOLCHAIN" --version
        rustc "+$NIGHTLY_TOOLCHAIN" --version
        bpf-linker --version
    fi
fi
