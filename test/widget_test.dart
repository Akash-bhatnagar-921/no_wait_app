import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:no_wait_app/main.dart';

void main() {
  testWidgets('shows role selection when onboarding is complete and user is logged out',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Continue as Customer'), findsOneWidget);
    expect(find.text('Join as Professional'), findsOneWidget);
  });
}
