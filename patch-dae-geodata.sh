#!/bin/sh
# Patch fresh luci-app-dae and luci-lib-daeuniverse sources with geodata updates.
# The patcher runs on the build host; Python 3 is not added to the firmware.
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <luci-app-dae-dir> <luci-lib-daeuniverse-dir>" >&2
    exit 2
fi

exec python3 - "$1" "$2" <<'PY'
from pathlib import Path
import json
import sys

app = Path(sys.argv[1]).resolve()
lib = Path(sys.argv[2]).resolve()

service = lib / "htdocs/luci-static/resources/daeuniverse/service.js"
makefile = lib / "Makefile"
acl = app / "root/usr/share/rpcd/acl.d/luci-app-dae.json"
pot = lib / "po/templates/daeuniverse.pot"
po = lib / "po/zh_Hans/daeuniverse.po"
helper = lib / "root/usr/libexec/daeuniverse-geodata"

required = [service, makefile, acl, pot, po]
missing = [str(p) for p in required if not p.is_file()]
if missing:
    sys.exit("ERROR: source layout not recognized; missing:\n  " + "\n  ".join(missing))

def replace_once(path, old, new, label):
    data = path.read_text(encoding="utf-8")
    if new in data:
        print("Already patched:", label)
        return
    count = data.count(old)
    if count != 1:
        sys.exit(f"ERROR: expected exactly one patch anchor for {label}, found {count}: {path}")
    path.write_text(data.replace(old, new, 1), encoding="utf-8")
    print("Patched:", label)

replace_once(
    makefile,
    "LUCI_DEPENDS:=+luci-base +jshn +flock +coreutils-timeout",
    "LUCI_DEPENDS:=+luci-base +jshn +flock +coreutils-timeout +curl",
    "curl dependency"
)

helper_text = r'''#!/bin/sh
# Managed by patch-dae-geodata.sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
umask 077

. /usr/share/libubox/jshn.sh

DIR=/usr/share/v2ray
LOCK=/tmp/dae-geodata.lock
CRON_LOCK=/tmp/dae-geodata-cron.lock
LOG=/tmp/dae-geodata.log
RC=/tmp/dae-geodata.rc
CRONTAB=/etc/crontabs/root
MARK='# dae-geodata-auto-update'

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

write_result() {
    result_file=$(mktemp /tmp/dae-geodata.rc.XXXXXX) || return 1
    if printf '%s\n' "$1" > "$result_file" && mv -f "$result_file" "$RC"; then
        return 0
    fi
    rm -f "$result_file"
    return 1
}

update_geodata() {
    mkdir -p "$DIR" || {
        echo "Unable to create $DIR."
        return 1
    }

    tmp=$(mktemp -d "$DIR/.geodata.XXXXXX") || {
        echo "Unable to create a temporary directory in $DIR."
        return 1
    }
    trap 'rm -rf "$tmp"' EXIT

    for name in geosite geoip; do
        url="https://gh-proxy.com/https://raw.githubusercontent.com/najloa/rules/release/$name.dat"
        echo "Downloading $name.dat..."
        curl -fLsS --connect-timeout 15 --max-time 15 "$url" -o "$tmp/$name.dat" || return 1
        curl -fLsS --connect-timeout 15 --max-time 15 "$url.sha256sum" -o "$tmp/$name.dat.sha256sum" || return 1
        echo "Checking $name.dat..."
        (cd "$tmp" && sha256sum -c "$name.dat.sha256sum") || return 1
    done

    mv -f "$tmp/geosite.dat" "$DIR/geosite.dat" || return 1
    mv -f "$tmp/geoip.dat" "$DIR/geoip.dat" || return 1
    echo "Geosite and geoip updated successfully."
}

status() {
    exec 8>>"$LOCK" || fail "Unable to open update lock."
    running=1
    if flock -n 8; then
        running=0
    fi

    if [ "$running" -eq 0 ] && [ -s "$LOG" ] && [ ! -f "$RC" ]; then
        echo "Update worker exited without reporting its result." >> "$LOG"
        write_result 1 || fail "Unable to record update status."
    fi

    json_init
    json_add_boolean running "$running"
    if [ -f "$RC" ]; then
        IFS= read -r result < "$RC" || result=1
        case "$result" in
            ''|*[!0-9]*) result=1 ;;
        esac
        json_add_int code "$result"
    else
        json_add_null code
    fi
    log=
    [ ! -f "$LOG" ] || log=$(tail -c 16384 "$LOG" 2>/dev/null)
    json_add_string log "$log"
    exec 8>&-
    json_dump
}

start_update() {
    exec 9>>"$LOCK" || fail "Unable to open update lock."
    if ! flock -n 9; then
        exec 9>&-
        status
        return
    fi

    : > "$LOG" || fail "Unable to reset update log."
    rm -f "$RC" || fail "Unable to reset update result."

    (
        trap '' HUP
        update_geodata
        result=$?
        write_result "$result"
    ) </dev/null >>"$LOG" 2>&1 &

    exec 9>&-
    status
}

auto_update() {
    [ "$(uci -q get dae.config.auto_update 2>/dev/null)" = "1" ] || exit 0

    exec 9>>"$LOCK" || fail "Unable to open update lock."
    flock -n 9 || exit 0
    : > "$LOG" || fail "Unable to reset update log."
    rm -f "$RC" || fail "Unable to reset update result."

    update_geodata >>"$LOG" 2>&1
    result=$?
    write_result "$result" || fail "Unable to record update result."
    return "$result"
}

sync_schedule() {
    exec 8>>"$CRON_LOCK" || fail "Unable to open cron lock."
    flock 8 || fail "Unable to lock crontab."

    mkdir -p /etc/crontabs || fail "Unable to create /etc/crontabs."
    tmp=$(mktemp /etc/crontabs/.root.XXXXXX) || fail "Unable to create temporary crontab."

    if [ -f "$CRONTAB" ]; then
        awk -v marker="$MARK" 'index($0, marker) == 0 { print }' "$CRONTAB" > "$tmp" ||
            fail "Unable to read the existing crontab."
    fi

    if [ "$(uci -q get dae.config.auto_update 2>/dev/null)" = "1" ]; then
        printf '%s\n' "0 4 * * * /usr/libexec/daeuniverse-geodata auto $MARK" >> "$tmp"
    fi

    if [ -f "$CRONTAB" ] && cmp -s "$tmp" "$CRONTAB"; then
        rm -f "$tmp"
        return 0
    fi

    chmod 600 "$tmp" || fail "Unable to set crontab permissions."
    mv -f "$tmp" "$CRONTAB" || fail "Unable to install the new crontab."
    /etc/init.d/cron restart || fail "Crontab changed, but cron could not be restarted."
}

[ "$#" -gt 0 ] || fail "A command is required."
command=$1
shift

case "$command" in
    start)
        [ "$#" -eq 0 ] || fail "start takes no arguments."
        start_update
        ;;
    status)
        [ "$#" -eq 0 ] || fail "status takes no arguments."
        status
        ;;
    auto)
        [ "$#" -eq 0 ] || fail "auto takes no arguments."
        auto_update
        ;;
    schedule)
        [ "$#" -eq 0 ] || fail "schedule takes no arguments."
        sync_schedule
        ;;
    *)
        fail "Invalid command."
        ;;
esac
'''

