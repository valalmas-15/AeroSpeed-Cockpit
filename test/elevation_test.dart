import 'package:flutter_test/flutter_test.dart';
import 'package:speedometer_app/models/speed_data.dart';

void main() {
  group('Elevation, Ascent, and Descent Model Tests', () {
    test('Default speed data values for altitude and gain', () {
      const data = SpeedData();
      expect(data.altitude, 0.0);
      expect(data.totalAscentMeters, 0.0);
      expect(data.totalDescentMeters, 0.0);
      expect(data.displayElevation, 0.0);
      expect(data.displayAscent, 0.0);
      expect(data.displayDescent, 0.0);
      expect(data.elevationUnitLabel, 'm');
    });

    test('Metric display conversion (km/h)', () {
      const data = SpeedData(
        unit: SpeedUnit.kmh,
        altitude: 142.5,
        totalAscentMeters: 45.0,
        totalDescentMeters: 12.0,
      );
      expect(data.displayElevation, 142.5);
      expect(data.displayAscent, 45.0);
      expect(data.displayDescent, 12.0);
      expect(data.elevationUnitLabel, 'm');
    });

    test('Imperial display conversion (mph -> feet)', () {
      const data = SpeedData(
        unit: SpeedUnit.mph,
        altitude: 100.0, // ~328.084 feet
        totalAscentMeters: 10.0, // ~32.8084 feet
        totalDescentMeters: 5.0, // ~16.4042 feet
      );
      expect(data.displayElevation, closeTo(328.084, 0.01));
      expect(data.displayAscent, closeTo(32.8084, 0.01));
      expect(data.displayDescent, closeTo(16.4042, 0.01));
      expect(data.elevationUnitLabel, 'ft');
    });

    test('copyWith updates elevation fields properly', () {
      const initial = SpeedData(altitude: 110.0);
      final updated = initial.copyWith(
        altitude: 125.0,
        totalAscentMeters: 15.0,
        totalDescentMeters: 0.0,
      );
      expect(updated.altitude, 125.0);
      expect(updated.totalAscentMeters, 15.0);
      expect(updated.totalDescentMeters, 0.0);
    });
  });
}
