#!/usr/bin/env bash
#
# Prune MediaTek Unified Autobuild selections for Qihoo 360T7.
#
# This script:
#   1. Prunes selected packages from the four inherited Filogic defconfigs.
#   2. Keeps only the configured MT7981 RFB target-device profile.
#   3. Disables selected, unnecessary BusyBox applets/features.
#   4. Patches Unified Autobuild rules for the 360T7 hardware.
#
# Run before: autobuild.sh ... prepare
# Usage: bash scripts/prune-mtk-defconfig-v2.sh [mtk-openwrt-feeds]

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

# -----------------------------------------------------------------------------
# Generic config helpers
# -----------------------------------------------------------------------------

# Remove a symbol's assignments/not-set entries from all layers, then place one
# explicit not-set override in the most-specific layer.
disable_symbol() {
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

symbol_is_enabled() {
    local symbol="$1"
    local file

    for file in "${DEFCONFIGS[@]}"; do
        if grep -Eq "^${symbol}=(y|m)$" "$file"; then
            return 0
        fi
    done
    return 1
}

# -----------------------------------------------------------------------------
# Preserve the MT7981 platform-level WO firmware selection.
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# Target-device profile pruning
# -----------------------------------------------------------------------------

# Conservative default: retain the MT7981 RFB profile as the closest MediaTek
# reference profile. It is NOT the Qihoo 360T7 device profile. If the build has
# a dedicated 360T7 profile, add its exact CONFIG_TARGET_DEVICE_ symbol here
# and verify that the autobuild flow actually selects it.
KEEP_TARGET_DEVICE_SYMBOLS=(
    "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_mediatek_mt7981-rfb"
)

is_kept_target_device() {
    local candidate="$1"
    local keep
    for keep in "${KEEP_TARGET_DEVICE_SYMBOLS[@]}"; do
        [[ "$candidate" == "$keep" ]] && return 0
    done
    return 1
}

# Fail rather than silently producing a multi-profile build with no retained
# device profile when the source defconfigs have changed.
KEEP_PROFILE_FOUND=0
for symbol in "${KEEP_TARGET_DEVICE_SYMBOLS[@]}"; do
    if symbol_is_enabled "$symbol"; then
        KEEP_PROFILE_FOUND=1
        break
    fi
done

if [[ "$KEEP_PROFILE_FOUND" -ne 1 ]]; then
    echo "ERROR: None of the configured KEEP_TARGET_DEVICE_SYMBOLS is enabled." >&2
    echo "Check the current MediaTek defconfigs and update the profile allowlist." >&2
    exit 1
fi

echo "========== Pruning target-device profiles =========="
mapfile -t TARGET_DEVICE_SYMBOLS < <(
    awk '
        /^CONFIG_TARGET_DEVICE_[A-Za-z0-9_.+-]+=(y|m)$/ {
            sub(/=.*/, "")
            print
        }
    ' "${DEFCONFIGS[@]}" | sort -u
)

for symbol in "${TARGET_DEVICE_SYMBOLS[@]}"; do
    if is_kept_target_device "$symbol"; then
        echo "Preserved profile: ${symbol}"
    else
        disable_symbol "$symbol"
    fi
done

# Deliberately leave CONFIG_TARGET_MULTI_PROFILE and
# CONFIG_TARGET_PER_DEVICE_ROOTFS unchanged. They control the multi-profile
# build/rootfs behavior rather than selecting an individual device.

# -----------------------------------------------------------------------------
# BusyBox applet / feature pruning
# -----------------------------------------------------------------------------

# These are optional applets/features. TFTP is removed only because this build
# does not require TFTP recovery or file transfer; remove it from this list if
# TFTP is part of the user's recovery workflow.
BUSYBOX_DISABLE_SYMBOLS=(
    "CONFIG_BUSYBOX_CONFIG_TFTP"
    "CONFIG_BUSYBOX_CONFIG_FEATURE_TFTP_GET"
    "CONFIG_BUSYBOX_CONFIG_FEATURE_TFTP_PUT"
)

echo "========== Pruning selected BusyBox features =========="
for symbol in "${BUSYBOX_DISABLE_SYMBOLS[@]}"; do
    if symbol_is_enabled "$symbol"; then
        disable_symbol "$symbol"
    else
        echo "Unchanged (not enabled): ${symbol}"
    fi
done

# CONFIG_BUSYBOX_CUSTOM is intentionally preserved. Other BusyBox options are
# untouched unless explicitly listed above.

# -----------------------------------------------------------------------------
# Package pruning
# -----------------------------------------------------------------------------

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

        # StrongSwan / IPsec packages. Do NOT wildcard-match kmod-crypto-eip*:
        # keep kmod-crypto-eip-ddk available for separate MT7981 compatibility
        # testing. This does not imply that proxy userspace crypto uses the EIP.
        strongswan|strongswan-*|kmod-ipsec*|kmod-ipt-ipsec|iptables-mod-ipsec)
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
        disable_symbol "$symbol"
    fi
done

# -----------------------------------------------------------------------------
# Patch Unified Autobuild rules
# -----------------------------------------------------------------------------

echo "========== Patching Unified Autobuild rules =========="
python3 - "$BASE_DIR" <<'PYRULES'
from pathlib import Path
import re
import sys

