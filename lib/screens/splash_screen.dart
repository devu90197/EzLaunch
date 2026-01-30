import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _logoOpacity;

  late AnimationController _textController;
  late List<Animation<double>> _letterOffsets;
  late List<Animation<double>> _letterOpacities;
  
  late AnimationController _taglineController;
  late Animation<double> _taglineOffset;
  late Animation<double> _taglineOpacity;

  final String _appName = "EzLaunch";

  @override
  void initState() {
    super.initState();

    // Logo Animation Setup
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _logoRotation = Tween<double>(begin: -0.5, end: 0.0).animate( // -30 degrees is approx -0.5 radians
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Letters Animation Setup
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _letterOffsets = List.generate(_appName.length, (index) {
      final start = 0.2 + (index * 0.05);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 20, end: 0).animate(
        CurvedAnimation(
          parent: _textController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });

    _letterOpacities = List.generate(_appName.length, (index) {
      final start = 0.2 + (index * 0.05);
      final end = (start + 0.2).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _textController,
          curve: Interval(start, end, curve: Curves.easeIn),
        ),
      );
    });

    // Tagline Animation Setup
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _taglineOffset = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _taglineController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _taglineController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    _logoController.forward();
    _textController.forward();
    _taglineController.forward();

    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    
    final session = Supabase.instance.client.auth.currentSession;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => session != null ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2563EB), // Signature Blue
      body: Stack(
        children: [
          // Subtle circular gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.5),
                    const Color(0xFF2563EB),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.rotate(
                        angle: _logoRotation.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Image.asset(
                            'assets/images/logomain.png',
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                
                // Animated Letters
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_appName.length, (index) {
                    return AnimatedBuilder(
                      animation: _textController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _letterOpacities[index].value,
                          child: Transform.translate(
                            offset: Offset(0, _letterOffsets[index].value),
                            child: Text(
                              _appName[index],
                              style: GoogleFonts.outfit(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
                
                const SizedBox(height: 12),
                
                // Animated Tagline
                AnimatedBuilder(
                  animation: _taglineController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _taglineOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _taglineOffset.value),
                        child: Text(
                          "Inventory Made Simple",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
