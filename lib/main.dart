import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/api.dart';
import 'screens/pin_screen.dart';
import 'screens/shell.dart';
import 'services/notifications.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  try {
    await Notifications.init();
  } catch (_) {}
  final logged = await Api.i.hasSession();
  runApp(UmmuAymanApp(logged: logged));
}

class UmmuAymanApp extends StatelessWidget {
  final bool logged;
  const UmmuAymanApp({super.key, required this.logged});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ummu Ayman',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // App inafunguka moja kwa moja kwenye PIN (hakuna splash).
        home: logged ? const Shell() : const PinScreen(),
      );
}
