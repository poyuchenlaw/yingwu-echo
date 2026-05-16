import 'package:flutter/material.dart';
import 'screens/home_mirror.dart';

void main() {
  runApp(const YingwuEchoApp());
}

class YingwuEchoApp extends StatelessWidget {
  const YingwuEchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '應物 ECHO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B3F00), // 青銅主色
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeMirrorScreen(),
      // TODO: replace with go_router once route structure is confirmed
    );
  }
}
