import 'package:flutter/material.dart';

import 'game_controller.dart';
import 'screens/character_creator_screen.dart';
import 'screens/map_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReinoDeNieblaApp());
}

class ReinoDeNieblaApp extends StatefulWidget {
  const ReinoDeNieblaApp({super.key});

  @override
  State<ReinoDeNieblaApp> createState() => _ReinoDeNieblaAppState();
}

class _ReinoDeNieblaAppState extends State<ReinoDeNieblaApp>
    with WidgetsBindingObserver {
  final GameController _controller = GameController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.saveNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reino de Niebla',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (!_controller.loaded) {
            return const _SplashScreen();
          }
          // Primer arranque: el Espejo Mágico crea al personaje.
          if (_controller.player.name.isEmpty) {
            return CharacterCreatorScreen(
                controller: _controller, firstTime: true);
          }
          return MapScreen(controller: _controller);
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RN.night,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏰', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('Reino de Niebla',
                style: fantasyTitle(28, color: RN.goldSoft)),
            const SizedBox(height: 8),
            const Text('Despertando a los cartógrafos…',
                style: TextStyle(color: RN.parchmentDim)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: RN.gold),
          ],
        ),
      ),
    );
  }
}
