import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matter_home/services/matter_channel.dart';
import 'package:matter_home/ui/theme.dart';

void main() {
  testWidgets('App theme and channel smoke test', (tester) async {
    expect(buildAppTheme(), isA<ThemeData>());
    expect(MatterChannel(), isNotNull);
  });
}
