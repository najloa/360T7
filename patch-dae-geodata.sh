#!/bin/sh
set -eu

ROOT=${1:-"$PWD/feeds/daeuniverse_packages"}
[ -d "$ROOT" ] || {
	printf '错误：找不到 feeds 目录：%s\n' "$ROOT" >&2
	exit 1
}

PKG="$ROOT/luci-lib-daeuniverse/root/usr/libexec/daeuniverse-pkg"
JS="$ROOT/luci-lib-daeuniverse/htdocs/luci-static/resources/daeuniverse/service.js"
ACL_DAE="$ROOT/luci-app-dae/root/usr/share/rpcd/acl.d/luci-app-dae.json"
ACL_HONK="$ROOT/luci-app-honk/root/usr/share/rpcd/acl.d/luci-app-honk.json"

for file in "$PKG" "$JS" "$ACL_DAE" "$ACL_HONK"; do
	[ -f "$file" ] || {
		printf '错误：找不到上游文件：%s\n' "$file" >&2
		exit 1
	}
done

WORK=$(mktemp -d)
rollback=0

cleanup() {
	rc=$?
	if [ "$rollback" -eq 1 ]; then
		i=0
		for file in "$PKG" "$JS" "$ACL_DAE" "$ACL_HONK"; do
			[ ! -f "$WORK/backup.$i" ] || cp -p "$WORK/backup.$i" "$file"
			i=$((i + 1))
		done
	fi
	rm -rf "$WORK"
	exit "$rc"
}
trap cleanup EXIT HUP INT TERM

# 先在临时目录完成全部变更和锚点校验；四个文件全部生成成功后才写回。
python3 - "$ROOT" "$WORK" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
work = Path(sys.argv[2])

paths = [
    root / "luci-lib-daeuniverse/root/usr/libexec/daeuniverse-pkg",
    root / "luci-lib-daeuniverse/htdocs/luci-static/resources/daeuniverse/service.js",
    root / "luci-app-dae/root/usr/share/rpcd/acl.d/luci-app-dae.json",
    root / "luci-app-honk/root/usr/share/rpcd/acl.d/luci-app-honk.json",
]
src = [p.read_text() for p in paths]

def once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"错误：{label} 锚点应匹配 1 次，实际 {count} 次；未写回任何文件")
    return text.replace(old, new, 1)

# 1. daeuniverse-pkg：沿用上游 LOCK / STATE / LOG / RC / flock / status。
pkg = src[0]

pkg = once(
    pkg,
    '''\tjson_add_string app "$app"
\tjson_add_string id "$(date +%s)-$$"
\tjson_add_array packages
''',
    '''\tjson_add_string kind upgrade
\tjson_add_string app "$app"
\tjson_add_string id "$(date +%s)-$$"
\tjson_add_array packages
''',
    "APK 任务 kind"
)

pkg = once(
    pkg,
    "Upgrade worker exited without reporting its status.",
    "Background worker exited without reporting its status.",
    "worker 中断提示"
)

