import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:godel_dpll/main.dart';

void main() {
  for (final p in [TargetPlatform.macOS]) {
    for (final w in [1000.0, 1100.0, 1280.0, 1440.0, 1920.0]) {
      testWidgets('$p $w', (t) async {
        debugDefaultTargetPlatformOverride = p;
        t.view.physicalSize = Size(w, 1400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final old = FlutterError.onError;
        FlutterError.onError = (d) { if (d.toString().contains('overflow')) debugPrint('DETAILS $p $w: ${d.toString()}'); };
        await t.pumpWidget(const GodelDpllApp());
        await t.runAsync(() => GoogleFonts.pendingFonts().timeout(const Duration(seconds: 30)));
        await t.pump();
        await t.pump();
        debugPrint('TITLE $p $w: ${t.getSize(find.text("Gödel-DPLL"))} row1=${t.getSize(find.byType(IntrinsicHeight).first)}');
        FlutterError.onError = old;
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