base = Path(sys.argv[1])
platform_rules = base / "rules"
wifi_rules = base / "mac80211" / "rules"

for path in (platform_rules, wifi_rules):
    if not path.is_file():
        raise SystemExit(f"ERROR: Missing Unified Autobuild rules file: {path}")


def remove_function(text: str, name: str) -> str:
    pattern = re.compile(r"(?ms)^[A-Za-z_][A-Za-z0-9_]*\(\)\s*\{.*?^\}\s*\n?")
    matches = [m for m in pattern.finditer(text)
               if re.match(rf"{re.escape(name)}\(\)", m.group(0))]
    if len(matches) > 1:
        raise SystemExit(f"ERROR: Multiple definitions of {name} in rules file")
    if matches:
        m = matches[0]
        text = text[:m.start()] + text[m.end():]
    return text


def remove_exact_line(text: str, line: str) -> str:
    return "\n".join(x for x in text.split("\n") if x.strip() != line.strip())


def patch_platform_rules(text: str) -> str:
    # 360T7 uses SPI-NAND, not eMMC. Keep the hook symbol but skip eMMC QVL packages.
    func_pattern = re.compile(r"(?ms)^platform_change_openwrt_config\(\)\s*\{.*?^\}\s*\n?")
    noop = "platform_change_openwrt_config() {\n\t:\n}\n"
    if func_pattern.search(text):
        text = func_pattern.sub(lambda _: noop, text, count=1)
        comment = "# Qihoo 360T7 uses SPI-NAND, not eMMC; skip the eMMC QVL package set."
        if comment not in text:
            text = text.replace(noop, comment + "\n" + noop, 1)
    else:
        raise SystemExit("ERROR: Cannot find platform_change_openwrt_config()")

    # Remove the interactive KDB/KGDB kernel debugger hook and implementation.
    text = remove_exact_line(
        text,
        "list_add_after $(hooks autobuild_prepare) filogic_change_kernel_config change_kernel_kdb_config",
    )
    text = remove_function(text, "change_kernel_kdb_config")

    # Remove firmware preparation for external PHYs absent from the 360T7.
    text = remove_exact_line(text, "list_append $(hooks autobuild_prepare) airoha_firmware_install")
    text = remove_exact_line(
        text,
        "list_add_after $(hooks autobuild_prepare) airoha_firmware_install copy_phy_firmware",
    )
    text = re.sub(r"(?m)^[ \t]*extra_firmware(?:\+)?=.*\n", "", text)
    text = remove_function(text, "airoha_firmware_install")
    text = remove_function(text, "copy_phy_firmware")
    text = re.sub(
        r"(?m)^[ \t]*kernel_config_enable CONFIG_EXTRA_FIRMWARE(?:_DIR)?(?:[ \t]+.*)?\n",
        "",
        text,
    )

    # Explicitly disable unused external PHY/switch, sensor and emulation drivers.
    disable = [
        "CONFIG_AIR_EN8811H_PHY", "CONFIG_AIR_EN8811H_PHY_DEBUGFS",
        "CONFIG_AN8855_GSW", "CONFIG_NET_DSA_MXL862",
        "CONFIG_NET_DSA_TAG_MXL862", "CONFIG_NET_DSA_TAG_MXL862_8021Q",
        "CONFIG_SENSORS_PWM_FAN", "CONFIG_AS21XXX_PHY", "CONFIG_AQUANTIA_PHY",
        "CONFIG_AIROHA_AN8801_PHY", "CONFIG_AIR_AN8811HB_PHY",
        "CONFIG_AIR_AN8811HB_PHY_DEBUGFS", "CONFIG_IIO", "CONFIG_ZTS8032",
        "CONFIG_ZTS8232", "CONFIG_THERMAL_EMULATION",
    ]
    for symbol in disable:
        text = re.sub(
            rf"(?m)^[ \t]*kernel_config_enable {re.escape(symbol)}(?:[ \t]+.*)?\n",
            "",
            text,
        )

    func = re.search(r"(?ms)^filogic_change_kernel_config\(\)\s*\{.*?^\}", text)
    if not func:
        raise SystemExit("ERROR: Cannot find filogic_change_kernel_config()")
    body = func.group(0)
    for symbol in disable:
        line = f"\tkernel_config_disable {symbol}"
        if line not in body:
            body = body[:-1].rstrip() + "\n" + line + "\n}"
    text = text[:func.start()] + body + text[func.end():]
    return text


def patch_wifi_rules(text: str) -> str:
    # Preserve change_kernel_coredump_conf; remove only relayd's re-enable hook.
    text = remove_exact_line(
        text,
        "list_add_after $(hooks autobuild_prepare) variant_change_openwrt_config change_openwrt_relayd_conf",
    )
    text = remove_function(text, "change_openwrt_relayd_conf")
    return text


for path, patcher in ((platform_rules, patch_platform_rules), (wifi_rules, patch_wifi_rules)):
    original = path.read_text()
    updated = patcher(original)
    if updated != original:
        path.write_text(updated)
        print(f"Patched: {path}")
    else:
        print(f"Already patched: {path}")
PYRULES

echo
echo "========== Pruning completed =========="
