#!/usr/bin/env bash
#
# Prune MediaTek Unified Autobuild configuration for Qihoo 360T7.
#
# This script operates only on a fresh mtk-openwrt-feeds checkout.
# It prunes the four inherited defconfigs and removes MediaTek rule hooks
# that would otherwise re-enable RFB-only test packages or unrelated PHYs.
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

FINAL_DEFCONFIG="${DEFCONFIGS[3]}"
FILOGIC_RULES="${BASE_DIR}/rules"
MAC80211_RULES="${BASE_DIR}/mac80211/rules"

for file in "${DEFCONFIGS[@]}" "${FILOGIC_RULES}" "${MAC80211_RULES}"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Missing required file: $file" >&2
        exit 1
    fi
done

# Remove every assignment (y/m or an existing not-set line) for this symbol
# from all four layers, then put one explicit not-set override in layer 4.
# MediaTek's aconf merges layers in parent-to-child order; the child layer wins.
set_not_set_in_final_layer() {
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

    printf '# %s is not set\n' "$symbol" >> "$FINAL_DEFCONFIG"
    echo "Disabled: ${symbol}"
}

# This package is enabled in the platform layer and explicitly disabled in
# the mac80211 layer. Remove active assignments from every layer, but preserve
# the existing child-level not-set line that cancels the parent selection.
remove_enabled_assignments_preserve_not_set() {
    local symbol="$1"
    local file
    local tmp

    for file in "${DEFCONFIGS[@]}"; do
        tmp="$(mktemp "${file}.XXXXXX")"
        awk -v symbol="$symbol" '
            index($0, symbol "=") == 1 { next }
            { print }
        ' "$file" > "$tmp"
        mv "$tmp" "$file"
    done
}

remove_enabled_assignments_preserve_not_set \
    "CONFIG_PACKAGE_mt7981-wo-firmware"

# Package names are collected from the actual four defconfigs, not from a
# previously generated diffconfig or a saved .config artifact.
mapfile -t PACKAGE_SYMBOLS < <(
    awk '
        /^CONFIG_PACKAGE_[A-Za-z0-9_.+-]+=(y|m)$/ {
            sub(/=.*/, "")
            print
        }
    ' "${DEFCONFIGS[@]}" | sort -u
)

should_remove_package() {
    local pkg="$1"

    case "$pkg" in
        # No external USB port; no USB host/storage stack or USB utilities.
        kmod-usb*|usbutils)
            return 0
            ;;

        # No removable block storage / eMMC on this board.
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

echo "========== Pruning MediaTek defconfigs =========="

for symbol in "${PACKAGE_SYMBOLS[@]}"; do
    pkg="${symbol#CONFIG_PACKAGE_}"
    if should_remove_package "$pkg"; then
        set_not_set_in_final_layer "$symbol"
    fi
done

# Disable the multi-profile build and per-device rootfs mode.
for symbol in \
    CONFIG_TARGET_MULTI_PROFILE \
    CONFIG_TARGET_PER_DEVICE_ROOTFS
do
    if grep -Fq -- "${symbol}=y" "${DEFCONFIGS[@]}"; then
        set_not_set_in_final_layer "$symbol"
    fi
done

# Disable all inherited Filogic RFB device profiles. These are distinct from
# CONFIG_TARGET_mediatek_filogic_DEVICE_qihoo_360t7 in the user's own config.
mapfile -t DEVICE_SYMBOLS < <(
    awk '
        /^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_[A-Za-z0-9_.+-]+=y$/ {
            sub(/=.*/, "")
            print
        }
    ' "${DEFCONFIGS[@]}" | sort -u
)

for symbol in "${DEVICE_SYMBOLS[@]}"; do
    set_not_set_in_final_layer "$symbol"
done

# Disable kernel profiling and trim optional BusyBox applets explicitly enabled
# by the inherited configs. CONFIG_KERNEL_BPF_EVENTS is deliberately untouched.
BUSYBOX_SYMBOLS=(
    CONFIG_KERNEL_PROFILING
    CONFIG_BUSYBOX_CONFIG_TFTP
    CONFIG_BUSYBOX_CONFIG_FEATURE_TFTP_GET
    CONFIG_BUSYBOX_CONFIG_FEATURE_TFTP_PUT
    CONFIG_BUSYBOX_CONFIG_VCONFIG
    CONFIG_BUSYBOX_CONFIG_MPSTAT
    CONFIG_BUSYBOX_CONFIG_TELNET
    CONFIG_BUSYBOX_CONFIG_TELNETD
    CONFIG_BUSYBOX_CONFIG_FEATURE_TELNETD_STANDALONE
)

