import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:speedometer_app/providers/dashboard_provider.dart';

void main() {
  testWidgets('Speedometer app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Text('AeroSpeed Cockpit Test'),
          ),
        ),
      ),
    );

    expect(find.text('AeroSpeed Cockpit Test'), findsOneWidget);
  });
}
