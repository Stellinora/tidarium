import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/ai/ai_gateway.dart';

void main() {
  test('AiQuota enforces the per-run limit', () {
    final quota = AiQuota(maxCallsPerRun: 2, maxCallsPerMinute: 100);

    expect(quota.tryAcquire(), isTrue);
    expect(quota.tryAcquire(), isTrue);
    expect(quota.tryAcquire(), isFalse);

    quota.reset();
    expect(quota.tryAcquire(), isTrue);
  });

  test('AiQuota enforces the per-minute limit', () {
    final quota = AiQuota(maxCallsPerRun: 100, maxCallsPerMinute: 2);
    final start = DateTime.utc(2026, 10, 23, 8);

    expect(quota.tryAcquire(now: start), isTrue);
    expect(
      quota.tryAcquire(now: start.add(const Duration(seconds: 10))),
      isTrue,
    );
    expect(
      quota.tryAcquire(now: start.add(const Duration(seconds: 20))),
      isFalse,
    );
    expect(
      quota.tryAcquire(now: start.add(const Duration(minutes: 2))),
      isTrue,
    );
  });
}
