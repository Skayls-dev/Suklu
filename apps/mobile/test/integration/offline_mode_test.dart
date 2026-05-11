import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suklu_mobile/core/mixins/offline_guard_mixin.dart';
import 'package:suklu_mobile/core/providers/connectivity_provider.dart';
import 'package:suklu_mobile/core/widgets/offline_banner.dart';
import 'package:suklu_mobile/features/auth/domain/auth_user.dart';
import 'package:suklu_mobile/features/auth/domain/user_role.dart';
import 'package:suklu_mobile/features/auth/presentation/auth_providers.dart';
import 'package:suklu_mobile/features/booking/domain/booking_model.dart';
import 'package:suklu_mobile/features/booking/presentation/booking_providers.dart';
import 'package:suklu_mobile/features/booking/presentation/booking_screen.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  Future<AuthUser?> build() async {
    return const AuthUser(
      uid: 'student-1',
      email: 'student@suklu.test',
      displayName: 'Student',
      role: UserRole.student,
      isActive: true,
    );
  }
}

void main() {
  testWidgets('bookings s affichent depuis le cache quand hors ligne',
      (tester) async {
    final booking = BookingModel(
      id: 'booking-1',
      studentId: 'student-1',
      tutorId: 'tutor-1',
      subjectId: 'math',
      scheduledAt: DateTime(2026, 1, 1, 10),
      durationMinutes: 60,
      sessionType: SessionType.oneOnOne,
      status: BookingStatus.confirmed,
      totalAmount: 15000,
      currency: 'XOF',
      isFromCache: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          userBookingsProvider.overrideWith((ref) => Stream.value([booking])),
          isOnlineProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: BookingScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('math'), findsOneWidget);
    expect(find.text('Affichage du cache local'), findsOneWidget);
  });

  testWidgets('banniere hors ligne apparait quand connectivite perdue',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Hors ligne'), findsOneWidget);
  });

  testWidgets('creation de booking bloquee hors ligne', (tester) async {
    var called = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          home: _OfflineGuardHarness(
            onAction: () async {
              called = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('guard-button')));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.textContaining('Action impossible hors ligne'), findsOneWidget);
  });
}

class _OfflineGuardHarness extends ConsumerStatefulWidget {
  const _OfflineGuardHarness({required this.onAction});

  final Future<void> Function() onAction;

  @override
  ConsumerState<_OfflineGuardHarness> createState() =>
      _OfflineGuardHarnessState();
}

class _OfflineGuardHarnessState extends ConsumerState<_OfflineGuardHarness>
    with OfflineGuardMixin<_OfflineGuardHarness> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('guard-button'),
          onPressed: () {
            guardOnline(context, widget.onAction);
          },
          child: const Text('Submit'),
        ),
      ),
    );
  }
}
