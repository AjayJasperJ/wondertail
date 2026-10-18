import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/save_repository.dart';
import 'ui/game_screen.dart';
import 'ui/lobby_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final saves = SaveRepository(PreferencesSaveStore());
  final loaded = await saves.load();
  runApp(WondertailApp(saves: saves, loaded: loaded));
}

class WondertailApp extends StatelessWidget {
  const WondertailApp(
      {super.key,
      required this.saves,
      required this.loaded,
      this.startInGame = false});
  final bool startInGame;
  final SaveRepository saves;
  final LoadResult loaded;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wondertail · Little Drift',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff477467),
            surface: const Color(0xfffffcf4),
          ),
          fontFamily: 'sans-serif',
        ),
        home: startInGame
            ? GameScreen(saves: saves, loaded: loaded)
            : LobbyScreen(saves: saves, loaded: loaded),
      );
}