geo_functions = r'''
# Download and verify both files before replacing either installed data file.
geodata_update() {
	app=$1

	case "$app" in
		dae)
			data_dir=/usr/share/dae
			;;
		honk)
			data_dir=/etc/honk/data
			;;
		*)
			echo "Unknown application: $app"
			return 1
			;;
	esac

	mkdir -p "$data_dir" || {
		echo "Unable to create data directory: $data_dir"
		return 1
	}

	base='https://gh-proxy.com/https://raw.githubusercontent.com/najloa/rules/release'
	tmpdir=$(mktemp -d /tmp/daeuniverse-geodata.XXXXXX) || return 1

	(
		cd "$tmpdir" || exit 1

		# Download and verify both files first.
		for file in geosite.dat geoip.dat; do
			wget -q -T 10 -O "$file" "$base/$file" || {
				echo "Unable to download $file."
				exit 1
			}

			wget -q -T 5 -O "$file.sha256sum" "$base/$file.sha256sum" || {
				echo "Unable to download $file.sha256sum."
				exit 1
			}

			sha256sum -c "$file.sha256sum" || exit 1
		done

		# Stage verified files in the destination filesystem.
		stage_dir=$(mktemp -d "$data_dir/.daeuniverse-geodata.XXXXXX") || exit 1

		for file in geosite.dat geoip.dat; do
			cp "$file" "$stage_dir/$file" || exit 1
			chmod 0644 "$stage_dir/$file" || exit 1
		done

		# Replace installed files only after both staged files are ready.
		for file in geosite.dat geoip.dat; do
			mv -f "$stage_dir/$file" "$data_dir/$file" || exit 1
		done

		rmdir "$stage_dir" || exit 1
	)

	code=$?
	rm -rf "$tmpdir"

	[ "$code" -eq 0 ] || return "$code"

	reload_assets "$app" v2ray-geoip v2ray-geosite
}

geodata() {
	app=$1
	exec 9>>"$LOCK" || fail 'Unable to open the package lock.'
	if ! flock -n 9; then
		exec 9>&-
		status 1
		return
	fi

	json_init
	json_add_string kind geodata
	json_add_string app "$app"
	json_add_string id "$(date +%s)-$$"
	json_add_array packages
	json_add_string '' geosite.dat
	json_add_string '' geoip.dat
	json_close_array
	json_add_array before
	json_close_array

	state_file=$(mktemp /tmp/daeuniverse-pkg.XXXXXX) || fail 'Unable to create geodata state.'
	if ! json_dump > "$state_file" || ! mv -f "$state_file" "$STATE"; then
		rm -f "$state_file"
		fail 'Unable to save geodata state.'
	fi

	log_file=$(mktemp /tmp/daeuniverse-pkg.XXXXXX) || fail 'Unable to create the geodata log.'
	if ! mv -f "$log_file" "$LOG"; then
		rm -f "$log_file"
		fail 'Unable to reset the geodata log.'
	fi

	rm -f "$RC" || fail 'Unable to reset the geodata result.'

	(
		trap '' HUP
		if geodata_update "$app"; then
			code=0
		else
			code=$?
		fi
		write_result "$code"
	) </dev/null >>"$LOG" 2>&1 &

	exec 9>&-
	status 0
}
'''

pkg = once(
    pkg,
    "\nstatus() {\n",
    "\n" + geo_functions + "\nstatus() {\n",
    "Geo 数据后台任务函数插入位置"
)

pkg = once(
    pkg,
    '''\t\tjson_add_null id
\t\tjson_add_string app ''
''',
    '''\t\tjson_add_null id
\t\tjson_add_string kind ''
\t\tjson_add_string app ''
''',
    "status 空状态 kind"
)

pkg = once(
    pkg,
    '''\tstatus)
\t\t[ "$#" -eq 0 ] || fail 'Status takes no arguments.'
\t\tstatus 0
\t\t;;
\t*) fail 'Invalid command.' ;;
''',
    '''\tgeodata)
\t\t[ "$#" -eq 1 ] || fail 'Exactly one application is required.'
\t\tvalid_app "$1" || fail 'Invalid application.'
\t\tgeodata "$1"
\t\t;;
\tstatus)
\t\t[ "$#" -eq 0 ] || fail 'Status takes no arguments.'
\t\tstatus 0
\t\t;;
\t*) fail 'Invalid command.' ;;
''',
    "geodata 命令入口"
)

# 2. service.js：共用原有 packageCommand / 状态轮询 / modal。
js = src[1]

