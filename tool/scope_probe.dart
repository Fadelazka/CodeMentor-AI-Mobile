// PROBE sementara: membuktikan perilaku ProviderScope bersarang (nesting),
// karena NextAuthRiverpodScope membuat ProviderScope-nya sendiri.
//   flutter test tool/scope_probe.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final overrideTargetProvider = Provider<String>((ref) => 'default');

int stableInstanceCount = 0;
final stableProvider = Provider<Object>((ref) {
  stableInstanceCount++;
  return Object();
});

void main() {
  testWidgets('scope anak mewarisi override + state scope induk', (tester) async {
    String? seenFromChild;
    Object? outerInstance;
    Object? innerInstance;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [overrideTargetProvider.overrideWithValue('parent')],
        child: Consumer(
          builder: (context, ref, _) {
            outerInstance = ref.watch(stableProvider);
            // scope anak, meniru NextAuthRiverpodScope
            return ProviderScope(
              child: Consumer(
                builder: (context, innerRef, _) {
                  seenFromChild = innerRef.watch(overrideTargetProvider);
                  innerInstance = innerRef.watch(stableProvider);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    // ignore: avoid_print
    print(
      'override terlihat dari scope anak : $seenFromChild\n'
      'instance provider sama         : ${identical(outerInstance, innerInstance)}\n'
      'provider dibuat berapa kali    : $stableInstanceCount',
    );

    expect(seenFromChild, 'parent');
    expect(identical(outerInstance, innerInstance), isTrue);
    expect(stableInstanceCount, 1);
  });
}
