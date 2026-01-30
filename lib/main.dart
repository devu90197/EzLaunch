import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (AppConstants.supabaseUrl.isEmpty) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Supabase URL is missing!\nPlease run with:\nflutter run --dart-define-from-file=.env',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ));
    return;
  }
  
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseKey,
  );
  
  runApp(
    const ProviderScope(
      child: EzLaunchApp(),
    ),
  );
}

class EzLaunchApp extends StatelessWidget {
  const EzLaunchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF38BDF8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      home: const SplashScreen(), // Splash will redirect to Login
    );
  }
}
