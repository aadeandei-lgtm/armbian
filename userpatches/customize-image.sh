#!/bin/bash
# customize-image.sh — hook Armbian yang dijalankan di dalam chroot sebelum image difinalkan.
#
# Args: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# Mengapa file ini ada:
#   Build ini memakai BOARD=orangepi-rk3399, sehingga Armbian memilih DTB
#   rk3399-orangepi.dtb sebagai default. Board YS-A99/ZM-RK3399 (kernel menyebutnya
#   "Bozz RK3399 Board", compatible "rockchip,rk3399-bozz") memakai pin-mux GMAC
#   yang berbeda, sehingga dengan DTB board lain Ethernet tidak ter-inisialisasi
#   (gejala: 0 paket setelah link up, NIC tidak muncul).
#
#   Perbaikan: sisipkan DTB board yang benar dan arahkan fdtfile ke sana.
#   Firmware 21.05 (dari server YSKJ) bekerja karena memuat rk3399-bozz.dtb.
#
# Sumber DTB: /tmp/overlay/ berisi isi userpatches/overlay/ (lihat catatan di bawah).
set -e

BOARD_TARGET="yskg"                    # board yang hendak diperbaiki
DTB_NAME="rk3399-bozz.dtb"             # nama DTB tujuan di /boot/dtb/rockchip/
DTB_SRC="/tmp/overlay/${DTB_NAME}"

# Dua nama board yang dipakai build ini: board upstream (orangepi-rk3399)
# dan pilihan userpatches (yskg). Hook hanya bertindak untuk keduanya.
case "$BOARD" in
    orangepi-rk3399|yskg|yskj|bozz) ;;
    *) echo "[yskg-dtbfix] BOARD=$BOARD — tidak perlu intervensi"; exit 0 ;;
esac

echo "[yskg-dtbfix] memasang DTB board (BOARD=$BOARD RELEASE=$RELEASE)"

if [ ! -f "$DTB_SRC" ]; then
    echo "[yskg-dtbfix] PERINGATAN: $DTB_SRC tidak ditemukan — DTB tidak dipasang"
    echo "[yskg-dtbfix] pastikan userpatches/overlay/$DTB_NAME ada di repo"
else
    # /boot/dtb adalah symlink ke dtb-<kernel>-<family>; salin ke dua tempat agar
    # tetap benar walau kernel berubah dan symlink tidak terbentuk saat build.
    for d in /boot/dtb /boot/dtb-*; do
        [ -d "$d/rockchip" ] || continue
        install -m 644 "$DTB_SRC" "$d/rockchip/${DTB_NAME}"
        echo "[yskg-dtbfix]   -> $d/rockchip/${DTB_NAME}"
    done
fi

# Arahkan U-Boot ke DTB tersebut. boot.cmd memuat: load ... dtb/${fdtfile}
if [ -f /boot/armbianEnv.txt ]; then
    if grep -q '^fdtfile=' /boot/armbianEnv.txt; then
        sed -i "s|^fdtfile=.*|fdtfile=${DTB_NAME}|" /boot/armbianEnv.txt
    else
        echo "fdtfile=${DTB_NAME}" >> /boot/armbianEnv.txt
    fi
    echo "[yskg-dtbfix] fdtfile=$(grep '^fdtfile=' /boot/armbianEnv.txt | cut -d= -f2)"
fi

# Catat jejak agar mudah diaudit dari dalam image hasil build.
{
    echo "yskg-dtbfix RELEASE=$RELEASE LINUXFAMILY=$LINUXFAMILY BOARD=$BOARD"
    echo "DTB=${DTB_NAME} dipasang oleh customize-image.sh"
} >> /etc/armbian-release 2>/dev/null || true

echo "[yskg-dtbfix] selesai"
