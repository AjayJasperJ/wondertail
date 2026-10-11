import 'package:flutter/material.dart';

import 'data/save_repository.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final saves = SaveRepository(PreferencesSaveStore());
  final loaded = await saves.load();
  runApp(WondertailApp(saves: saves, loaded: loaded));
}

class WondertailApp extends StatelessWidget {
  const WondertailApp({super.key, required this.saves, required this.loaded});
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
        home: GameScreen(saves: saves, loaded: loaded),
      );
}
