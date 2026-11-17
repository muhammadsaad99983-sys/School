import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'ui_auth.dart';
import 'ui_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FamilyApp());
  store.init();
}

class FamilyApp extends StatelessWidget {
  const FamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        Widget home;
        if (!store.loaded) {
          home = const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (store.users.isEmpty) {
          home = const SetupPage();
        } else if (store.current == null) {
          home = const LoginPage();
        } else {
          home = const HomePage();
        }
        return MaterialApp(
          title: tr('app'),
          debugShowCheckedModeBanner: false,
          themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.teal,
              brightness: Brightness.light),
          darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.teal,
              brightness: Brightness.dark),
          builder: (context, child) => Directionality(
            textDirection:
                appLang == 'ur' ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
          home: home,
        );
      },
    );
  }
}