js = once(
    js,
    '''\tshowPackageJob(status, message) {
\t\tthis.packageLog = E('pre', { 'class': 'du-log', 'aria-live': 'polite' }, status.log || '');
\t\tthis.packageProgress = E('p', { 'class': 'spinning' }, message || _('Upgrading…'));
\t\tui.showModal(_('Upgrade'), [ this.packageProgress, this.packageLog ]);
\t},
''',
    '''\tshowPackageJob(status, message) {
\t\tconst title = this.packageJobKind === 'geodata' ? _('Geo data update') : _('Upgrade');
\t\tthis.packageLog = E('pre', { 'class': 'du-log', 'aria-live': 'polite' }, status.log || '');
\t\tthis.packageProgress = E('p', { 'class': 'spinning' }, message ||
\t\t\t(this.packageJobKind === 'geodata' ? _('Downloading geo data…') : _('Upgrading…')));
\t\tui.showModal(title, [ this.packageProgress, this.packageLog ]);
\t},
''',
    "showPackageJob"
)

js = once(
    js,
    '''\tasync handleUpgrade(packages) {
\t\tthis.checkButton.disabled = true;
\t\tthis.packageLaunchError = null;
''',
    '''\tasync handleUpgrade(packages) {
\t\tthis.packageJobKind = 'upgrade';
\t\tthis.checkButton.disabled = true;
\t\tthis.geodataButton.disabled = true;
\t\tthis.packageLaunchError = null;
''',
    "handleUpgrade 初始化"
)

js = once(
    js,
    '''\t\tthis.packagePreviousJob = previous.id;
\t\ttry {
\t\t\tconst status = previous.running ? previous :
''',
    '''\t\tthis.packagePreviousJob = previous.id;
\t\tif (previous.running)
\t\t\tthis.packageJobKind = previous.kind || 'upgrade';
\t\ttry {
\t\t\tconst status = previous.running ? previous :
''',
    "handleUpgrade 识别已有任务"
)

geo_handler = r'''
	async handleGeodataUpdate() {
		this.packageJobKind = 'geodata';
		this.checkButton.disabled = true;
		this.geodataButton.disabled = true;
		this.packageLaunchError = null;
		this.showPackageJob({}, _('Downloading geo data…'));
		let previous;
		try {
			previous = await this.packageCommand([ 'status' ]);
		}
		catch (error) {
			this.finishPackageJob(this.packageError(error), false);
			return;
		}

		this.packagePreviousJob = previous.id;
		if (previous.running)
			this.packageJobKind = previous.kind || 'upgrade';
		try {
			const status = previous.running ? previous :
				await this.packageCommand([ 'geodata', this.app.name ]);
			this.showPackageJob(status, previous.running || status.already_running
				? _('A background task is already running.') : null);
		}
		catch (error) {
			if (error.exitCode != null || error.name === 'PermissionError') {
				if (error.exitCode != null)
					error.message = _('Geo data update command exited with code %s.').format(error.exitCode);
				this.finishPackageJob(this.packageError(error), false);
				return;
			}
			// rpcd may restart after the worker has started but before its reply arrives.
			this.packageLaunchError = error;
		}
		this.packagePolling = true;
		this.packagePollFailure = null;
	},

'''

js = once(
    js,
    "\tasync pollPackageJob() {\n",
    geo_handler + "\tasync pollPackageJob() {\n",
    "Geo 更新前端处理函数插入位置"
)

js = once(
    js,
    '''\t\t\tif (status.running) {
\t\t\t\tthis.checkButton.disabled = true;
\t\t\t\tif (!this.packageProgress)
\t\t\t\t\tthis.showPackageJob(status, _('An upgrade is already running.'));
\t\t\t\telse if (this.packagePollFailure)
\t\t\t\t\tthis.packageProgress.replaceChildren(_('Upgrading…'));
''',
    '''\t\t\tif (status.running) {
\t\t\t\tthis.packageJobKind = status.kind || this.packageJobKind || 'upgrade';
\t\t\t\tthis.checkButton.disabled = true;
\t\t\t\tthis.geodataButton.disabled = true;
\t\t\t\tconst runningMessage = this.packageJobKind === 'geodata'
\t\t\t\t\t? _('A geo data update is already running.') : _('An upgrade is already running.');
\t\t\t\tif (!this.packageProgress)
\t\t\t\t\tthis.showPackageJob(status, runningMessage);
\t\t\t\telse if (this.packagePollFailure)
\t\t\t\t\tthis.packageProgress.replaceChildren(this.packageJobKind === 'geodata'
\t\t\t\t\t\t? _('Downloading geo data…') : _('Upgrading…'));
''',
    "poll running 分支"
)

