import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  runApp(const ChatKitApp());
}

class ChatKitApp extends StatelessWidget {
  const ChatKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF30B84A);
    return MaterialApp(
      title: 'ChatKit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
