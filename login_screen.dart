import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _welcomeMessage = "Welcome back!";
  bool _isObscure = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Load last logged in user name and pre-fill email
  Future<void> _loadLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    final lastName = prefs.getString('user_name');
    final lastEmail = prefs.getString('user_email');
    if (mounted && lastName != null && lastEmail != null) {
      setState(() {
        _welcomeMessage = "Welcome back\n$lastName";
        _emailController.text = lastEmail;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final success = await AuthService.logIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged in successfully!')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      }
    } catch (e) {
      final errorStr = e.toString();
      if (mounted) {
        if (errorStr.contains('CONFIGURATION_NOT_FOUND') || errorStr.contains('network-request-failed') || errorStr.contains('firebase_auth')) {
          _showFirebaseErrorDialog(context, errorStr);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorStr.replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFirebaseErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Firebase Setup Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your app is connected to Firebase, but standard Email/Password sign-in has not been enabled in your Firebase Console (or the network is unreachable).\n\n"
              "Firebase Error:\n$errorMessage",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to switch to Local Demo Mode to test signing up, logging in, and password encoding locally?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F54EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await AuthService.setForceLocalFallback(true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Switched to Local Demo Mode! Please try logging in again.')),
                );
              }
            },
            child: const Text('Switch to Demo Mode'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final success = await AuthService.signInWithGoogle();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged in with Google successfully!')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign In failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Bird Animation GIF Scaled (Top Section)
              Container(
                height: screenSize.height * 0.24,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/signUp-logIn-page-bird-animation-6s-design-2.gif',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // 2. Rounded Container for Login Fields (Bottom Section)
              Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
                constraints: BoxConstraints(
                  minHeight: screenSize.height * 0.60,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F7FA), // Soft light-blue background card matching mockup
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _welcomeMessage,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Email Field
                      Text(
                        'Email',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      TextFormField(
                        controller: _emailController,
                        style: GoogleFonts.poppins(fontSize: 15),
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.email_outlined),
                          hintText: 'Enter your email',
                          border: UnderlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      Text(
                        'Password',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _isObscure,
                        style: GoogleFonts.poppins(fontSize: 15),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          hintText: 'Enter password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _isObscure = !_isObscure),
                          ),
                          border: const UnderlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter your password'
                            : null,
                      ),
                      
                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  initialEmail: _emailController.text,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2F54EB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign In Button
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2F54EB), // Royal Blue
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 3,
                              ),
                              child: Text(
                                'Sign in',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      
                      const SizedBox(height: 24),

                      // Google Sign In Separator
                      Row(
                        children: [
                          const Expanded(child: Divider(thickness: 1, color: Color(0xFFCBD5E1))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'or sign in with',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                          const Expanded(child: Divider(thickness: 1, color: Color(0xFFCBD5E1))),
                        ],
                      ),
                      
                      const SizedBox(height: 18),

                      // Google Icon Button
                      Center(
                        child: InkWell(
                          onTap: _isLoading ? null : _handleGoogleLogin,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/google-icon.png',
                              width: 28,
                              height: 28,
                              errorBuilder: (context, error, stackTrace) {
                                // Simple text/icon fallback
                                return const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.red);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