js = once(
    js,
    '''\t\t\telse if (status.code != null && this.packageProgress) {
\t\t\t\tif (status.code !== 0) {
\t\t\t\t\tconst error = new Error(_('apk exited with code %s.').format(status.code));
\t\t\t\t\terror.output = status.log;
\t\t\t\t\tthis.finishPackageJob(this.packageError(error), false);
\t\t\t\t}
\t\t\t\telse {
''',
    '''\t\t\telse if (status.code != null && this.packageProgress) {
\t\t\t\tthis.packageJobKind = status.kind || this.packageJobKind || 'upgrade';
\t\t\t\tif (this.packageJobKind === 'geodata') {
\t\t\t\t\tthis.finishPackageJob([
\t\t\t\t\t\tE('pre', { 'class': 'du-log' }, status.log),
\t\t\t\t\t\tE('p', {}, status.code === 0
\t\t\t\t\t\t\t? _('Geo data updated.')
\t\t\t\t\t\t\t: _('Geo data update failed (exit code %s).').format(status.code))
\t\t\t\t\t], false);
\t\t\t\t}
\t\t\t\telse if (status.code !== 0) {
\t\t\t\t\tconst error = new Error(_('apk exited with code %s.').format(status.code));
\t\t\t\t\terror.output = status.log;
\t\t\t\t\tthis.finishPackageJob(this.packageError(error), false);
\t\t\t\t}
\t\t\t\telse {
''',
    "poll 完成分支"
)

js = once(
    js,
    '''\t\t\t\tif (this.packageLaunchError)
\t\t\t\t\tthrow this.packageLaunchError;
\t\t\t\tthis.packagePolling = false;
\t\t\t\tthis.checkButton.disabled = false;
''',
    '''\t\t\t\tif (this.packageLaunchError)
\t\t\t\t\tthrow this.packageLaunchError;
\t\t\t\tthis.packagePolling = false;
\t\t\t\tthis.checkButton.disabled = false;
\t\t\t\tthis.geodataButton.disabled = false;
\t\t\t\tthis.packageJobKind = null;
''',
    "poll 无任务复位"
)

js = once(
    js,
    '''\t\t\t\tif (this.packageProgress)
\t\t\t\t\tthis.packageProgress.replaceChildren(_('Waiting for the package manager to reconnect…'));
''',
    '''\t\t\t\tif (this.packageProgress)
\t\t\t\t\tthis.packageProgress.replaceChildren(this.packageJobKind === 'geodata'
\t\t\t\t\t\t? _('Waiting for the service manager to reconnect…')
\t\t\t\t\t\t: _('Waiting for the package manager to reconnect…'));
''',
    "poll 重连提示"
)

js = once(
    js,
    '''\t\t\tthis.finishPackageJob([
\t\t\t\tE('p', {}, _('Unable to read upgrade status. The job may still be running; reload to reconnect.')),
\t\t\t\t...this.packageError(error)
\t\t\t], false);
''',
    '''\t\t\tthis.finishPackageJob([
\t\t\t\tE('p', {}, this.packageJobKind === 'geodata'
\t\t\t\t\t? _('Unable to read geo data update status. The job may still be running; reload to reconnect.')
\t\t\t\t\t: _('Unable to read upgrade status. The job may still be running; reload to reconnect.')),
\t\t\t\t...this.packageError(error)
\t\t\t], false);
''',
    "poll 最终错误提示"
)

