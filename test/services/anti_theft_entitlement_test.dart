import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geowake2/services/anti_theft_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'free users cannot enable or configure anti-theft at service level',
    () async {
      final service = AntiTheftService.forTest(entitlement: () => false);

      await expectLater(
        service.setEnabled(true),
        throwsA(isA<AntiTheftDenied>()),
      );
      await expectLater(
        service.setSensitivity(AntiTheftSensitivity.high),
        throwsA(isA<AntiTheftDenied>()),
      );
      await expectLater(
        service.setChargerDetection(false),
        throwsA(isA<AntiTheftDenied>()),
      );
      expect(service.isEnabled, isFalse);
      expect(service.isMonitoring, isFalse);
    },
  );

  test('disabling remains available after entitlement lapses', () async {
    var pro = true;
    final service = AntiTheftService.forTest(entitlement: () => pro);
    await service.setEnabled(true);
    expect(service.isEnabled, isTrue);

    pro = false;
    await service.setEnabled(false);
    expect(service.isEnabled, isFalse);
  });

  test(
    'a persisted enabled setting cannot start without current Pro',
    () async {
      var pro = true;
      final service = AntiTheftService.forTest(entitlement: () => pro);
      await service.setEnabled(true);
      pro = false;

      await service.startMonitoring();
      expect(service.isMonitoring, isFalse);
    },
  );
}