if helper.exists():
    existing = helper.read_text(encoding="utf-8")
    if existing != helper_text:
        sys.exit(f"ERROR: {helper} already exists and is not this patcher's file; refusing to overwrite.")
    print("Already patched: geodata helper")
else:
    helper.parent.mkdir(parents=True, exist_ok=True)
    helper.write_text(helper_text, encoding="utf-8")
    helper.chmod(0o755)
    print("Added: geodata helper")

service_insert = r'''
	/* Geodata rule sets: independent of the dae/honk package upgrade job. */

	async geodataCommand(args) {
		const result = await fs.exec('/usr/libexec/daeuniverse-geodata', args);
		if (result.code !== 0) {
			const error = new Error(result.stderr || _('Geodata operation failed.'));
			error.output = result.stdout || '';
			throw error;
		}
		return JSON.parse(result.stdout);
	},

	async handleGeodataUpdate() {
		this.geodataButton.disabled = true;
		this.geodataStatus.replaceChildren(_('Starting rule-set update…'));
		try {
			await this.geodataCommand([ 'start' ]);
			await this.pollGeodataJob();
		}
		catch (error) {
			this.geodataButton.disabled = false;
			this.geodataStatus.replaceChildren(E('pre', { 'class': 'du-log' },
				error.output || error.message));
		}
	},

	async pollGeodataJob() {
		if (!this.geodataStatus)
			return;
		try {
			const status = await this.geodataCommand([ 'status' ]);
			this.geodataButton.disabled = status.running;
			const message = status.running ? _('Updating rule sets…')
				: status.code === 0 ? _('Rule sets updated.')
				: status.code != null ? _('Rule-set update failed.')
				: _('Rule sets have not been updated yet.');
			this.geodataStatus.replaceChildren(
				E('div', {}, message),
				status.log ? E('pre', { 'class': 'du-log' }, status.log) : ''
			);
		}
		catch (error) {
			this.geodataButton.disabled = false;
			this.geodataStatus.replaceChildren(E('pre', { 'class': 'du-log' }, error.message));
		}
	},

'''
replace_once(service, "\t/* Packages */\n", service_insert + "\t/* Packages */\n", "geodata UI methods")

