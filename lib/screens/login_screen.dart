import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final bool showSkipButton;
  
  const LoginScreen({super.key, this.showSkipButton = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitAuth(DatabaseService dbService) async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      
      // Simulate auth process
      dbService.login(username, email);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('streamsync_seen_onboarding', true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isSignUp ? 'Account created successfully! Welcome $username.' : 'Logged in successfully!')),
      );

      // Navigate to home shell
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationShell()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.movie_filter_rounded,
                    color: AppTheme.accent,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isSignUp ? 'Create Account' : 'Welcome Back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'Sign up to sync your watchlist & history' : 'Sign in to access your synced profile data',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white70),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Username is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.mail_outline_rounded, color: Colors.white70),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Email is required';
                      if (!val.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white70),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: () => _submitAuth(dbService),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isSignUp ? 'Sign Up' : 'Log In',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle mode button
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),

                  // Skip option
                  if (widget.showSkipButton) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('streamsync_seen_onboarding', true);
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const MainNavigationShell()),
                        );
                      },
                      child: const Text(
                        'Skip for Now',
                        style: TextStyle(color: Colors.white38, fontSize: 13, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
