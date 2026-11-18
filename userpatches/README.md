# Perbaikan DTB board YS-A99 / ZM-RK3399 (`yskg`)

## Masalah

Image yang dihasilkan build ini **tidak menginisialisasi Ethernet** di board
YS-A99 / ZM-RK3399 (SoC RK3399).

Contoh gejala:
- `ip link` hanya menampilkan `lo`
- tidak ada paket sama sekali setelah boot, walau kabel terpasang
- pada uji jaringan: **0 paket** dalam jendela 12 menit

## Akar masalah

Build memakai `BOARD=orangepi-rk3399`:

```
config_board="orangepi-rk3399"
./compile.sh BOARD=orangepi-rk3399 BRANCH=current RELEASE=trixie
```

Karena itu Armbian memasang `rk3399-orangepi.dtb` sebagai DTB default, dan
`/boot/armbianEnv.txt` **tidak** mengisi `fdtfile`. `boot.scr` lalu memuat DTB
Orange Pi, yang pin-mux GMAC-nya berbeda dari board ini. Kernel RK3399 sendiri
mengenali board ini sebagai:

```
model = "Bozz RK3399 Board"
compatible = "rockchip,rk3399-bozz", "rockchip,rk3399"
```

Firmware pembanding dari vendor (`armbian_21.05_server_full.img.gz`) berhasil
karena membawa `rk3399-bozz.dtb`, bukan DTB Orange Pi.

## Perbaikan

| File | Fungsi |
|---|---|
| `userpatches/overlay/rk3399-bozz.dtb` | DTB board yang benar (75.131 byte) |
| `userpatches/customize-image.sh` | hook: pasang DTB ke `/boot/dtb*/rockchip/` dan set `fdtfile` |
| `userpatches/config-yskg.conf.sh` | preset build supaya konsisten & bisa dipanggil `./compile.sh yskg` |

Hook berjalan di chroot sebelum image difinalkan, jadi setiap build berikutnya
otomatis benar — tidak perlu graft manual lagi.

## Asal DTB

`rk3399-bozz.dtb` diekstrak dari firmware vendor yang terbukti bekerja:

- Sumber: `armbian_21.05_server_full.img.gz` (files.kos.org.cn, folder `YSKJ_RK3399/Armbian/`)
- Cara ekstrak: pindai pola FDT (`d0 0d fe ed`) di seluruh image — rootfs image
  tersebut terpotong (ext4 mengklaim 28,8 GB, berkas hanya 2,33 GB), sehingga
  mount/debugfs tidak bisa dipakai
- Offset ditemukan: `841089024`
- Ukuran: 75.131 byte
- MD5: `7ea2e82fc5505edc2a452224ca58ccc9`
- Validasi: `dtc -I dtb -O dts` → 3.882 baris, `ethernet@fe300000` = `rockchip,rk3399-gmac`

## Catatan penting

1. DTS untuk board ini **juga tersedia** di `unifreq/linux-6.18.y`:
   `arch/arm64/boot/dts/rockchip/rk3399-yskj.dts` (`model = "RK3399 YSKJ"`,
   1.029 baris) dan `rk3399-bozz-sw799.dts` (`model = "RK3399 SW799"`).
   Jangka panjang, lebih baik memasukkan DTS tersebut ke build (patch kernel +
   entri Makefile) daripada menempelkan DTB biner.
2. Perbaikan ini **hanya menyentuh DTB**. U-Boot pada image baru adalah
   `2022.07_armbian`, sedangkan firmware 21.05 memakai `2020.10-armbian`.
   Jika masalah boot masih muncul, langkah berikutnya adalah mengevaluasi U-Boot.
3. Belum ada uji boot end-to-end: box uji tidak tersedia saat perubahan ini dibuat.

## Cara pakai

Build seperti biasa (workflow `Build Armbian arm64 server image`), tidak perlu
mengubah input apa pun — hook aktif otomatis untuk board
`orangepi-rk3399` / `yskg`.

Verifikasi di dalam image hasil build:

```bash
ls -l /boot/dtb/rockchip/rk3399-bozz.dtb
grep '^fdtfile=' /boot/armbianEnv.txt
dtc -I dtb -O dts /boot/dtb/rockchip/rk3399-bozz.dtb | grep -m1 'model ='
# harus: model = "Bozz RK3399 Board";
```