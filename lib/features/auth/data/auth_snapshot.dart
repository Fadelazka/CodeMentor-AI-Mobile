import 'dart:async';

import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_session.dart';
import 'auth_repository.dart';

/// Potret (snapshot) status login + data sesi yang dibaca langsung dari
/// `NextAuthClient`.
class AuthSnapshot {
  const AuthSnapshot({required this.status, this.session});

  final SessionStatus status;
  final AppSession? session;

  /// Sesi masih diperiksa / belum diketahui.
  bool get sedangMemeriksa =>
      status == SessionStatus.initial || status == SessionStatus.loading;

  bool get sudahLogin => status == SessionStatus.authenticated;
}

/// Sumber kebenaran status login untuk router dan UI.
///
/// CATATAN (hasil pengujian di `tool/event_probe.dart`): `statusProvider` milik
/// paket flutter_next_auth_riverpod TIDAK ikut berubah saat status sesi
/// berubah — event bus tetap mengirim `StatusChangedEvent` (terbukti), tetapi
/// state provider paket tertinggal di `initial`, sehingga router tidak pernah
/// berpindah dari splash. Karena itu di sini kita berlangganan langsung ke
/// `client.eventBus` (cara yang terbukti bekerja), bukan ke provider paket.
class AuthSnapshotNotifier extends Notifier<AuthSnapshot> {
  StreamSubscription<NextAuthEvent>? _subscription;

  @override
  AuthSnapshot build() {
    final client = ref.watch(nextAuthClientProvider);

    _subscription?.cancel();
    _subscription = client.eventBus.on<NextAuthEvent>().listen(_handleEvent);
    ref.onDispose(() => _subscription?.cancel());

    return AuthSnapshot(status: client.status, session: client.session);
  }

  void _handleEvent(NextAuthEvent event) {
    if (event is! StatusChangedEvent && event is! SessionChangedEvent) return;

    final client = ref.read(nextAuthClientProvider);
    state = AuthSnapshot(status: client.status, session: client.session);
  }
}

/// Status login reaktif (dipakai router, splash, halaman login, beranda).
final authSnapshotProvider = NotifierProvider<AuthSnapshotNotifier, AuthSnapshot>(
  AuthSnapshotNotifier.new,
);
