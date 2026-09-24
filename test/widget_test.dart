import 'package:flutter_test/flutter_test.dart';

import 'package:nihongo_trainer/main.dart';

/// This file exists mainly so `flutter create` (run fresh by the build
/// workflow every time, to regenerate android/) never scaffolds its own
/// default `test/widget_test.dart` -- flutter create only writes files
/// that don't already exist, and its stock template references a `MyApp`
/// counter widget that isn't part of this project, which fails to even
/// compile against our real `NihongoTrainerApp`.
///
/// This one pumps the real app just long enough to get past the splash
/// screen's first frames and confirms nothing throws while doing so. It's
/// deliberately light (no pumpAndSettle) so it can't hang on a looping
/// animation or background music timer.
void main() {
  testWidgets('App launches without throwing', (tester) async {
    await tester.pumpWidget(const NihongoTrainerApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
