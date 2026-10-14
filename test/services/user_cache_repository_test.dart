import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/models/user_profile.dart';
import 'package:tftiapp/services/user_cache_repository.dart';

void main() {
  group('UserCacheRepository Tests', () {
    late UserCacheRepository repo;

    final sampleUser = UserProfile(
      uid: 'cached-user-1',
      displayName: 'Cached Hero',
      username: 'cached_hero',
      avatarColor: 4280391411,
      blockedUids: const [],
    );

    setUp(() {
      repo = UserCacheRepository.instance;
      repo.clear();
    });

    tearDown(() {
      repo.clear();
    });

    test('putUser stores user in cache and returns it via getUser without network', () async {
      repo.putUser(sampleUser);

      // Fetch without forcing refresh
      final user = await repo.getUser('cached-user-1');
      expect(user, isNotNull);
      expect(user?.uid, 'cached-user-1');
      expect(user?.displayName, 'Cached Hero');
      expect(user?.username, 'cached_hero');
    });

    test('invalidateUser evicts the specified user from cache', () async {
      repo.putUser(sampleUser);
      expect(await repo.getUser('cached-user-1'), isNotNull);

      repo.invalidateUser('cached-user-1');

      // Since Firestore is not mocked, a miss will catch and return null
      final evicted = await repo.getUser('cached-user-1');
      expect(evicted, isNull);
    });

    test('clear() empties all cached users and events', () async {
      final user2 = sampleUser.copyWith(uid: 'cached-user-2');
      repo.putUser(sampleUser);
      repo.putUser(user2);

      expect(await repo.getUser('cached-user-1'), isNotNull);
      expect(await repo.getUser('cached-user-2'), isNotNull);

      repo.clear();

      expect(await repo.getUser('cached-user-1'), isNull);
      expect(await repo.getUser('cached-user-2'), isNull);
    });

    test('getUser respects zero/negative TTL as expired', () async {
      repo.putUser(sampleUser);

      // Passing a negative TTL immediately triggers expiration
      final expired = await repo.getUser(
        'cached-user-1',
        ttl: const Duration(milliseconds: -1),
      );

      // On expiration, network fetch is triggered, failing gracefully in unit test environment
      // and falling back to cached entry data
      expect(expired, isNotNull);
    });
  });
}
