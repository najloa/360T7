#!/bin/sh
# dae / honk shared Geo update
# Extend daeuniverse-pkg and reuse its existing job mechanism.

set -eu

ROOT="${1:-$PWD/feeds/honk_packages}"

PKG="$ROOT/luci-lib-daeuniverse/root/usr/libexec/daeuniverse-pkg"
SERVICE="$ROOT/luci-lib-daeuniverse/htdocs/luci-static/resources/daeuniverse/service.js"

[ -f "$PKG" ] || { echo "错误：找不到 $PKG"; exit 1; }
[ -f "$SERVICE" ] || { echo "错误：找不到 $SERVICE"; exit 1; }

for app in dae honk; do
	ACL="$ROOT/luci-app-$app/root/usr/share/rpcd/acl.d/luci-app-$app.json"
	[ -f "$ACL" ] || { echo "错误：找不到 $ACL"; exit 1; }
done

# 1. Extend the existing package manager
python3 - "$PKG" <<'PY'
import sys

path = sys.argv[1]

with open(path, encoding="utf-8") as f:
    src = f.read()

if "geodata_job()" in src:
    raise SystemExit("Geo 更新后端已经存在，请勿重复打补丁")

anchor = '[ "$#" -gt 0 ] || fail \'A command is required.\''

functions = r'''
# Update Geo data using the same background job and lock as apk upgrades.
geodata_update() {
	BASE=/usr/share/v2ray
	URL=https://gh-proxy.com/https://raw.githubusercontent.com/najloa/rules/release

	tmp=$(mktemp -d "$BASE/.geodata.XXXXXX") || {
		echo "Unable to create temporary directory."
		return 1
	}
	trap 'rm -rf "$tmp"' EXIT

	for name in geosite geoip; do
		wget -q -T 10 -O "$tmp/$name.dat" \
			"$URL/$name.dat" || {
			echo "Download $name.dat failed."
			return 1
		}

		wget -q -T 10 -O "$tmp/$name.dat.sha256sum" \
			"$URL/$name.dat.sha256sum" || {
			echo "Download $name checksum failed."
			return 1
		}
	done

	cd "$tmp" || return 1

	for name in geosite geoip; do
		sha256sum -c "$name.dat.sha256sum" || {
			echo "$name.dat checksum verification failed."
			return 1
		}
	done

	mkdir "$tmp/backup" || return 1

	for name in geosite geoip; do
		if [ -e "$BASE/$name.dat" ]; then
			cp -p "$BASE/$name.dat" "$tmp/backup/$name.dat" || {
				echo "Backup $name.dat failed."
				return 1
			}
		fi
	done

	for name in geosite geoip; do
		if ! mv -f "$tmp/$name.dat" "$BASE/$name.dat"; then
			echo "Replace $name.dat failed; restoring backups."

			for restore in geosite geoip; do
				if [ -e "$tmp/backup/$restore.dat" ]; then
					cp -p "$tmp/backup/$restore.dat" "$BASE/$restore.dat" ||
						echo "Restore $restore.dat failed."
				else
					rm -f "$BASE/$restore.dat"
				fi
			done

			return 1
		fi
	done

	echo "Geo data updated successfully."
}

geodata_job() {
	app=$1

	exec 9>>"$LOCK" || fail 'Unable to open the package lock.'
	if ! flock -n 9; then
		exec 9>&-
		status 1
		return
	fi

	json_init
	json_add_string app "$app"
	json_add_string id "$(date +%s)-$$"

	json_add_array packages
	json_add_string '' geosite.dat
	json_add_string '' geoip.dat
	json_close_array

	json_add_array before
	json_close_array

	state_file=$(mktemp /tmp/daeuniverse-pkg.XXXXXX) ||
		fail 'Unable to create Geo data state.'

	if ! json_dump > "$state_file" || ! mv -f "$state_file" "$STATE"; then
		rm -f "$state_file"
		fail 'Unable to save Geo data state.'
	fi

	log_file=$(mktemp /tmp/daeuniverse-pkg.XXXXXX) ||
		fail 'Unable to create Geo data log.'

	if ! mv -f "$log_file" "$LOG"; then
		rm -f "$log_file"
		fail 'Unable to reset Geo data log.'
	fi

	rm -f "$RC" || fail 'Unable to reset Geo data result.'

	(
		trap '' HUP

		if mkdir -p /usr/share/v2ray; then
			geodata_update
		else
			echo "Unable to create Geo data directory."
			false
		fi

		code=$?
		write_result "$code"
	) </dev/null >>"$LOG" 2>&1 &

	exec 9>&-
	status 0
}

'''

if src.count(anchor) != 1:
    raise SystemExit("错误：无法定位 daeuniverse-pkg 命令入口")

src = src.replace(anchor, functions + anchor, 1)