js = once(
    js,
    '''\tfinishPackageJob(nodes, reload) {
\t\tthis.packagePolling = false;
\t\tthis.checkButton.disabled = false;
\t\tthis.packageProgress = null;
\t\tui.showModal(_('Upgrade'), [ ...nodes,
''',
    '''\tfinishPackageJob(nodes, reload) {
\t\tconst title = this.packageJobKind === 'geodata' ? _('Geo data update') : _('Upgrade');
\t\tthis.packagePolling = false;
\t\tthis.checkButton.disabled = false;
\t\tthis.geodataButton.disabled = false;
\t\tthis.packageProgress = null;
\t\tthis.packageJobKind = null;
\t\tui.showModal(title, [ ...nodes,
''',
    "finishPackageJob"
)

js = once(
    js,
    '''\t\tthis.checkButton = E('button', {
\t\t\t'class': 'btn cbi-button', 'type': 'button',
\t\t\t'click': () => this.handleCheckUpdates()
\t\t}, _('Check for updates'));
''',
    '''\t\tthis.checkButton = E('button', {
\t\t\t'class': 'btn cbi-button', 'type': 'button',
\t\t\t'click': () => this.handleCheckUpdates()
\t\t}, _('Check for updates'));
\t\tthis.geodataButton = E('button', {
\t\t\t'class': 'btn cbi-button', 'type': 'button',
\t\t\t'click': () => this.handleGeodataUpdate()
\t\t}, _('Update geo data'));
''',
    "Geo 更新按钮定义"
)

js = once(
    js,
    '''\t\t\t\t: installed.find(pkg => pkg.name === name)?.version || _('Not installed')),
\t\t\t' ', this.checkButton, this.packageStatus
''',
    '''\t\t\t\t: installed.find(pkg => pkg.name === name)?.version || _('Not installed')),
\t\t\t' ', this.checkButton, ' ', this.geodataButton, this.packageStatus
''',
    "Geo 更新按钮显示"
)

# 3. 两份 ACL：仅在 write.file 增加 geodata 命令执行权限。
def patch_acl(text, label):
    return once(
        text,
        '''\t\t\t\t"/usr/libexec/daeuniverse-pkg upgrade *": [ "exec" ]''',
        '''\t\t\t\t"/usr/libexec/daeuniverse-pkg upgrade *": [ "exec" ],
\t\t\t\t"/usr/libexec/daeuniverse-pkg geodata *": [ "exec" ]''',
        label
    )

acl_dae = patch_acl(src[2], "dae ACL geodata 权限")
acl_honk = patch_acl(src[3], "honk ACL geodata 权限")

outputs = [pkg, js, acl_dae, acl_honk]
for i, content in enumerate(outputs):
    (work / f"new.{i}").write_text(content)

for i, path in enumerate(paths):
    if path.read_text() == outputs[i]:
        raise SystemExit(f"错误：文件已经包含本补丁内容或无需修改：{path}")

print("四个文件的变更均已生成，所有锚点匹配唯一。")
PY

# 保存原文件，随后写回；写回中途失败则由 trap 恢复全部原文件。
i=0
for file in "$PKG" "$JS" "$ACL_DAE" "$ACL_HONK"; do
	cp -p "$file" "$WORK/backup.$i"
	i=$((i + 1))
done

rollback=1
i=0
for file in "$PKG" "$JS" "$ACL_DAE" "$ACL_HONK"; do
	cat "$WORK/new.$i" > "$file"
	i=$((i + 1))
done
rollback=0

printf '%s\n' \
	"daeuniverse Geo 数据更新功能补丁已应用。" \
	"修改文件：" \
	"  luci-lib-daeuniverse/root/usr/libexec/daeuniverse-pkg" \
	"  luci-lib-daeuniverse/htdocs/luci-static/resources/daeuniverse/service.js" \
	"  luci-app-dae/root/usr/share/rpcd/acl.d/luci-app-dae.json" \
	"  luci-app-honk/root/usr/share/rpcd/acl.d/luci-app-honk.json"
