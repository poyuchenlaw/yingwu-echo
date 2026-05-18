import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'api/echo_client.dart';
import 'api/sprite_resolver.dart';
import 'services/device_id.dart';
import 'services/settings_store.dart';
import 'theme/echo_theme.dart';
import 'screens/home_mirror.dart';
import 'screens/onboarding.dart';

final settingsProvider = Provider<SettingsStore>((_) => throw UnimplementedError());
final deviceIdProvider = Provider<DeviceId>((_) => throw UnimplementedError());
final apiBaseProvider = StateProvider<String>(
  (ref) => ref.read(settingsProvider).apiBase,
);
final clientProvider = Provider<EchoClient>(
  (ref) => EchoClient(
    base: ref.watch(apiBaseProvider),
    playerId: ref.watch(deviceIdProvider).value,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh', null);
  await SpriteResolver.instance.ensureLoaded();
  final settings = await SettingsStore.load();
  final deviceId = await DeviceId.load();
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(settings),
        deviceIdProvider.overrideWithValue(deviceId),
      ],
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
