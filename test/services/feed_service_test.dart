import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/services/feed_service.dart';

void main() {
  group('FeedService.combineLatest4 Tests', () {
    test('Emits only when all 4 streams have emitted at least once', () async {
      final ctrlA = StreamController<String>();
      final ctrlB = StreamController<int>();
      final ctrlC = StreamController<bool>();
      final ctrlD = StreamController<double>();

      final List<String> emissions = [];

      final combined = FeedService.combineLatest4(
        ctrlA.stream,
        ctrlB.stream,
        ctrlC.stream,
        ctrlD.stream,
        (a, b, c, d) => '$a-$b-$c-$d',
      );

      final sub = combined.listen((val) {
        emissions.add(val);
      });

      ctrlA.add('A1');
      await pumpEventQueue();
      expect(emissions, isEmpty);

      ctrlB.add(10);
      await pumpEventQueue();
      expect(emissions, isEmpty);

      ctrlC.add(true);
      await pumpEventQueue();
      expect(emissions, isEmpty);

      ctrlD.add(3.14);
      await pumpEventQueue();
      expect(emissions, ['A1-10-true-3.14']);

      // New emission on single stream emits latest combination
      ctrlA.add('A2');
      await pumpEventQueue();
      expect(emissions, ['A1-10-true-3.14', 'A2-10-true-3.14']);

      ctrlB.add(20);
      await pumpEventQueue();
      expect(emissions, ['A1-10-true-3.14', 'A2-10-true-3.14', 'A2-20-true-3.14']);

      await sub.cancel();
      await ctrlA.close();
      await ctrlB.close();
      await ctrlC.close();
      await ctrlD.close();
    });

    test('Cancels subscriptions to underlying streams when combined stream is cancelled', () async {
      var aCancelled = false;
      var bCancelled = false;
      var cCancelled = false;
      var dCancelled = false;

      final ctrlA = StreamController<String>(onCancel: () => aCancelled = true);
      final ctrlB = StreamController<int>(onCancel: () => bCancelled = true);
      final ctrlC = StreamController<bool>(onCancel: () => cCancelled = true);
      final ctrlD = StreamController<double>(onCancel: () => dCancelled = true);

      final combined = FeedService.combineLatest4(
        ctrlA.stream,
        ctrlB.stream,
        ctrlC.stream,
        ctrlD.stream,
        (a, b, c, d) => '$a-$b-$c-$d',
      );

      final sub = combined.listen((_) {});
      await pumpEventQueue();

      expect(aCancelled, isFalse);

      await sub.cancel();
      await pumpEventQueue();

      expect(aCancelled, isTrue);
      expect(bCancelled, isTrue);
      expect(cCancelled, isTrue);
      expect(dCancelled, isTrue);

      await ctrlA.close();
      await ctrlB.close();
      await ctrlC.close();
      await ctrlD.close();
    });
  });
}
