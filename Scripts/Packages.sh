#!/bin/bash
# Packages.sh - 自定义软件包拉取脚本

# 严格模式：任何命令失败或使用未定义变量时立即退出
set -euo pipefail

# 安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=${4:-}
	local PKG_LIST=("$PKG_NAME" ${5:-})  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo ""

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		echo "Search directory: $NAME"
		local FOUND_DIRS=()
		mapfile -t FOUND_DIRS < <(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		if [ ${#FOUND_DIRS[@]} -gt 0 ]; then
			for DIR in "${FOUND_DIRS[@]}"; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done
		else
			echo "Not found directory: $NAME"
		fi
	done

	# git clone 失败时跳过该包，不中断整个编译流程（如仓库变私有或被删除）
	echo "Cloning: https://github.com/$PKG_REPO.git (branch: $PKG_BRANCH)"
	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git" || {
		echo "WARNING: Failed to clone $PKG_REPO, skipping."
		return
	}

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find "./$REPO_NAME/"*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf "./$REPO_NAME/"
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f "$REPO_NAME" "$PKG_NAME"
	fi
}

# OpenClash 与 Tailscale 均已移除：honk 接管透明代理，且在 TC hook / NFQUEUE 320 /
# 根 cgroup 的 sock_ops 槽位上互斥，不能与 OpenClash 共存。
#
# UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
#
# UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale"    "main"
# rm -f ./luci-app-tailscale/root/etc/config/tailscale
# rm -f ./luci-app-tailscale/root/etc/init.d/tailscale

# honk：官方只发预编译二进制，包配方放在本仓库 Package/honk/ 下，这里拷进 package 树
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -d "$REPO_ROOT/Package/honk" ]; then
	rm -rf ./honk
	cp -rf "$REPO_ROOT/Package/honk" ./honk
	echo "Copied custom package: honk"
else
	echo "WARNING: $REPO_ROOT/Package/honk not found, honk will NOT be built!"
fi

# 以下插件当前配置均未启用（CONFIG_PACKAGE_*=n），克隆它们只是白费构建时间，
# 其中 vnt 的仓库已删除，每次构建还会刷一条 "Failed to clone" 警告。故整段移除。
# 需要时重新加回来并同时在 Config/*.txt 里打开对应 CONFIG_PACKAGE_* 即可。
#
# UPDATE_PACKAGE "momo"        "nikkinikki-org/OpenWrt-momo"        "main"
# UPDATE_PACKAGE "nikki"       "nikkinikki-org/OpenWrt-nikki"       "main"
# UPDATE_PACKAGE "homeproxy"   "immortalwrt/homeproxy"              "master"
# UPDATE_PACKAGE "passwall"    "Openwrt-Passwall/openwrt-passwall"  "main" "pkg"
# UPDATE_PACKAGE "passwall2"   "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
# UPDATE_PACKAGE "ddns-go"     "sirpdboy/luci-app-ddns-go"          "main"
# UPDATE_PACKAGE "diskman"     "lisaac/luci-app-diskman"            "master"
# UPDATE_PACKAGE "easytier"    "EasyTier/luci-app-easytier"         "main"
# UPDATE_PACKAGE "mosdns"      "sbwml/luci-app-mosdns"              "v5"   "" "v2dat"
# UPDATE_PACKAGE "openlist2"   "sbwml/luci-app-openlist2"           "main"
# UPDATE_PACKAGE "partexp"     "sirpdboy/luci-app-partexp"          "main"
# UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent"         "master" "" "qt6base qt6tools rblibtorrent"
# UPDATE_PACKAGE "quickfile"   "sbwml/luci-app-quickfile"           "main"
# UPDATE_PACKAGE "vnt"         "lmq8267/luci-app-vnt"               "main"
