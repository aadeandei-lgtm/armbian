#!/bin/bash
# customize-image.sh — hook Armbian, dijalankan di dalam chroot sebelum image difinalkan.
#
# Armbian memanggilnya dengan POSITIONAL ARGUMEN, bukan environment variable:
#   chroot_sdcard /tmp/customize-image.sh "$RELEASE" "$LINUXFAMILY" "$BOARD" "$BUILD_DESKTOP" "$ARCH"
# (lib/functions/rootfs/customize.sh baris 34)
# Karena itu $BOARD/$RELEASE tidak ada sebagai variabel lingkungan di sini — harus
# dibaca dari $1..$5. Membaca "$BOARD" langsung menghasilkan string kosong.
#
# Mengapa file ini ada:
#   Build memakai BOARD=orangepi-rk3399, sehingga Armbian memilih rk3399-orangepi.dtb
#   sebagai DTB default. Board YS-A99/ZM-RK3399 (kernel menyebutnya "Bozz RK3399
#   Board", compatible "rockchip,rk3399-bozz") memakai pin-mux GMAC berbeda, sehingga
#   dengan DTB board lain Ethernet tidak ter-inisialisasi (gejala: 0 paket, NIC absen).
#   Firmware vendor 21.05 bekerja karena membawa rk3399-bozz.dtb.
set -e

RELEASE="${1:-}"
LINUXFAMILY="${2:-}"
BOARD="${3:-}"
BUILD_DESKTOP="${4:-}"
ARCH="${5:-}"

DTB_NAME="rk3399-bozz.dtb"             # nama DTB tujuan di /boot/dtb/rockchip/
DTB_SRC="/tmp/overlay/${DTB_NAME}"     # overlay di-bind ke /tmp/overlay oleh Armbian

echo "[yskg-dtbfix] argumen: RELEASE=$RELEASE LINUXFAMILY=$LINUXFAMILY BOARD=$BOARD ARCH=$ARCH"

# Hanya bertindak untuk board yang relevan; board lain dibiarkan apa adanya.
case "$BOARD" in
    orangepi-rk3399|yskg|yskj|bozz|rockchip64) ;;
    *) echo "[yskg-dtbfix] BOARD=$BOARD — tidak perlu intervensi"; exit 0 ;;
esac

if [ ! -f "$DTB_SRC" ]; then
    echo "[yskg-dtbfix] PERINGATAN: $DTB_SRC tidak ditemukan — DTB tidak dipasang"
    echo "[yskg-dtbfix] pastikan userpatches/overlay/$DTB_NAME ada di repo"
    exit 0
fi

# /boot/dtb adalah symlink ke dtb-<kernel>-<family>; salin ke KEDUANYA supaya tetap
# benar walau kernel berubah versi dan symlink belum terbentuk saat hook jalan.
INSTALLED=0
for d in /boot/dtb /boot/dtb-*; do
    [ -d "$d/rockchip" ] || continue
    install -m 644 "$DTB_SRC" "$d/rockchip/${DTB_NAME}"
    echo "[yskg-dtbfix]   -> $d/rockchip/${DTB_NAME}"
    INSTALLED=$((INSTALLED + 1))
done
[ "$INSTALLED" -gt 0 ] || echo "[yskg-dtbfix] PERINGATAN: tidak ada direktori dtb ditemukan di /boot"

# Arahkan U-Boot ke DTB tersebut. boot.cmd memuat berkas dtb/${fdtfile}.
if [ -f /boot/armbianEnv.txt ]; then
    if grep -q '^fdtfile=' /boot/armbianEnv.txt; then
        sed -i "s|^fdtfile=.*|fdtfile=${DTB_NAME}|" /boot/armbianEnv.txt
    else
        echo "fdtfile=${DTB_NAME}" >> /boot/armbianEnv.txt
    fi
    echo "[yskg-dtbfix] fdtfile=$(grep '^fdtfile=' /boot/armbianEnv.txt | cut -d= -f2)"
else
    echo "[yskg-dtbfix] PERINGATAN: /boot/armbianEnv.txt tidak ada"
fi

# Verifikasi ulang dari dalam chroot: gagalkan build kalau DTB tidak terpasang,
# supaya tidak menghasilkan image tanpa perbaikan yang baru ketahuan saat boot.
if [ -f "/boot/dtb/rockchip/${DTB_NAME}" ]; then
    SZ=$(stat -c %s "/boot/dtb/rockchip/${DTB_NAME}")
    echo "[yskg-dtbfix] terverifikasi: ${SZ} byte"
    [ "$SZ" = "75131" ] || { echo "[yskg-dtbfix] ERROR: ukuran DTB tak terduga ($SZ)"; exit 1; }
else
    echo "[yskg-dtbfix] ERROR: DTB tidak ada di /boot/dtb/rockchip/${DTB_NAME}"
    exit 1
fi

# Jejak audit di dalam image.
{
    echo "yskg-dtbfix RELEASE=$RELEASE LINUXFAMILY=$LINUXFAMILY BOARD=$BOARD"
    echo "DTB=${DTB_NAME} dipasang oleh customize-image.sh"
} >> /etc/armbian-release 2>/dev/null || true

echo "[yskg-dtbfix] selesai"