replace_once(
    service,
    "\t\tconst m = new form.Map(name);\n\t\tconst s = m.section(form.NamedSection, 'config', name);",
    "\t\tconst m = new form.Map(name);\n"
    "\t\tconst saveMap = m.save.bind(m);\n"
    "\t\tm.save = (...args) => saveMap(...args).then(() =>\n"
    "\t\t\tfs.exec('/usr/libexec/daeuniverse-geodata', [ 'schedule' ]).then(result => {\n"
    "\t\t\t\tif (result.code !== 0)\n"
    "\t\t\t\t\tthrow new Error(result.stderr || _('Unable to update the automatic rule-set schedule.'));\n"
    "\t\t\t})\n"
    "\t\t);\n"
    "\t\tconst s = m.section(form.NamedSection, 'config', name);",
    "post-save cron synchronization"
)

geodata_row = r'''
		this.geodataButton = E('button', {
			'class': 'btn cbi-button cbi-button-action', 'type': 'button',
			'click': () => this.handleGeodataUpdate()
		}, _('Update now'));
		this.geodataStatus = E('div', { 'aria-live': 'polite' });
		o = s.option(form.Flag, 'auto_update', _('Rule sets'),
			_('Automatically update geosite.dat and geoip.dat every day at 4:00 AM.'));
		o.default = '0';
		o.rmempty = false;
		const renderAutoUpdateFlag = o.renderWidget.bind(o);
		o.renderWidget = (section_id, option_index, cfgvalue) => E('div', {}, [
			this.geodataButton, ' ', renderAutoUpdateFlag(section_id, option_index, cfgvalue),
			this.geodataStatus
		]);

'''
replace_once(
    service,
    "\t\t// Not a UCI option: the rc.d link of the init script, which the switch\n",
    geodata_row + "\t\t// Not a UCI option: the rc.d link of the init script, which the switch\n",
    "rule-set status row"
)

replace_once(
    service,
    "\t\t\t\tthis.updateStatus(),\n\t\t\t\tthis.updateBoot(),",
    "\t\t\t\tthis.updateStatus(),\n\t\t\t\tthis.updateBoot(),\n\t\t\t\tthis.pollGeodataJob(),",
    "geodata status polling"
)
replace_once(
    service,
    "\t\t\tthis.updateStatus();\n\t\t\tthis.packagePolling = true;",
    "\t\t\tthis.updateStatus();\n\t\t\tthis.pollGeodataJob();\n\t\t\tthis.packagePolling = true;",
    "initial geodata status"
)

acl_data = json.loads(acl.read_text(encoding="utf-8"))
entry = acl_data["luci-app-dae"]
read_file = entry.setdefault("read", {}).setdefault("file", {})
write_file = entry.setdefault("write", {}).setdefault("file", {})
read_file["/usr/libexec/daeuniverse-geodata status"] = ["exec"]
write_file["/usr/libexec/daeuniverse-geodata start"] = ["exec"]
write_file["/usr/libexec/daeuniverse-geodata schedule"] = ["exec"]
acl.write_text(json.dumps(acl_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("Patched: RPC ACL")

messages = {
    "Rule sets": "规则集",
    "Automatically update geosite.dat and geoip.dat every day at 4:00 AM.": "每天凌晨 4 点自动更新 geosite.dat 和 geoip.dat。",
    "Update now": "立即更新",
    "Starting rule-set update…": "正在启动规则集更新…",
    "Updating rule sets…": "正在更新规则集…",
    "Rule sets updated.": "规则集已更新。",
    "Rule-set update failed.": "规则集更新失败。",
    "Rule sets have not been updated yet.": "尚未更新规则集。",
    "Geodata operation failed.": "规则集操作失败。",
    "Unable to update the automatic rule-set schedule.": "无法更新规则集自动更新计划。"
}

def append_messages(path, translations, is_template=False):
    data = path.read_text(encoding="utf-8")
    additions = []
    for msgid, translated in translations.items():
        marker = 'msgid ' + json.dumps(msgid, ensure_ascii=False)
        if marker in data:
            continue
        if is_template:
            additions.append(f'\nmsgid {json.dumps(msgid, ensure_ascii=False)}\nmsgstr ""\n')
        else:
            additions.append(
                f'\nmsgid {json.dumps(msgid, ensure_ascii=False)}\n'
                f'msgstr {json.dumps(translated, ensure_ascii=False)}\n'
            )
    if additions:
        path.write_text(data.rstrip() + "\n" + "".join(additions), encoding="utf-8")
        print("Updated translations:", path)
    else:
        print("Already translated:", path)

append_messages(pot, messages, True)
append_messages(po, messages)

print("\nGeodata update patch applied.")
print("Rebuild luci-lib-daeuniverse and luci-app-dae to include the changes.")
PY
