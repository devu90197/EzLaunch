import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      // Mocking successful login for demonstration since real credentials might not be set
      // await Supabase.instance.client.auth.signInWithPassword(
      //   email: _emailController.text,
      //   password: _passwordController.text,
      // );
      
      await Future.delayed(const Duration(seconds: 1)); // Simulate api call
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const DashboardScreen())
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 400,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1542744094-24638eff58bb?auto=format&fit=crop&q=80&w=1000'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(.8),
                      Colors.black.withOpacity(.2),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FadeInUp(duration: const Duration(milliseconds: 1000), child: const Text("EzLaunch", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 10),
                      FadeInUp(duration: const Duration(milliseconds: 1300), child: const Text("Your Smart Onboarding Partner.", style: TextStyle(color: Colors.white, fontSize: 18))),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  FadeInUp(duration: const Duration(milliseconds: 1400), child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Color.fromRGBO(225, 95, 27, .3), blurRadius: 20, offset: Offset(0, 10))]
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
                          child: TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(hintText: "Email or Phone number", hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(hintText: "Password", hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 40),
                  FadeInUp(duration: const Duration(milliseconds: 1500), child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 40),
                  FadeInUp(duration: const Duration(milliseconds: 1600), child: MaterialButton(
                    onPressed: _loading ? null : _signIn,
                    height: 50,
                    color: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    child: Center(
                      child: _loading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
