# 🏎️ AeroSpeed Cockpit — Flutter Speedometer, Offline Navigation & Amazfit Vital Telemetry

[![Download Release APK](https://img.shields.io/badge/Download-Release%20APK%20(Latest)-00E5FF?style=for-the-badge&logo=android&logoColor=black)](https://github.com/valalmas-15/AeroSpeed-Cockpit/releases/latest/download/app-release.apk)
[![GitHub Release](https://img.shields.io/github/v/release/valalmas-15/AeroSpeed-Cockpit?style=for-the-badge&color=10B981&label=Latest%20Release)](https://github.com/valalmas-15/AeroSpeed-Cockpit/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20(Landscape%20HUD)-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)

**AeroSpeed Cockpit** adalah aplikasi dashboard cockpit speedometer, navigasi rute offline mandiri, dan monitor tanda vital pintar yang dibangun dengan **Flutter**. Didesain khusus dalam orientasi horizontal (**Landscape HUD**) untuk dipasang di stang sepeda, dashboard sepeda motor, mobil, maupun perangkat navigasi berkendara.

---

## 📥 Download Aplikasi (Release APK)

Anda dapat langsung mengunduh dan menginstal aplikasi AeroSpeed Cockpit versi **Release APK** tanpa perlu kompilasi kode:

* 🚀 **[Download AeroSpeed Cockpit Release APK (app-release.apk)](https://github.com/valalmas-15/AeroSpeed-Cockpit/releases/latest/download/app-release.apk)** *(Direct Link)*
* 📦 **[Halaman Rilis GitHub (All Releases)](https://github.com/valalmas-15/AeroSpeed-Cockpit/releases)** *(Daftar Semua Versi)*

### 📲 Panduan Instalasi di HP Android:
1. Unduh file `app-release.apk` langsung ke smartphone Android Anda melalui link di atas.
2. Buka file APK yang telah diunduh.
3. Jika muncul dialog perizinan keamanan, pilih **Pengaturan / Setelan** lalu aktifkan **"Izinkan dari sumber ini"** (*Install Unknown Apps*).
4. Tekan **Pasang / Instal** hingga proses selesai.
5. Buka aplikasi **AeroSpeed Cockpit**, berikan izin akses **Lokasi (GPS)** dan **Perangkat Sekitar (Bluetooth)** agar speedometer dan sensor detak jantung berfungsi maksimal.

---

## 🧭 Menu Navigasi Utama (Hamburger Button)

Tombol menu hamburger (**☰**) di pojok kiri atas bilah status HUD memungkinkan pergantian layar secara instan:

1. **Dashboard Cockpit**: Tampilan utama cockpit 3 kolom (Speedometer & Sesi, Peta Navigasi Offline, dan Tanda Vital Amazfit).
2. **Riwayat Workout**: Daftar sesi latihan/perjalanan yang tersimpan rapi, dilengkapi ikon siluet rute PNG, metrik lengkap, dan penampil peta interaktif ala Strava.

---

## 📐 Layout 3 Kolom Horizontal (Dashboard Cockpit)

Aplikasi dirancang dengan rasio adaptif tanpa layout overflow (diuji pada layar Samsung Galaxy J6+ 1480×720 / 360dp height):

| 🧭 Kiri: Speedometer & Sesi | 🗺️ Tengah: Maps & Navigasi Offline | ❤️ Kanan: Tanda Vital (Amazfit) |
| :--- | :--- | :--- |
| • Speedometer analog gauge + angka digital<br>• Switcher unit (KM/H & MPH)<br>• Altimeter / Elevasi real-time (m / ft)<br>• Sistem Sesi Workout (Mulai, Jeda, Selesai)<br>• Ascent (+m) & Descent (-m)<br>• Max Speed & Average Speed<br>• Jarak Tempuh & Durasi Sesi<br>• Peringatan batas overspeed | • Mode Siang (*Day*) & Mode Malam (*Dark*)<br>• Peta offline mandiri + download per provinsi<br>• Semua klasifikasi jalan (arteri, kolektor, gang)<br>• Cold-boot offline map guarantee<br>• Pencarian rute (Google Maps link, preset, tap peta)<br>• Navigasi Turn-by-Turn bersuara arah & jarak<br>• Kompas heading dinamis & auto-reroute | • Koneksi BLE Amazfit Active 2 (SIG UUID `0x180D`)<br>• Detak jantung (BPM) real-time berdenyut<br>• Grafik live gelombang ECG / Pulse<br>• Penghitung kalori terbakar aktif (kcal)<br>• Indikator baterai jam pintar (%)<br>• Mode simulasi demo detak jantung |

---

## ⚡ Fitur-Fitur Unggulan

### 1. 🚴 Sistem Sesi Berkendara (Workout Session Lifecycle)
- **Pengingat Awal Sesi**: Jika sesi belum dimulai, panel kiri menampilkan banner peringatan *"SESI BELUM DIMULAI"* dan tombol besar **MULAI SESI BERKENDARA**.
- **Kontrol Perekaman Lengkap**:
  - **Mulai Sesi**: Mengaktifkan penghitung waktu durasi, jarak tempuh GPS, elevasi gain/loss, dan akumulasi kalori.
  - **Jeda Sesi (Pause)**: Menjeda perekaman sehingga pergerakan saat istirahat/lampu merah tidak mengacaukan statistik rata-rata.
  - **Selesai Sesi (Finish)**: Memunculkan popup dialog konfirmasi ringkasan sesi dengan opsi batal atau simpan ke riwayat.
- **Isolasi Perekaman**: Hanya rute dan metrik yang terekam saat sesi aktif yang akan masuk ke riwayat penyimpanan.

### 2. 🗺️ Peta Offline Mandiri & Manajer Unduhan Provinsi
- **Tampilan Peta Mode Siang (Default)**: Menghadirkan warna peta siang yang cerah, kontras tinggi, dan nyaman dilihat di bawah terik sinar matahari. Tersedia opsi beralih ke Mode Malam (*Dark HUD*) kapan saja.
- **Jaringan Jalan Vektor Lengkap**: Menampilkan seluruh klasifikasi jalan, mulai dari jalan tol, jalan arteri utama, jalan kolektor, jalan lokal, hingga jalan lingkungan/perumahan.
- **Cold-Boot Offline**: Peta dan POI tetap muncul seketika saat aplikasi baru dibuka dari nol tanpa sambungan internet sama sekali.
- **Popup Manajer Unduhan Peta**:
  - **Pembaruan & Hapus Peta**: Menampilkan daftar provinsi yang sudah diunduh di perangkat, status update harian, tombol cek pembaruan, dan tombol hapus data provinsi.
  - **Daftar Peta Siap Unduh**: Menyediakan katalog paket peta per provinsi di Indonesia (DI Yogyakarta, Jawa Tengah, Jawa Timur, DKI Jakarta, Jawa Barat, Banten, Bali, dll.) dengan estimasi ukuran MB.

### 3. 🏁 Riwayat Workout & Penampil Rute ala Strava
- **Ikon Siluet Rute PNG Otomatis**: Setiap kali sesi selesai disimpan, rute koordinat GPS aktual yang dilalui dirasterisasi secara lokal menjadi file gambar PNG siluet bercahaya neon cyan dengan titik awal hijau (*Start*) dan titik finis merah (*End*).
- **Preview Cepat di Daftar Riwayat**: Bentuk jalur perjalanan langsung terlihat pada thumbnail kartu riwayat sebelum membuka peta detail.
- **Penampil Peta Riwayat Interaktif (Map Viewer)**:
  - Layar peta rute tersendiri dengan latar grid taktis.
  - Menampilkan jalur GPS aktual yang dilalui secara presisi di atas peta jalan.
  - Tombol **KEMBALI** yang ramah tombol fisik/gesture back Android (`PopScope`).
  - Toggle mode Siang / Malam.
  - Bilah HUD metrik lengkap di bagian bawah: Jarak Tempuh, Durasi, Kecepatan Rata-rata, Max Speed, Elevasi (+/-), Kalori, dan Rata-rata Detak Jantung.

### 4. 🛰️ Navigasi Pintar & Mesin Routing Offline
- **Pencarian Fleksibel**:
  - Salin-tempel tautan Google Maps (shortlink `maps.app.goo.gl` atau URL panjang `@lat,lng`).
  - Input koordinat desimal langsung (`-7.7956, 110.3695`).
  - Pilihan rute preset instan destinasi populer.
  - Mengetuk langsung titik di peta (*Tap on Map to Navigate*).
- **Turn-by-Turn Guidance**: Menampilkan rambu belokan visual, nama jalan berikutnya, jarak ke maneuver, dan estimasi waktu tiba (ETA).
- **Deteksi Keluar Jalur (Off-Route)**: Mendeteksi jika pengemudi salah belok atau mengambil rute alternatif dan menghitung ulang rute secara otomatis.

### 5. ❤️ Telemetri Amazfit Active 2 via BLE Standar
- Menggunakan protokol resmi **Bluetooth SIG Heart Rate Service (UUID `0x180D`)** dan **Heart Rate Measurement (UUID `0x2A37`)**.
- Mendukung pemantauan daya baterai jam (**Battery Service UUID `0x180F`**).
- Grafik gelombang ECG / denyut nadi real-time yang terus diperbarui.
- Perhitungan kalori aktif real-time berbasis profil detak jantung dan durasi aktivitas.

---

## ⌚ Panduan Menghubungkan Amazfit Active 2

Amazfit Active 2 (Zepp OS) memiliki fitur bawaan untuk memancarkan detak jantung ke perangkat sekitar:

1. **Melalui Aplikasi Zepp di Ponsel**:
   - Buka aplikasi **Zepp** di ponsel Anda.
   - Masuk ke tab **Profil** > pilih jam **Amazfit Active 2**.
   - Masuk ke menu **Pemantauan Kesehatan** atau **Detak Jantung Aktivitas**.
   - Aktifkan opsi **"Berbagi Detak Jantung"** (*Heart Rate Sharing / Broadcast*).
2. **Atau Melalui Jam Amazfit Active 2 Langsung**:
   - Buka **Pengaturan** pada jam.
   - Pilih **Preferensi Latihan** (*Workout Settings*) > **Siaran Detak Jantung** (*Heart Rate Broadcast*).
   - Tekan **Aktifkan**.
3. **Hubungkan di Aplikasi AeroSpeed Cockpit**:
   - Tekan panel Tanda Vital di sebelah kanan layar (atau ikon Bluetooth).
   - Klik tombol **Pindai Ulang**.
   - Pilih perangkat **Amazfit Active 2** dari daftar perangkat yang ditemukan, lalu klik **Hubungkan**.
   - Angka BPM dan grafik detak jantung akan langsung tersinkronisasi.

---

## 📱 Konfigurasi & Perizinan Android

File `android/app/src/main/AndroidManifest.xml` telah dikonfigurasi untuk performa optimal di kendaraan:
- `android.permission.ACCESS_FINE_LOCATION` (GPS hardware akurasi tinggi)
- `android.permission.ACCESS_COARSE_LOCATION` (Lokasi jaringan)
- `android.permission.BLUETOOTH_SCAN` & `android.permission.BLUETOOTH_CONNECT` (Android 12+ API 31+)
- `android.permission.WAKE_LOCK` (Mencegah layar redup atau mati selama berkendara)
- `android.permission.INTERNET` (Pembaruan ubin peta & download rute)
- `android:screenOrientation="sensorLandscape"` (Mengunci mode horizontal stabil)

---

## 🛠️ Pengembangan & Menjalankan dari Source Code

### Kebutuhan Sistem:
- Flutter SDK 3.x / Dart 3.x
- Android SDK (API level 21+)
- Kabel data USB dengan USB Debugging aktif

### Menjalankan Aplikasi:
```bash
# 1. Clone repository
git clone https://github.com/valalmas-15/AeroSpeed-Cockpit.git
cd AeroSpeed-Cockpit

# 2. Ambil seluruh dependensi package
flutter pub get

# 3. Jalankan automated test suite (61 unit tests)
flutter test

# 4. Jalankan aplikasi pada perangkat yang terhubung
flutter run
```

### Membangun File Release APK Mandiri:
```bash
flutter build apk --release
```
File APK siap instal akan dibuat di:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📁 Struktur Kode Utama

```
lib/
├── main.dart                               # Entry point, theme initialization & landscape lock
├── theme/
│   └── app_theme.dart                      # Skema warna Cyberpunk HUD, palette neon, glassmorphism
├── models/
│   ├── speed_data.dart                     # Model data kecepatan, altimeter, filter GPS
│   ├── route_model.dart                    # Model rute, turn-by-turn maneuvers, polyline
│   ├── vital_signs.dart                    # Model detak jantung, zona BPM, ECG buffer, kalori
│   ├── workout_session_model.dart          # Model sesi workout lengkap dengan path thumbnail rute
│   └── province_offline_model.dart         # Model katalog paket peta provinsi offline
├── providers/
│   └── dashboard_provider.dart             # State management pusat: HUD, navigasi, workout lifecycle
├── services/
│   ├── gps_speed_service.dart              # Service GPS hardware & kalkulator altimeter/elevasi
│   ├── ble_heart_rate_service.dart         # Komunikasi BLE Bluetooth SIG Amazfit Active
│   ├── offline_map_service.dart            # Cache ubin peta offline, deteksi konektivitas, download
│   ├── offline_routing_engine.dart         # Mesin pencarian rute & turn-by-turn offline
│   ├── offline_tile_service.dart           # Fallback ubin vektor jalan beresolusi tinggi
│   ├── route_thumbnail_service.dart        # Generator siluet rute PNG otomatis (PictureRecorder)
│   └── workout_history_service.dart        # Penyimpanan data sesi riwayat berkendara (SharedPreferences)
└── widgets/
    ├── speedometer/                        # Widget Speedometer analog arc, LCD digital & bar elevasi
    ├── map/                                # Widget Peta Carto/OSM, dialog download peta, search rute
    ├── vitals/                             # Widget Telemetri Amazfit, grafik ECG live, modal BLE
    └── history/                            # Widget Riwayat Sesi, thumbnail rute PNG, Strava map viewer
```

---

## 📄 Lisensi

Proyek ini dirilis di bawah lisensi [MIT License](LICENSE). Silakan gunakan, kembangkan, dan sesuaikan untuk kebutuhan kendaraan maupun personal Anda!
