import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:rive/rive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';

import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Charger les variables d'environnement
  try {
    await dotenv.load(fileName: ".env");
    logger.d('✅ Fichier .env chargé avec succès');
    
    // Debug: vérifier la clé API
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      logger.d('✅ Clé API OpenAI trouvée: ${apiKey.substring(0, 10)}...');
    } else {
      logger.w('⚠️ Clé API OpenAI non trouvée dans .env');
    }
  } catch (e) {
    logger.w('⚠️ Fichier .env non trouvé, utilisation des valeurs par défaut: $e');
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('fr_FR', null);

  runApp(const BazariaRoot());
}

class BazariaRoot extends StatefulWidget {
  const BazariaRoot({super.key});
  @override
  State<BazariaRoot> createState() => _BazariaRootState();
}

class _BazariaRootState extends State<BazariaRoot> {
  bool _showSplash = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    await Future.delayed(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    setState(() {
      _showSplash = false;
      _showOnboarding = !onboardingSeen;
    });
  }

  void _finishOnboarding() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bazaria',
      theme: AppTheme.themeData,
      home: _showSplash
          ? const SplashScreen()
          : _showOnboarding
              ? OnboardingScreen(onFinish: _finishOnboarding)
              : const HomeScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 180,
          height: 180,
          child: RiveAnimation.asset(
            'assets/bazaria.riv',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
