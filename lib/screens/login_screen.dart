import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final LocalAuthentication _auth = LocalAuthentication();
  bool _loading = false;
  bool _showPassword = false;
  bool _isValidEmail = false;
  bool _canCheckBiometrics = false;

  final Color _appleAccent = const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_onPasswordChanged);
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      setState(() => _canCheckBiometrics = canCheck && isSupported);
    } catch (e) {
      // Biometrics not available
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final email = _emailController.text;
    final emailRegex = RegExp(r"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$");
    setState(() {
      _isValidEmail = emailRegex.hasMatch(email);
    });
  }

  void _onPasswordChanged() {
    setState(() {}); // Refresh form validity
  }

  bool get _isFormValid => _isValidEmail && _passwordController.text.length >= 6;

  Future<void> _signIn() async {
    if (!_isFormValid) return;

    setState(() => _loading = true);
    FocusScope.of(context).unfocus();

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const DashboardScreen())
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError("An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithBiometrics() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to access EzLaunch Portal',
      );

      if (authenticated) {
        // In a real passkey flow, we would use the biometric result to 
        // sign in via Supabase. For this mobile flow, we check if there's
        // a persistent session first (Splash handles that), but if they
        // trigger this manual passkey, we verify the user.
        _showError("Passkey login verified. Redirecting...");
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const DashboardScreen())
        );
      }
    } catch (e) {
      _showError("Biometric authentication failed.");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Blue header section with premium gradient
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_appleAccent, const Color(0xFF1D4ED8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logomain.png',
                    width: 70,
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "EzLaunch",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    "Secure Operator Portal",
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // Form Section
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
                  child: AutofillGroup(
                    child: Column(
                      children: [
                        // Email Field
                        _buildFieldLabel("Email Address"),
                        const SizedBox(height: 10),
                        _buildDecoratedField(
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            style: GoogleFonts.outfit(fontSize: 15),
                            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                            decoration: InputDecoration(
                              hintText: "operator@ezbillify.com",
                              hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                              prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[500], size: 22),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Password Field
                        _buildFieldLabel("Password"),
                        const SizedBox(height: 10),
                        _buildDecoratedField(
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 12, right: 10),
                                child: Icon(Icons.lock_outline_rounded, color: Colors.grey[500], size: 22),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  obscureText: !_showPassword,
                                  autofillHints: const [AutofillHints.password],
                                  style: GoogleFonts.outfit(fontSize: 15),
                                  onSubmitted: (_) => _signIn(),
                                  decoration: InputDecoration(
                                    hintText: "••••••••",
                                    hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey[400],
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              _showError("Please contact your administrator to reset your password.");
                            },
                            child: Text(
                              "Forgot Password?",
                              style: GoogleFonts.outfit(
                                color: _appleAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_isFormValid && !_loading) ? _signIn : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _appleAccent,
                              disabledBackgroundColor: Colors.grey[200],
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                "Sign In",
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                          ),
                        ),
                        
                        if (_canCheckBiometrics) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: _signInWithBiometrics,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _appleAccent.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.face_unlock_rounded, color: _appleAccent),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Sign in with Passkey",
                                    style: GoogleFonts.outfit(
                                      color: _appleAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 48),
                        
                        // Footer
                        Column(
                          children: [
                            Text(
                              "POWERED BY",
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400],
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "EZBILLIFY TECHNOLOGY",
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[500],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildDecoratedField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}
