// PROBE (bukti pengujian) untuk dua temuan wiring Step 3:
//
// 1. `statusProvider` milik paket flutter_next_auth_riverpod TIDAK ikut berubah
//    walau eventBus mengirim `StatusChangedEvent`, sehingga router yang
//    bergantung padanya tidak pernah berpindah dari splash.
//    -> karena itu `authSnapshotProvider` (lib/features/auth/data/auth_snapshot.dart)
//       mendengarkan `client.eventBus` secara langsung.
// 2. Perilaku `ProviderScope` bersarang (dipakai NextAuthRiverpodScope) diuji di
//    tool/scope_probe.dart.
//
// Jalankan:  flutter test tool/event_probe.dart
import 'package:codementor_mobile/features/auth/data/auth_repository.dart';
import 'package:codementor_mobile/features/auth/domain/app_session.dart';
import 'package:codementor_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_next_auth_riverpod/next_auth_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/in_memory_secure_storage.dart';

void main() {
  testWidgets('event bus mengirim event, statusProvider paket tertinggal', (
    tester,
  ) async {
    FlutterSecureStoragePlatform.instance = InMemorySecureStorage();
    final client = AuthRepository.createNextAuthClient();

    final events = <String>[];
    client.eventBus
        .on<NextAuthEvent>()
        .listen((event) => events.add(event.runtimeType.toString()));

    WidgetRef? ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nextAuthClientProvider.overrideWithValue(client)],
        child: NextAuthRiverpodScope<AppSession>(
          client: client,
          child: Consumer(
            builder: (context, r, _) {
              ref = r;
              return const CodeMentorApp();
            },
          ),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final layar = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .whereType<String>()
          .toList();
      // ignore: avoid_print
      print(
        'f$i | client=${client.status} | events=$events | '
        'statusProvider=${ref!.read(statusProvider)} | layar=$layar',
      );
    }
  });
}
