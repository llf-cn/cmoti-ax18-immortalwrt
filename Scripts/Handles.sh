#!/bin/bash
# Handles.sh - 编译前资源预置与补丁脚本

# 严格模式：任何命令失败或使用未定义变量时立即退出
set -euo pipefail

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

# 修改 qca-nss-drv 启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	sed -i 's/START=.*/START=85/g' "$NSS_DRV"
	echo "qca-nss-drv start order has been fixed!"
fi

# 修改 qca-nss-pbuf 启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	sed -i 's/START=.*/START=86/g' "$NSS_PBUF"
	echo "qca-nss-pbuf start order has been fixed!"
fi

# ---------------------------------------------------------------
# 中和 ath11k NSS mesh offload 补丁里的条件编译守卫（兜底）
#
# 背景：patches/nss/ath11k/300-ath11k-nss-mesh-offload-support.patch 用
#   #ifdef CPTCFG_ATH11K_NSS_MESH_SUPPORT 给 ath11k_ops 挂上 .config_mesh_offload_path，
#   而该成员在 mac80211.h 里受 CPTCFG_MAC80211_MESH 约束。
#   本配置关闭了 MAC80211_MESH，一旦 ATH11K_NSS_SUPPORT 被重新打开（上游默认 y）
#   就会出现 "no member named 'config_mesh_offload_path'" 编译错误。
#
# 做法：只替换宏名、不改行数，补丁的 hunk 计数不受影响，仍可正常应用；
#   改后的宏永远不会被定义，整段 NSS mesh 代码即被排除。
# ---------------------------------------------------------------
A11K_MESH_PATCH="./kernel/mac80211/patches/nss/ath11k/300-ath11k-nss-mesh-offload-support.patch"
if [ -f "$A11K_MESH_PATCH" ]; then
	sed -i 's/CPTCFG_ATH11K_NSS_MESH_SUPPORT/CPTCFG_ATH11K_NSS_MESH_SUPPORT_OFF/g' "$A11K_MESH_PATCH"
	echo "ath11k nss mesh offload guard has been disabled!"
fi

# ---------------------------------------------------------------
# 从 target DEFAULT_PACKAGES 中剔除不编译/不使用的默认包
#
# 背景：target/linux/qualcommax/Makefile 的 DEFAULT_PACKAGES 会把
#   kmod-ath11k / -ahb / -pci、kmod-fs-f2fs、f2fs-tools、
#   kmod-usb-serial-qualcomm 当作默认包带入。仅在 Config/*.txt 里写
#   "is not set" 无效 —— 实测最终 .config 里仍然是 =m（默认值覆盖了配置）。
#   因此在这里直接从源头删除 token。
#
# 注意：必须先删长名（kmod-ath11k-pci / -ahb）再删短名，否则短名的
#   \b 边界会匹配到 "-" 之前，留下 "-pci" / "-ahb" 残片。
# ---------------------------------------------------------------
TMK="./target/linux/qualcommax/Makefile"
if [ -f "$TMK" ]; then
	cp -f "$TMK" "$TMK.bak"
	sed -i \
		-e 's/\bkmod-ath11k-pci\b//g' \
		-e 's/\bkmod-ath11k-ahb\b//g' \
		-e 's/\bkmod-ath11k\b//g' \
		-e 's/\bf2fs-tools\b//g' \
		-e 's/\bkmod-fs-f2fs\b//g' \
		-e 's/\bkmod-usb-serial-qualcomm\b//g' \
		"$TMK"
	LEFT=$(grep -c "kmod-ath11k\|f2fs\|kmod-usb-serial-qualcomm" "$TMK" || true)
	echo "DEFAULT_PACKAGES trimmed, remaining refs: ${LEFT:-0}"
	grep -n "DEFAULT_PACKAGES +=" -A8 "$TMK" | head -12
fi

