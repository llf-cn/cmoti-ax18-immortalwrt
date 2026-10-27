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
#   kmod-usb-serial-qualcomm、automount 当作默认包带入。仅在 Config/*.txt
#   里写 "is not set" 无效 —— 实测最终 .config 仍然是 =m/=y（默认值与
#   DEPENDS 的 +pkg（等价于 select）会覆盖用户配置）。
#   因此在这里直接从源头剔除 token。
#
# automount 尤其关键：它的 DEPENDS 里带了
#   +kmod-usb-storage +kmod-usb-storage-extras +kmod-usb-storage-uas
#   +kmod-fs-ext4 +kmod-fs-exfat +kmod-fs-vfat +ntfs3-mount(→kmod-fs-ntfs3)
# 整条 USB 存储 / NTFS3 依赖链都是从它拉进来的。
#
# 注意 1：本脚本的工作目录是 ./wrt/package/（workflow 里先 cd 再调用），
#   所以 target 目录要用 ../target，不能用 ./target。
# 注意 2：必须先删长名（kmod-ath11k-pci / -ahb）再删短名，否则短名的
#   \b 边界会匹配到 "-" 之前，留下 "-pci" / "-ahb" 残片。
# ---------------------------------------------------------------
TMK=""
for CAND in "../target/linux/qualcommax/Makefile" "./target/linux/qualcommax/Makefile"; do
	if [ -f "$CAND" ]; then
		TMK="$CAND"
		break
	fi
done

if [ -n "$TMK" ]; then
	echo "Trimming DEFAULT_PACKAGES in: $TMK"
	cp -f "$TMK" "$TMK.bak"
	sed -i \
		-e 's/\bkmod-ath11k-pci\b//g' \
		-e 's/\bkmod-ath11k-ahb\b//g' \
		-e 's/\bkmod-ath11k\b//g' \
		-e 's/\bf2fs-tools\b//g' \
		-e 's/\bkmod-fs-f2fs\b//g' \
		-e 's/\bkmod-usb-serial-qualcomm\b//g' \
		-e 's/\bautomount\b//g' \
		"$TMK"
	LEFT=$(grep -c "kmod-ath11k\|f2fs\|usb-serial-qualcomm\|automount" "$TMK" || true)
	echo "DEFAULT_PACKAGES trimmed, remaining refs: ${LEFT:-0}"
	sed -n '/DEFAULT_PACKAGES +=/,/^$/p' "$TMK"
else
	echo "WARNING: qualcommax target Makefile not found, DEFAULT_PACKAGES untouched!"
	ls -d ../target/linux/*/ 2>/dev/null | head -5
fi

