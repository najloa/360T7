#!/bin/sh
# 为 luci-app-dae 增加规则集手动更新功能
# 仅修改 dae 页面，不影响 honk
# 使用 OpenWrt 自带 wget 和 sha256sum

set -eu

ROOT="${1:-$PWD/feeds/honk_packages}"
SERVICE="$ROOT/luci-lib-daeuniverse/htdocs/luci-static/resources/daeuniverse/service.js"
ACL="$ROOT/luci-app-dae/root/usr/share/rpcd/acl.d/luci-app-dae.json"
HELPER="$ROOT/luci-lib-daeuniverse/root/usr/libexec/daeuniverse-geodata"

[ -f "$SERVICE" ] || {
	echo "错误：找不到 $SERVICE"
	exit 1
}
[ -f "$ACL" ] || {
	echo "错误：找不到 $ACL"
	exit 1
}

mkdir -p "$(dirname "$HELPER")"

# 1. 新增规则集下载及校验脚本
cat > "$HELPER" <<'EOF'
#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

BASE=/usr/share/v2ray
LOCK=/tmp/dae-geodata.lock
STATE=/tmp/dae-geodata.state
URL=https://gh-proxy.com/https://raw.githubusercontent.com/najloa/rules/release

fail() {
	echo failed > "$STATE"
	rm -rf "$LOCK"
	exit 1
}

worker() {
	tmp=$(mktemp -d "$BASE/.geodata.XXXXXX") || fail
	trap 'rm -rf "$tmp"; rm -rf "$LOCK"' EXIT

	# 下载规则集及对应校验文件
	for name in geosite geoip; do
		wget -q --timeout=20 \
			-O "$tmp/$name.dat" \
			"$URL/$name.dat" || fail

		wget -q --timeout=20 \
			-O "$tmp/$name.dat.sha256sum" \
			"$URL/$name.dat.sha256sum" || fail
	done

	# 校验两个文件，任何一个失败都不替换旧文件
	cd "$tmp" || fail
	sha256sum -c geosite.dat.sha256sum >/dev/null 2>&1 || fail
	sha256sum -c geoip.dat.sha256sum >/dev/null 2>&1 || fail

	# 备份旧文件，替换失败时回滚
	mkdir -p "$tmp/backup" || fail

	for name in geosite geoip; do
		if [ -e "$BASE/$name.dat" ]; then
			mv "$BASE/$name.dat" "$tmp/backup/$name.dat" || fail
		fi
	done

	if ! mv "$tmp/geosite.dat" "$BASE/geosite.dat"; then
		[ ! -e "$tmp/backup/geosite.dat" ] ||
			mv "$tmp/backup/geosite.dat" "$BASE/geosite.dat"
		[ ! -e "$tmp/backup/geoip.dat" ] ||
			mv "$tmp/backup/geoip.dat" "$BASE/geoip.dat"
		fail
	fi

	if ! mv "$tmp/geoip.dat" "$BASE/geoip.dat"; then
		rm -f "$BASE/geosite.dat"
		[ ! -e "$tmp/backup/geosite.dat" ] ||
			mv "$tmp/backup/geosite.dat" "$BASE/geosite.dat"
		[ ! -e "$tmp/backup/geoip.dat" ] ||
			mv "$tmp/backup/geoip.dat" "$BASE/geoip.dat"
		fail
	fi

	echo success > "$STATE"
}

case "${1:-}" in
	start)
		mkdir -p "$BASE" || exit 1

		if ! mkdir "$LOCK" 2>/dev/null; then
			exit 1
		fi

		echo running > "$STATE"
		"$0" worker </dev/null >/dev/null 2>&1 &
		;;

	worker)
		worker
		;;

	status)
		if [ -f "$STATE" ]; then
			cat "$STATE"
		else
			echo failed
		fi
		;;

	*)
		exit 1
		;;
esac
EOF

chmod 755 "$HELPER"

# 2. 修改 ACL，允许 dae 页面执行规则集更新脚本
python3 - "$ACL" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path, encoding="utf-8") as f:
    data = json.load(f)

app = data["luci-app-dae"]

app["read"]["file"]["/usr/libexec/daeuniverse-geodata status"] = ["exec"]
app["write"]["file"]["/usr/libexec/daeuniverse-geodata start"] = ["exec"]

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent="\t")
    f.write("\n")
PY

# 3. 修改共享页面：仅 dae 显示规则集更新按钮
python3 - "$SERVICE" <<'PY'
import sys

path = sys.argv[1]

with open(path, encoding="utf-8") as f:
    src = f.read()

anchor = """\t/* Status and log */"""

methods = r'''
	/* Geodata: dae only */

	async handleGeodataUpdate() {
		const button = this.geodataButton;
		button.disabled = true;
		button.textContent = '下载中';

		try {
			const command = '/usr/libexec/daeuniverse-geodata';

			const start = await fs.exec(command, [ 'start' ]);
			if (start.code !== 0)
				throw new Error('Unable to start update');

			let status = 'running';

			while (status === 'running') {
				await new Promise(resolve => setTimeout(resolve, 1000));

				const result = await fs.exec(command, [ 'status' ]);
				if (result.code !== 0)
					throw new Error('Unable to read update status');

				status = result.stdout.trim();
			}

			if (status !== 'success')
				throw new Error('Update failed');

			button.textContent = '下载成功';
		}
		catch (err) {
			button.textContent = '下载失败';
		}
		finally {
			button.disabled = false;
		}
	},

'''

if src.count(anchor) != 1:
    raise SystemExit("错误：无法唯一定位 service.js 中的 Status and log 区域")

src = src.replace(anchor, methods + anchor, 1)

anchor = """\t\tthis.bootSwitch = E('input', {"""

ui = r'''
		// Geodata update is only shown on the dae page.
		if (name === 'dae') {
			this.geodataButton = E('button', {
				'class': 'btn cbi-button',
				'type': 'button',
				'click': () => this.handleGeodataUpdate()
			}, '立即更新');

			o = s.option(form.DummyValue, '_geodata', '规则集');
			o.renderWidget = () => E('div', {}, this.geodataButton);
		}

'''

if src.count(anchor) != 1:
    raise SystemExit("错误：无法唯一定位规则集按钮插入位置")

src = src.replace(anchor, ui + anchor, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(src)
PY

echo "规则集更新功能已添加。"
