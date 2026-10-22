// The whole first start on a device or simulator, against a running `anyps5-tool remote` on the
// same network: welcome, finding the Mac, pairing, the pad. Run with flutter drive.
import 'dart:io';

import 'package:anyps5_remote/main.dart' as app;
import 'package:anyps5_remote/ui/pad_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 40)}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) throw TestFailure('never showed: $finder');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first start flows from welcome to the pad', (tester) async {
    SharedPreferences.setMockInitialValues({});
    app.main();
    await waitFor(tester, find.text('Başla'));
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('1-welcome');
    await tester.tap(find.text('Başla'));
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('2-searching');
    await waitFor(tester, find.textContaining('bulundu'));
    // A launcher that allows every phone skips the pairing step.
    await waitFor(tester, find.byWidgetPredicate((widget) => widget is Text && (widget.data?.contains('İzin Ver') == true || widget.data == 'Kol açılıyor…')));
    if (find.textContaining('İzin Ver').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 300));
      await binding.takeScreenshot('3-pairing');
    }
    await waitFor(tester, find.text('Hazır'));
    await waitFor(tester, find.text('Kol açılıyor…'));
    await binding.takeScreenshot('4-ready');
    await waitFor(tester, find.byType(PadScreen));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await binding.takeScreenshot('5-pad');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
