# CodeMentor AI — Aplikasi Mobile (Flutter)

Aplikasi mobile CodeMentor AI: konsultasi error kode dengan AI, kuis onboarding,
dan riwayat konsultasi. Project ini **meniru UI/UX web** (`src/` pada repo root)
dan memakai **backend Next.js yang sama** (tidak ada endpoint baru).

> Status: dikerjakan bertahap. Step 1 (tema) dan Step 2 (Dashboard + bottom
> navigation) sudah selesai; Chat, Kuis, dan Riwayat menyusul.

## Menjalankan

```bash
flutter pub get
flutter run
```

Alamat backend bisa diganti tanpa mengubah kode (berguna untuk server lokal):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Default: `https://code-mentor-ai-zeta-three.vercel.app` (lihat
`lib/core/constants/api_constants.dart`).

Pemeriksaan mutu:

```bash
flutter analyze
flutter test
```

Probe manual (menembak jaringan sungguhan, **bukan** bagian `flutter test` biasa):

```bash
flutter test tool/login_probe.dart       # login NextAuth ke produksi
flutter test tool/dashboard_probe.dart   # GET /api/admin/stats & /api/dashboard/stats
flutter test tool/event_probe.dart       # reaktivitas status sesi
flutter test tool/scope_probe.dart       # NextAuthRiverpodScope
```

## Struktur

```
lib/
├── main.dart                    # ProviderScope + NextAuthRiverpodScope + CodeMentorApp
├── core/
│   ├── constants/               # base URL, nama cookie, daftar bahasa, endpoint
│   ├── network/                 # Dio: DioHttpClient (untuk paket auth) + createApiDio
│   ├── router/                  # AppRoutes + GoRouter (StatefulShellRoute 4 tab)
│   ├── theme/                   # AppColors & AppTheme (token web: HSL + app shell)
│   └── widgets/                 # AppLogo, GradientButton, ComingSoonView
└── features/
    ├── auth/                    # repository, snapshot status, splash, login
    ├── dashboard/               # domain/data/presentation statistik
    ├── chat/                    # (Step 3) UI chat
    ├── history/                 # (Step 5) riwayat konsultasi
    ├── quiz/                    # (Step 4) kuis onboarding
    ├── profile/                 # identitas user + keluar
    └── shell/                   # kerangka app: bottom navigation
```

## Keputusan teknis penting

- **Autentikasi memakai COOKIE NextAuth v4** (bukan `Authorization: Bearer`).
  Nama cookie mengikuti protokol: `__Secure-next-auth.session-token` (HTTPS) dan
  `next-auth.session-token` (HTTP). Paket: `flutter_next_auth_riverpod` +
  `flutter_next_auth_core` (implementasi `HttpClient`-nya ada di `core/network`).
- **Status login dipantau sendiri** lewat `authSnapshotProvider`
  (`lib/features/auth/data/auth_snapshot.dart`) yang berlangganan `client.eventBus`.
  Provider bawaan paket (`statusProvider`) tidak reaktif (dibuktikan
  `tool/event_probe.dart`).
* Satu instance `NextAuthClient` dibuat di `main.dart`, di-override ke
  `ProviderScope`, lalu diteruskan ke `NextAuthRiverpodScope`.
* **Dua palet warna web disalin apa adanya**: token Tailwind HSL untuk halaman
  publik (login, aksen crimson `#DD1D4A`) dan token "app shell" untuk area setelah
  login (permukaan `#0A0B14`/`#0F1119`, sidebar `#05060A`, gradien brand
  `#FF3B6B → #FF6B35`).
* **Font**: Inter (teks), JetBrains Mono (label/eyebrow), Space Grotesk
  (wordmark) — sama dengan web. Dipasang lewat paket `google_fonts`
  (`AppTheme.mono(...)`, `AppTheme.display(...)`, `interTextTheme`). Di test,
  pengunduhan font dimatikan (`GoogleFonts.config.allowRuntimeFetching = false`).
* **Tombol primer = putih (`AppTheme.paperButtonStyle`)**, meniru
  `Button variant="primary"` web (`bg-paper text-ink`). Warna crimson dipakai
  sebagai aksen (checkbox, border fokus, eyebrow, badge) dan tersedia sebagai
  `AppTheme.accentButtonStyle`. CTA di area aplikasi memakai gradien brand
  (`GradientButton`).
* **Dashboard**: `/dashboard` di web khusus admin; di mobile tab "Dashboard"
  ditampilkan untuk semua peran, hanya isinya yang menyesuaikan
  (admin → `GET /api/admin/stats`, user → `GET /api/dashboard/stats`).
* **Bottom navigation** (padanan sidebar web): Dashboard · Chat AI · Riwayat ·
  Profil, memakai `StatefulShellRoute.indexedStack` supaya posisi tiap tab tidak
  hilang saat berpindah.

## Kontrak API yang dipakai

| Endpoint                   | Dipakai di | Catatan                                        |
| -------------------------- | ---------- | ---------------------------------------------- |
| `POST /api/auth/...`       | Login      | cookie sesi + CSRF (via `flutter_next_auth_core`) |
| `GET /api/dashboard/stats` | Dashboard  | statistik pribadi; belum login tetap 200       |
| `GET /api/admin/stats`     | Dashboard  | statistik global, `403` bila bukan admin       |
| `POST /api/chat`           | Step 3     | `sourceCode`, `language`, `errorMessage`       |
| `POST /api/quiz/submit`    | Step 4     | `{ score, preference }`, 401 bila belum login   |
| `GET /api/history`         | Step 5     | `?language=&limit=&id=`, 401 bila belum login   |

## Test yang tersedia

| Berkas                          | Isi                                                          |
| ------------------------------- | ------------------------------------------------------------ |
| `test/widget_test.dart`         | alur login: redirect tanpa sesi, tombol dummy, validasi form    |
| `test/dashboard_stats_test.dart`| normalisasi respons API statistik (dua bentuk respons)         |
| `test/dashboard_screen_test.dart`| UI dashboard + bottom navigation (data palsu, tanpa jaringan) |

## Langkah berikutnya

1. **Step 3 (Chat)**: `lib/features/chat/presentation/chat_screen.dart` — bubble
   user/AI, pemilihan bahasa, `POST /api/chat` memakai cookie sesi.
2. **Step 4 (Kuis)**: 7 soal dari `src/lib/quiz-questions.ts` +
   `POST /api/quiz/submit`.
3. **Step 5 (Riwayat)**: `GET /api/history` + hapus riwayat.
4. Sebelum build APK: `minSdkVersion` 23 (kebutuhan `flutter_secure_storage`).
