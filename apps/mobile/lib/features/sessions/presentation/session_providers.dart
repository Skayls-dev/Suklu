import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_repository.dart';
import '../domain/session_model.dart';

final sessionByBookingIdProvider =
    FutureProvider.autoDispose.family<SessionModel?, String>((ref, bookingId) {
  return ref.watch(sessionRepositoryProvider).fetchSessionByBookingId(bookingId);
});

final sessionStreamProvider =
    StreamProvider.autoDispose.family<SessionModel?, String>((ref, sessionId) {
  return ref.watch(sessionRepositoryProvider).watchSession(sessionId);
});

final createRoomProvider = AsyncNotifierProvider.autoDispose
    .family<CreateRoomNotifier, ({String roomUrl, String sessionId})?, String>(
  CreateRoomNotifier.new,
);

class CreateRoomNotifier
    extends AutoDisposeFamilyAsyncNotifier<({String roomUrl, String sessionId})?, String> {
  @override
  Future<({String roomUrl, String sessionId})?> build(String bookingId) async {
    return null;
  }

  Future<({String roomUrl, String sessionId})?> create() async {
    state = const AsyncLoading();
    final nextState = await AsyncValue.guard(
      () => ref.read(sessionRepositoryProvider).createRoom(arg),
    );
    state = nextState;
    return nextState.valueOrNull;
  }
}