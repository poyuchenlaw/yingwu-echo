import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/echo_client.dart';
import 'api/sprite_resolver.dart';
import 'theme/echo_theme.dart';
import 'screens/home_mirror.dart';

final clientProvider = Provider<EchoClient>((_) => EchoClient());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SpriteResolver.instance.ensureLoaded();
  runApp(const ProviderScope(child: YingwuEchoApp()));
}

class YingwuEchoApp extends StatelessWidget {
  const YingwuEchoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '應物 ECHO',
      debugShowCheckedModeBanner: false,
      theme: echoTheme(),
      home: const HomeMirrorScreen(),
    );
  }
}
