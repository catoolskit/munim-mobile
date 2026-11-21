import 'package:flutter/material.dart';
import 'package:munim_mobile/theme.dart';
import 'package:munim_mobile/services/config_service.dart';
import 'package:munim_mobile/screens/setup_screen.dart';
import 'package:munim_mobile/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MunimApp());
}

class MunimApp extends StatelessWidget {
  const MunimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MUNIM',
      debugShowCheckedModeBanner: false,
      theme: MunimTheme.theme(),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final config = await ConfigService.load();
    if (!mounted) return;
    if (config == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(config: config)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MunimTheme.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: MunimTheme.gold,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('म',
                  style: TextStyle(
                    fontSize: 36, fontWeight: FontWeight.bold,
                    color: Color(0xFF071B49),
                  )),
              ),
            ),
            const SizedBox(height: 20),
            const Text('MUNIM',
              style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold,
                color: Colors.white, letterSpacing: 2,
              )),
            const SizedBox(height: 8),
            Text('Mobile Invoice App',
              style: TextStyle(
                fontSize: 14, color: Colors.white.withOpacity(0.6),
              )),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: MunimTheme.gold),
          ],
        ),
      ),
    );
  }
}
