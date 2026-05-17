import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/echo_client.dart';
import 'api/sprite_resolver.dart';
import 'services/settings_store.dart';
import 'theme/echo_theme.dart';
import 'screens/home_mirror.dart';
import 'screens/onboarding.dart';

final settingsProvider = Provider<SettingsStore>((_) => throw UnimplementedError());
final apiBaseProvider = StateProvider<String>(
  (ref) => ref.read(settingsProvider).apiBase,
);
final clientProvider = Provider<EchoClient>(
  (ref) => EchoClient(base: ref.watch(apiBaseProvider)),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SpriteResolver.instance.ensureLoaded();
  final settings = await SettingsStore.load();
  runApp(
    ProviderScope(
      overrides: [settingsProvider.overrideWithValue(settings)],
      child: YingwuEchoApp(showOnboarding: !settings.onboardingDone),
    ),
  );
}

class YingwuEchoApp extends StatelessWidget {
  const YingwuEchoApp({super.key, required this.showOnboarding});
  final bool showOnboarding;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '應物 ECHO',
      debugShowCheckedModeBanner: false,
      theme: echoTheme(),
      home: showOnboarding ? const OnboardingScreen() : const HomeMirrorScreen(),
    );
  }
}
