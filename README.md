# ChatKit

Simulator chat bergaya iOS "liquid glass" untuk bikin konten video (TikTok/Reels).
Tampilannya orisinal, bukan tiruan app chat mana pun, dan semua hasil export
membawa tanda "Chat Simulasi" (label kecil di header + pola watermark tipis).

## Fitur

- Proyek tersimpan (lanjut edit kapan saja), duplikat, hapus
- Chat pribadi dan grup (nama + warna + foto per anggota)
- Status header: online, mengetik..., atau teks sendiri
- Latar belakang: 6 bawaan atau import dari galeri
- Pesan: teks, foto (dengan keterangan), stiker (dari foto), voice note,
  balasan, reaksi emoji, bintang, pesan dihapus, pemisah tanggal
- Voice note dari video, file audio, atau rekam langsung. Bentuk gelombang
  diambil dari audio asli; bisa diputar dan dijeda di preview
- Jam tiap pesan bisa diatur, status terkirim/diterima/dibaca (centang gaya sendiri)
- Tahan pesan: menu reaksi + balas, teruskan, salin, bintang, sematkan, laporkan, hapus
- Ketuk pesan: ubah isi, pengirim, jam, status, reaksi, urutan
- Mode rekam layar (sembunyikan kontrol editor)
- Export: gambar PNG/JPG, atau video MP4 dengan audio dan animasi gelombang

## Build APK

Push ke branch `main`, lalu ambil APK dari tab **Actions → Build APK → Artifacts**.
Workflow membuat folder `android/` otomatis (`flutter create`) dan menjalankan
`tool/patch_android.py` (izin mikrofon, nama app, minSdk 24).

## Struktur

- `lib/models.dart`, `lib/store.dart` — data dan penyimpanan
- `lib/audio_utils.dart`, `lib/media_utils.dart` — audio (FFmpeg), stiker, rasio foto
- `lib/widgets/` — kaca, bubble, tampilan chat
- `lib/screens/` — daftar proyek, editor, export, sheet pengaturan
