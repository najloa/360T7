#!/usr/bin/env bash
#
# Prune MediaTek Unified Autobuild package selections for Qihoo 360T7.
#
# This script modifies only the four inherited defconfig files.
#
# Usage:
#   bash scripts/prune-mtk-defconfig.sh [mtk-openwrt-feeds]

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
        echo "ERROR: Missing defconfig: $file" >&2
        exit 1
    fi
done

# Keep the platform-level MT7981 WO firmware selection.
# A child-layer not-set entry overrides the parent-layer y entry, so remove
# assignments for this symbol from layers 2-4 and let layer 1 take effect.
MT7981_WO_SYMBOL="CONFIG_PACKAGE_mt7981-wo-firmware"

if ! grep -Fxq "${MT7981_WO_SYMBOL}=y" "${DEFCONFIGS[0]}"; then
    echo "ERROR: ${MT7981_WO_SYMBOL}=y is missing from ${DEFCONFIGS[0]}" >&2
    exit 1
fi

for file in "${DEFCONFIGS[@]:1}"; do
    tmp="$(mktemp "${file}.XXXXXX")"
    awk -v symbol="$MT7981_WO_SYMBOL" '
        index($0, symbol "=") == 1 { next }
        $0 == "# " symbol " is not set" { next }
        { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
done

echo "Preserved: ${MT7981_WO_SYMBOL}=y (platform layer)"

# Match only packages explicitly enabled (y or m) in the four defconfigs.
should_remove_package() {
    local pkg="$1"

    case "$pkg" in
        # No external USB port; remove USB host/storage support and utilities.
        kmod-usb*|usbutils)
            return 0
            ;;

        # Removable storage and filesystem support not used by this board.
        block-mount|blkid|e2fsprogs|f2fsck|mkf2fs|lsblk|sfdisk|mmc-utils|fio|\
        kmod-ata-core|kmod-scsi-core|kmod-scsi-generic|\
        kmod-fs-ext4|kmod-fs-f2fs|kmod-fs-vfat|kmod-fs-msdos|\
        kmod-fs-exfat|kmod-fs-ntfs3)
            return 0
            ;;

        # PHYs / firmware for hardware not present on Qihoo 360T7.
        airoha-phy-firmware|as2xxxx-firmware|aqr10g-phy-firmware|\
        airoha-*|aqr10g-*|kmod-phy-air*|kmod-phy-airoha-*|\
        kmod-phy-aquantia|kmod-phy-marvell*|\
        kmod-mt798x-2p5g-phy|mt798x-2p5g-phy-firmware-internal|kmod-sfp)
            return 0
            ;;

        # Other MediaTek SoC / Wi-Fi chipset firmware and drivers.
        mt7986-wo-firmware|mt7988-wo-firmware|\
        kmod-mt7986-firmware|kmod-mt7990-firmware|\
        kmod-mt7992*|kmod-mt7996*)
            return 0
            ;;

        # Test, profiling, factory and hardware-debug utilities.
        atenl|mt76-test|CFG80211_TESTMODE|perf|quick_track|flex|\
        regs|netsys_dbg_util|smp_util|mtk_factory_rw|\
        spidev-test|iio-utils|gpiod-tools|i2c-tools|lm-sensors|pciutils)
            return 0
            ;;

        # RFB-only peripherals not fitted on the 360T7 board.
        kmod-hwmon-pwmfan|kmod-i2c-mux-pca954x|kmod-eeprom-at24|\
        kmod-rtc-pcf8563|kmod-gpio-pca953x)
            return 0
            ;;

        # StrongSwan / IPsec and its optional hardware accelerator.
        strongswan|strongswan-*|kmod-ipsec*|kmod-ipt-ipsec|\
        iptables-mod-ipsec|kmod-crypto-eip*)
            return 0
            ;;

        # PPTP / L2TP VPN. PPPoE packages are deliberately not matched.
        pptpd|xl2tpd|ppp-mod-pptp|ppp-mod-pppol2tp|\
        kmod-pptp|kmod-pppol2tp|kmod-l2tp*)
            return 0
            ;;

        # Legacy iptables stack; this build uses the OpenWrt nftables firewall.
        ip6tables-zz-legacy|iptables-zz-legacy|iptables-mod-*|kmod-ipt-*)
            return 0
            ;;

        # SMB / Windows network discovery.
        ksmbd-server|luci-app-ksmbd|wsdd2|kmod-fs-ksmbd)
            return 0
            ;;

        # Avahi / mDNS.
        avahi-*)
            return 0
            ;;

        # Optional multicast proxy and wireless relay services.
        luci-app-omcproxy|luci-app-udpxy|relayd|luci-proto-relay)
            return 0
            ;;

        # Optional 6 GHz AFC daemon; 360T7 is a Wi-Fi 6, 2.4/5 GHz device.
        afcd)
            return 0
            ;;

        # File-transfer client not needed on the router.
        lftp)
            return 0
            ;;

        *)
            return 1
            ;;
    esac
}

# Remove a selected package from all layers and put one explicit not-set
# override in the most specific layer.
disable_package() {
    local symbol="$1"
    local file
    local tmp

    for file in "${DEFCONFIGS[@]}"; do
        tmp="$(mktemp "${file}.XXXXXX")"
        awk -v symbol="$symbol" '
            index($0, symbol "=") == 1 { next }
            $0 == "# " symbol " is not set" { next }
            { print }
        ' "$file" > "$tmp"
        mv "$tmp" "$file"
    done

    printf '# %s is not set\n' "$symbol" >> "${DEFCONFIGS[3]}"
    echo "Disabled: ${symbol}"
}

echo "========== Pruning selected packages =========="

mapfile -t PACKAGE_SYMBOLS < <(
    awk '
        /^CONFIG_PACKAGE_[A-Za-z0-9_.+-]+=(y|m)$/ {
            sub(/=.*/, "")
            print
        }
    ' "${DEFCONFIGS[@]}" | sort -u
)

for symbol in "${PACKAGE_SYMBOLS[@]}"; do
    pkg="${symbol#CONFIG_PACKAGE_}"

    # This platform-required package must never be removed by the package list.
    [[ "$symbol" == "$MT7981_WO_SYMBOL" ]] && continue

    if should_remove_package "$pkg"; then
        disable_package "$symbol"
    fi
done

echo
echo "========== Pruning completed =========="
echo "Modified files: the four defconfigs only."
