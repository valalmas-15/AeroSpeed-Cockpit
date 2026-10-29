# 🏎️ AeroSpeed Cockpit — Flutter Speedometer, Navigation & Amazfit Active 2 Vital Telemetry

Aplikasi dashboard cockpit speedometer futuristik yang dibangun menggunakan **Flutter**, dirancang khusus untuk berjalan di perangkat **Android** (serta iOS/Tablet) dalam tampilan horizontal (**Landscape HUD**).

---

## 📐 Layout 3 Kolom Horizontal

| 🧭 Kiri: Speedometer | 🗺️ Tengah: Maps & Rute | ❤️ Kanan: Tanda Vital (Amazfit) |
| :--- | :--- | :--- |
| **Speedometer Analog + Digital**<br>• Jarum neon & gauge melingkar glowing<br>• Angka digital besar high-contrast<br>• Switcher unit (KM/H & MPH)<br>• Max Speed, Avg Speed, Trip, Waktu<br>• Peringatan Batas Kecepatan (Overspeed)<br>• Indikator status satelit GPS | **Navigasi Rute Mirip Google Maps**<br>• Peta interaktif CartoDB Dark Matter / OSM<br>• Pencarian rute & tujuan (Nominatim / OSRM)<br>• HUD Navigasi Turn-by-Turn (arah belokan, nama jalan, jarak, ETA)<br>• Garis rute polyline bercahaya cyan<br>• Marker kendaraan berputar dinamis mengikuti heading kompas | **Sensor Detak Jantung Amazfit Active 2**<br>• Koneksi Bluetooth Low Energy (BLE)<br>• Animasi jantung berdenyut sesuai BPM asli<br>• Zona Detak Jantung (Warm Up, Fat Burn, Cardio, Peak)<br>• Grafik live gelombang ECG / Pulse<br>• Penghitung kalori aktif real-time (kcal)<br>• Modal scanner & status baterai jam |

---

## ⚡ Fitur Utama

1. **Horizontal Cockpit Lock**: Layar otomatis terkunci dalam mode lanskap (`sensorLandscape`), bar navigasi & status tersembunyi (*Immersive Sticky*), dan layar tetap menyala (*Wakelock*) selama berkendara.
2. **GPS Speedometer Presisi**: Menggunakan sensor geolokasi GPS hardware dengan filter eksponensial halus untuk mencegah fluktuasi angka saat diam atau berakselerasi.
3. **Pencarian Rute Seperti Google Maps**:
   - Cari tujuan dengan nama tempat/alamat.
   - Pilihan rute preset instan:
     - *Monas (Jakarta Pusat) ➔ Gelora Bung Karno (Senayan)*
     - *Bundaran HI ➔ Taman Impian Jaya Ancol*
     - *Gerbang Tol Pasteur ➔ Gedung Sate (Bandung)*
4. **Koneksi Amazfit Active 2 via BLE Standar**:
   - Amazfit Active 2 memancarkan protokol standar **Bluetooth SIG Heart Rate Service (UUID `0x180D`)** dan **Heart Rate Measurement (UUID `0x2A37`)**.
   - Mendukung pembacaan baterai jam (**Battery Service UUID `0x180F`**).
5. **Mode Demo / Simulasi Terintegrasi**:
   - Tombol **Simulasi Berkendara (Demo Drive)**: Menjalankan kendaraan di rute, menaikkan/menurunkan kecepatan, dan menggerakkan peta tanpa harus keluar ke jalan raya.
   - Tombol **Simulasi Amazfit (Demo)**: Menghasilkan fluktuasi detak jantung realistis untuk pengujian saat jam sedang di-charge atau di dalam ruangan.

---

## ⌚ Cara Menghubungkan Amazfit Active 2

Amazfit Active 2 (dengan Zepp OS) memiliki fitur bawaan untuk memancarkan detak jantung secara langsung ke perangkat Bluetooth sekitar:

1. **Melalui Aplikasi Zepp di Ponsel**:
   - Buka aplikasi **Zepp**.
   - Masuk ke tab **Profil** > pilih **Amazfit Active 2**.
   - Pilih menu **Pemantauan Kesehatan** atau **Detak Jantung Aktivitas**.
   - Aktifkan opsi **"Berbagi Detak Jantung"** (*Heart Rate Sharing / Heart Rate Broadcast*).
2. **Atau Melalui Jam Amazfit Active 2 Langsung**:
   - Buka **Pengaturan** di jam.
   - Masuk ke **Preferensi Latihan** (*Workout Settings*) > **Siaran Detak Jantung** (*Heart Rate Broadcast*).
   - Pilih **Aktifkan**.
3. **Hubungkan di Aplikasi AeroSpeed Cockpit**:
   - Di aplikasi ini, tekan ikon **Bluetooth** di pojok kanan atas (Panel Tanda Vital).
   - Klik tombol **Pindai Ulang**.
   - Pilih perangkat **Amazfit Active 2** dari daftar, lalu klik **Hubungkan**.
   - Angka BPM dan grafik detak jantung akan langsung tampil dan berdenyut secara real-time!

---

## 📱 Konfigurasi Android

File `android/app/src/main/AndroidManifest.xml` telah dilengkapi perizinan lengkap:
- `android.permission.ACCESS_FINE_LOCATION` (GPS akurasi tinggi)
- `android.permission.BLUETOOTH_SCAN` & `android.permission.BLUETOOTH_CONNECT` (Android 12+ API 31+)
- `android.permission.WAKE_LOCK` (layar tetap menyala)
- `android:screenOrientation="sensorLandscape"`

---

## 🚀 Cara Menjalankan Aplikasi

Pastikan SSD eksternal tempat Flutter SDK Anda (`/Volumes/alle`) sudah terhubung, kemudian buka terminal:

```bash
# 1. Masuk ke direktori proyek
cd /Users/alle/Speedometer

# 2. Ambil semua dependensi package
flutter pub get

# 3. Hubungkan HP Android via kabel data (USB Debugging ON) atau buka Android Emulator

# 4. Jalankan aplikasi
flutter run
```

Untuk mem-build APK rilis siap instal di Android:
```bash
flutter build apk --release
```
File APK akan berada di `build/app/outputs/flutter-apk/app-release.apk`.
