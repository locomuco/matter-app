import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/device_provider.dart';
import 'router.dart';
import 'services/device_store.dart';
import 'services/matter_channel.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final store   = await DeviceStore.open();
  final channel = MatterChannel();

  runApp(
    MultiProvider(
      providers: [
        Provider<MatterChannel>(create: (_) => channel),
        ChangeNotifierProvider(create: (_) => DeviceProvider(store, channel)),
      ],
      child: const MatterHomeApp(),
    ),
  );
}

class MatterHomeApp extends StatelessWidget {
  const MatterHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flux',
      debugShowCheckedModeBanner: false,
      theme:      buildAppTheme(brightness: Brightness.light),
      darkTheme:  buildAppTheme(brightness: Brightness.dark),
      themeMode:  ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
