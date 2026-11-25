
#!/usr/bin/env bash
#
# Prune MediaTek Unified Autobuild defconfigs for Qihoo 360T7.
#
# Usage:
#   bash scripts/prune-mtk-defconfig.sh [mtk-openwrt-feeds]
#

set -euo pipefail

FEEDS_ROOT="${1:-mtk-openwrt-feeds}"
BASE_DIR="${FEEDS_ROOT}/autobuild/unified/filogic"

DEFCONFIGS=(
    "${BASE_DIR}/25.12/defconfig"
    "${BASE_DIR}/mac80211/25.12/defconfig"
    "${BASE_DIR}/mac80211/mt798x_rfb/25.12/defconfig"
    "${BASE_DIR}/mac80211/mt798x_rfb/wifi6_nic/25.12/defconfig"
)

for file in "${DEFCONFIGS[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Missing defconfig: $file"
        exit 1
    fi
done

# Check whether a symbol is explicitly present in any defconfig.
symbol_exists() {
    local symbol="$1"

    grep -Fq "${symbol}=" "${DEFCONFIGS[@]}" ||
    grep -Fq "# ${symbol} is not set" "${DEFCONFIGS[@]}"
}

# Set a symbol to not-set in all four configuration layers.
# This prevents a lower layer from re-enabling an option.
disable_symbol() {
    local symbol="$1"
    local file
    local tmp

    if ! symbol_exists "$symbol"; then
        return 0
    fi

    for file in "${DEFCONFIGS[@]}"; do
        tmp="${file}.tmp"

        awk -v symbol="$symbol" '
            index($0, symbol "=") == 1 { next }
            $0 == "# " symbol " is not set" { next }
            { print }
        ' "$file" > "$tmp"

        printf '# %s is not set\n' "$symbol" >> "$tmp"
        mv "$tmp" "$file"
    done

    echo "Disabled: ${symbol}"
}

# Match package names selected by the four upstream defconfigs.
should_remove_package() {
    local pkg="$1"

    case "$pkg" in

        # USB host and USB storage
        kmod-usb*|usbutils|usbids|libusb-1.0)

            return 0
            ;;

        # Block storage and filesystem support
        block-mount|blkid|e2fsprogs|f2fsck|mkf2fs|lsblk|sfdisk)
            return 0
            ;;

        kmod-fs-ext4|kmod-fs-f2fs|kmod-fs-vfat)
            return 0
            ;;

        # StrongSwan / IPsec
        strongswan|strongswan-*|kmod-ipsec*|kmod-ipt-ipsec|iptables-mod-ipsec)
            return 0
            ;;

        # PPTP / L2TP VPN
        pptpd|xl2tpd|ppp-mod-pptp|ppp-mod-pppol2tp|kmod-pptp|kmod-pppol2tp|kmod-l2tp*)
            return 0
            ;;

        # Unused PHY vendors and 2.5G PHY
        airoha-*|aqr10g-*|kmod-phy-air*|kmod-phy-airoha-*|kmod-phy-aquantia|kmod-phy-marvell*)
            return 0
            ;;

        kmod-mt798x-2p5g-phy|mt798x-2p5g-phy-firmware-internal|kmod-sfp)
            return 0
            ;;

        # Wireless chipsets unrelated to MT7981
        mt7986-wo-firmware|mt7988-wo-firmware)
            return 0
            ;;

        kmod-mt7986-firmware|kmod-mt7990-firmware|kmod-mt7992*|kmod-mt7996*)
            return 0
            ;;

        # Wireless test and development tools
        atenl|mt76-test|CFG80211_TESTMODE|perf|fio|quick_track)
            return 0
            ;;

        # MediaTek hardware debugging tools
        regs|netsys_dbg_util|smp_util)
            return 0
            ;;

        # Peripheral testing and hardware management tools
        spidev-test|mmc-utils|iio-utils|gpiod-tools|i2c-tools|lm-sensors|pciutils)
            return 0
            ;;

        # SMB and Windows network discovery
        ksmbd-server|luci-app-ksmbd|wsdd2|kmod-fs-ksmbd)
            return 0
            ;;

        # mDNS / Avahi
        avahi-*|luci-app-udpxy)
            return 0
            ;;

        # Wireless relay
        relayd|luci-proto-relay)
            return 0
            ;;

        # File transfer client
        lftp)
            return 0
            ;;

        *)
            return 1
            ;;
    esac
}

echo "========== Pruning MediaTek defconfigs =========="

# Collect package symbols from all four layers.
mapfile -t PACKAGE_SYMBOLS < <(
    awk '
        /^CONFIG_PACKAGE_[A-Za-z0-9_.+-]+=/
        {
            sub(/=.*/, "")
            print
        }
    ' "${DEFCONFIGS[@]}" | sort -u
)

# Disable selected unnecessary packages.
for symbol in "${PACKAGE_SYMBOLS[@]}"; do
    pkg="${symbol#CONFIG_PACKAGE_}"

    if should_remove_package "$pkg"; then
        disable_symbol "$symbol"
    fi
done

# Disable multi-profile and per-device rootfs.
disable_symbol CONFIG_TARGET_MULTI_PROFILE
disable_symbol CONFIG_TARGET_PER_DEVICE_ROOTFS

# Disable all inherited MediaTek device profiles.
mapfile -t DEVICE_SYMBOLS < <(
    awk '
        /^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_[A-Za-z0-9_-]+=/
        {
            sub(/=.*/, "")
            print
        }
    ' "${DEFCONFIGS[@]}" | sort -u
)

for symbol in "${DEVICE_SYMBOLS[@]}"; do
    disable_symbol "$symbol"
done

echo
echo "========== Preserve MT7981 wireless packages =========="

# Ensure the 360T7 wireless driver and firmware remain enabled
# in the most specific configuration layer.
FINAL_DEFCONFIG="${DEFCONFIGS[3]}"

set_enabled() {
    local symbol="$1"
    local file="$FINAL_DEFCONFIG"
    local tmp="${file}.tmp"

    awk -v symbol="$symbol" '
        index($0, symbol "=") == 1 { next }
        $0 == "# " symbol " is not set" { next }
        { print }
    ' "$file" > "$tmp"

    printf '%s=y\n' "$symbol" >> "$tmp"
    mv "$tmp" "$file"

    echo "Enabled: ${symbol}"
}

set_enabled CONFIG_PACKAGE_kmod-mt7915e
set_enabled CONFIG_PACKAGE_kmod-mt7981-firmware
set_enabled CONFIG_PACKAGE_mt7981-wo-firmware

echo
echo "========== Pruning completed =========="