for symbol in "${BUSYBOX_SYMBOLS[@]}"; do
    if grep -Fq -- "${symbol}=y" "${DEFCONFIGS[@]}"; then
        set_not_set_in_final_layer "$symbol"
    fi
done

# Some packages are force-enabled by MediaTek's prepare hooks after aconf has
# merged the defconfigs. Remove only the specific hooks that are not needed
# for this single-device build. Keep ephy-utils and ethtool-full enabled.
python3 - "$FILOGIC_RULES" "$MAC80211_RULES" <<'PY'
from pathlib import Path
import sys

filogic_rules = Path(sys.argv[1])
mac80211_rules = Path(sys.argv[2])

filogic_drop_exact = {
    "list_append $(hooks autobuild_prepare) airoha_firmware_install",
    "list_add_after $(hooks autobuild_prepare) airoha_firmware_install copy_phy_firmware",
    "openwrt_config_enable CONFIG_PACKAGE_fio",
    "openwrt_config_enable CONFIG_PACKAGE_lsblk",
    "openwrt_config_enable CONFIG_PACKAGE_sfdisk",
    "openwrt_config_enable CONFIG_PACKAGE_mmc-utils",
}

# These kernel drivers / firmware are for PHYs, switches or sensors not fitted
# on Qihoo 360T7. Keep MT753X_GSW and the MT7981 built-in GPHY support.
filogic_drop_kernel_symbols = {
    "CONFIG_AIR_EN8811H_PHY",
    "CONFIG_AIR_EN8811H_PHY_DEBUGFS",
    "CONFIG_AQUANTIA_PHY",
    "CONFIG_AS21XXX_PHY",
    "CONFIG_AIROHA_AN8801_PHY",
    "CONFIG_AIR_AN8811HB_PHY",
    "CONFIG_AIR_AN8811HB_PHY_DEBUGFS",
    "CONFIG_AN8855_GSW",
    "CONFIG_NET_DSA_MXL862",
    "CONFIG_NET_DSA_TAG_MXL862",
    "CONFIG_NET_DSA_TAG_MXL862_8021Q",
    "CONFIG_IIO",
    "CONFIG_ZTS8032",
    "CONFIG_ZTS8232",
    "CONFIG_EXTRA_FIRMWARE",
    "CONFIG_EXTRA_FIRMWARE_DIR",
}

mac80211_drop_exact = {
    "openwrt_config_enable CONFIG_PACKAGE_relayd",
    "openwrt_config_enable CONFIG_PACKAGE_luci-proto-relay",
}

filogic_replacements = {
    # Keep the shell function syntactically valid after removing all QVL enables.
    "openwrt_config_enable CONFIG_PACKAGE_fio": "    : # QVL-only package enables removed for 360T7",
}

mac80211_replacements = {
    # Keep the relayd hook function syntactically valid but inert.
    "openwrt_config_enable CONFIG_PACKAGE_relayd": "    : # relayd disabled for 360T7",
}

def rewrite(path: Path, *, exact: set[str], drop_kernel: set[str] = set(),
            drop_prefixes: tuple[str, ...] = (),
            replacements: dict[str, str] = {}) -> None:
    original = path.read_text().splitlines()
    kept = []
    removed = []

    for line in original:
        stripped = line.strip()
        words = stripped.split()
        drop = stripped in exact or any(stripped.startswith(p) for p in drop_prefixes)

        if len(words) >= 2 and words[0] == "kernel_config_enable":
            if words[1] in drop_kernel:
                drop = True

        if drop:
            removed.append(stripped)
            replacement = replacements.get(stripped)
            if replacement is not None:
                kept.append(replacement)
        else:
            kept.append(line)

    if removed:
        path.write_text("\n".join(kept) + "\n")

    print(f"Updated {path}: removed {len(removed)} rule line(s)")
    for line in removed:
        print(f"  - {line}")

rewrite(
    filogic_rules,
    exact=filogic_drop_exact,
    drop_kernel=filogic_drop_kernel_symbols,
    drop_prefixes=("extra_firmware=", "extra_firmware+=",),
    replacements=filogic_replacements,
)
rewrite(
    mac80211_rules,
    exact=mac80211_drop_exact,
    replacements=mac80211_replacements,
)
PY

echo
echo "========== Pruning completed =========="
echo "The user's own defconfig is applied later, after MediaTek prepare."
echo "Keep required packages such as kmod-mt7915e, kmod-mt7981-firmware,"
echo "ephy-utils, ethtool-full, mtkhnat_util, tcpdump and iperf3 in the"
echo "MediaTek config or add them through the user's own defconfig."