anchor = '\tupgrade)\n'

case = '''\tgeodata)
		[ "$#" -eq 1 ] || fail 'Geo data requires an application name.'
		valid_app "$1" || fail 'Invalid application.'
		geodata_job "$1"
		;;
'''

if src.count(anchor) != 1:
    raise SystemExit("错误：无法定位 upgrade 命令")

src = src.replace(anchor, case + anchor, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(src)
PY

# 2. Extend the shared LuCI page
python3 - "$SERVICE" <<'PY'
import sys

path = sys.argv[1]

with open(path, encoding="utf-8") as f:
    src = f.read()

if "handleGeodataUpdate()" in src:
    raise SystemExit("Geo 更新前端已经存在，请勿重复打补丁")

# Use a generic command error instead of incorrectly referring to apk.
old = "apk exited with code %s."
new = "Command exited with code %s."

if src.count(old) != 1:
    raise SystemExit("错误：无法唯一定位 packageCommand 错误提示")

src = src.replace(old, new, 1)

# Reuse the existing package-job completion mechanism.
old = """\t\t\telse if (status.code != null && this.packageProgress) {
\t\t\t\tif (status.code !== 0) {"""

new = """\t\t\telse if (status.code != null && this.packageProgress) {
				if (this.geodataJob) {
					this.finishPackageJob([
						E('pre', { 'class': 'du-log' }, status.log),
						E('p', {}, status.code === 0
							? _('Geo data updated.')
							: _('Geo data update failed (exit code %s).').format(status.code))
					], false);
				}
				else if (status.code !== 0) {"""

if src.count(old) != 1:
    raise SystemExit("错误：无法唯一定位任务完成处理区域")

src = src.replace(old, new, 1)

# Restore both buttons when a job finishes.
old = """\t\tthis.packageProgress = null;
		ui.showModal"""

new = """\t\tthis.packageProgress = null;
		this.geodataJob = false;
		if (this.geodataButton)
			this.geodataButton.disabled = false;
		ui.showModal"""

if src.count(old) != 1:
    raise SystemExit("错误：无法定位 finishPackageJob")

src = src.replace(old, new, 1)

# Add the Geo update handler, reusing packageCommand and existing polling.
anchor = "\t/* Status and log */"

method = r'''
	/* Geo data */
	async handleGeodataUpdate() {
		if (this.packagePolling)
			return;

		this.geodataButton.disabled = true;
		this.geodataJob = true;
		this.packageLaunchError = null;
		this.showPackageJob({});

		let previous;

		try {
			previous = await this.packageCommand([ 'status' ]);
			if (previous.running)
				throw new Error(_('Another background task is running.'));
		}
		catch (error) {
			this.finishPackageJob(this.packageError(error), false);
			return;
		}

		this.packagePreviousJob = previous.id;

		try {
			const status = await this.packageCommand([ 'geodata', this.app.name ]);

			if (status.already_running) {
				this.finishPackageJob([
					E('p', {}, _('Another background task is running.'))
				], false);
				return;
			}

			this.showPackageJob(status);
		}
		catch (error) {
			if (error.exitCode != null || error.name === 'PermissionError') {
				this.finishPackageJob(this.packageError(error), false);
				return;
			}

			// The RPC reply may be lost after the background task starts.
			// Reuse the existing status polling to determine what happened.
			this.packageLaunchError = error;
		}

		this.packagePolling = true;
		this.packagePollFailure = null;
	},

'''

if src.count(anchor) != 1:
    raise SystemExit("错误：无法定位 Status and log 区域")

src = src.replace(anchor, method + anchor, 1)

# Add the button after the version field, for both applications.
anchor = """\t\t// Not a UCI option: the rc.d link of the init script, which the switch"""

ui = r'''
		// Shared Geo data update for dae and honk.
		this.geodataButton = E('button', {
			'class': 'btn cbi-button',
			'type': 'button',
			'click': () => this.handleGeodataUpdate()
		}, '立即更新');

		o = s.option(form.DummyValue, '_geodata', '规则集');
		o.renderWidget = () => E('div', {}, this.geodataButton);

'''

if src.count(anchor) != 1:
    raise SystemExit("错误：无法定位启动开关区域")

src = src.replace(anchor, ui + anchor, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(src)
PY

# 3. Grant both applications permission to start Geo updates.
python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])

for app in ("dae", "honk"):
    path = root / f"luci-app-{app}/root/usr/share/rpcd/acl.d/luci-app-{app}.json"

    with path.open(encoding="utf-8") as f:
        data = json.load(f)

    acl = data[f"luci-app-{app}"]

    acl["write"]["file"]["/usr/libexec/daeuniverse-pkg geodata *"] = ["exec"]

    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent="\t")
        f.write("\n")
PY

echo "dae / honk 共享 Geo 更新功能已添加。"
