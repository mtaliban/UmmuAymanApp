import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/api.dart';
import 'screens/splash_screen.dart';
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
        // Ukubwa wa maandishi ubaki kama kwenye muundo hata simu ikiwa na font kubwa
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.0)),
            child: child!,
          );
        },
        // Splash (nembo inajijenga + mstari wa bluu) kisha PIN au Nyumbani.
        home: SplashScreen(logged: logged),
      );
}
