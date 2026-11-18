#!/bin/bash
# config-yskg.conf.sh — konfigurasi build untuk board YS-A99 / ZM-RK3399.
#
# Pakai (dari dalam tree armbian/build):
#   ./compile.sh yskg            # nama file: userpatches/config-yskg.conf.sh
# atau tetap lewat workflow dengan config_board: yskg
#
# Mengapa: board "yskg" tidak ada di config/boards/ Armbian upstream, jadi
# memilihnya langsung lewat BOARD=yskg akan gagal saat compile. File ini
# mendefinisikan build memakai board upstream yang paling dekat
# (orangepi-rk3399) lalu memperbaiki DTB-nya lewat userpatches/customize-image.sh.
#
# Lihat juga: userpatches/customize-image.sh (pemasang DTB),
#             userpatches/overlay/rk3399-bozz.dtb (DTB dari firmware 21.05 YSKJ).

# Board upstream yang jadi basis build.
BOARD="orangepi-rk3399"
BRANCH="current"
RELEASE="trixie"

BUILD_MINIMAL="no"
BUILD_DESKTOP="no"
BUILD_ONLY="default"
EXPERT="yes"
KERNEL_CONFIGURE="no"
COMPRESS_OUTPUTIMAGE="sha"
SHARE_LOG="yes"

# Nama artefak agar tidak tertukar dengan build orangepi biasa.
BUILD_IMAGE_NAME="Armbian_${RELEASE}_${BOARD}_yskg-dtbfix"
