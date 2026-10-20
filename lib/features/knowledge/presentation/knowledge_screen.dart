import 'package:flutter/material.dart';

import '../../../core/widgets/coming_soon.dart';

/// Halaman "Pengetahuan" — padanan `src/app/(app)/pengetahuan/page.tsx`.
///
/// Di web halaman ini berisi daftar bahasa + kumpulan error umum beserta
/// penjelasannya. Kerangka route (Fase 1) disiapkan lebih dulu; daftar isinya
/// menyusul pada fase berikutnya.
class KnowledgeScreen extends StatelessWidget {
  const KnowledgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonView(
      title: 'Base Pengetahuan',
      description:
          'Kumpulan error coding paling sering muncul, lengkap dengan contoh '
          'dan solusinya.',
      icon: Icons.menu_book_outlined,
    );
  }
}
