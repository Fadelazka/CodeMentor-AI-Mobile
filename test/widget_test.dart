// Smoke test aplikasi CodeMentor AI (menggantikan test counter bawaan
// `flutter create` yang sudah tidak relevan karena `MyApp` sudah dihapus).
//
// Tujuannya memastikan WIRING Step 3 bekerja: ProviderScope +
// NextAuthRiverpodScope + router go_router + halaman login.
//
// Catatan: di `flutter test` semua request HTTP otomatis diblokir (selalu 400),
// sehingga status sesi berakhir `unauthenticated` dan router semestinya
// mengarahkan ke halaman login.
import 'package:codementor_mobile/features/auth/data/auth_repository.dart';
import 'package:codementor_mobile/features/auth/domain/app_session.dart';
import 'package:codementor_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/in_memory_secure_storage.dart';

/// Menyalakan pohon widget yang sama seperti `main.dart`, lalu memompa beberapa
/// frame: splash tampil -> pemeriksaan sesi -> status unauthenticated -> /login.
///
/// `refetchInterval` sengaja TIDAK diisi agar tidak ada timer yang menggantung
/// saat test berakhir.
Future<void> pumpCodeMentorApp(WidgetTester tester) async {
  final client = AuthRepository.createNextAuthClient();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [nextAuthClientProvider.overrideWithValue(client)],
      child: NextAuthRiverpodScope<AppSession>(
        client: client,
        child: const CodeMentorApp(),
      ),
    ),
  );

  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  setUpAll(() {
    // Di test tidak ada jaringan: matikan pengunduhan font Google supaya
    // google_fonts memakai font fallback tanpa mencoba HTTP.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    FlutterSecureStoragePlatform.instance = InMemorySecureStorage();
  });

  testWidgets('tanpa sesi tersimpan: router mengarahkan ke halaman login', (
    tester,
  ) async {
    await pumpCodeMentorApp(tester);

    expect(find.text('Selamat Datang Kembali'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('KATA SANDI'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Masuk dengan GitHub'), findsOneWidget);
  });

  testWidgets('tombol GitHub masih dummy: memunculkan pesan "segera hadir"', (
    tester,
  ) async {
    await pumpCodeMentorApp(tester);

    await tapVisible(tester, find.text('Masuk dengan GitHub'));
    await tester.pump(); // tampilkan SnackBar

    expect(find.textContaining('segera hadir'), findsOneWidget);
  });

  testWidgets('form kosong: muncul pesan validasi email & kata sandi', (
    tester,
  ) async {
    await pumpCodeMentorApp(tester);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Masuk'));

    expect(find.text('Email wajib diisi'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
  });
}
