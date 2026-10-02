import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'main_navigation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedNationality = 'Malaysia';
  bool _isObscure = true;
  bool _isLoading = false;

  final List<String> _nationalities = [
    'Malaysia',
    'Singapore',
    'Indonesia',
    'China',
    'United Kingdom',
    'United States',
    'Australia',
    'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final success = await AuthService.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nationality: _selectedNationality,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')),
        );
        // Navigate to Main navigation dashboard and remove auth screens from stack
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
                  const SnackBar(content: Text('Switched to Local Demo Mode! Please try signing up again.')),
                );
              }
            },
            child: const Text('Switch to Demo Mode'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignup() async {
    setState(() => _isLoading = true);
    try {
      final success = await AuthService.signInWithGoogle();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed up with Google successfully!')),
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
            content: Text('Google Sign Up failed: ${e.toString()}'),
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
              // 1. Bird Animation GIF Scaled Nicely (Top Section)
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

              // 2. Rounded Container for Signup Fields (Bottom Section)
              Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
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
                        "Welcome, let's explore\nPenang together!",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Name Field
                      Text(
                        'Name',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.poppins(fontSize: 15),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline_rounded),
                          hintText: 'Enter your name',
                          border: UnderlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Please enter your name' : null,
                      ),
                      const SizedBox(height: 18),

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
                      const SizedBox(height: 18),

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
                        validator: (value) => value == null || value.length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 18),

                      // Nationality Dropdown
                      Text(
                        'Nationality',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedNationality,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                        style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.public_rounded),
                          border: UnderlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        items: _nationalities.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() => _selectedNationality = newValue);
                          }
                        },
                      ),
                      const SizedBox(height: 32),

                      // Sign Up Button
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _handleSignup,
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
                                'Sign up',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      
                      const SizedBox(height: 20),

                      // Google Sign Up Separator
                      Row(
                        children: [
                          const Expanded(child: Divider(thickness: 1, color: Color(0xFFCBD5E1))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'or sign up with',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                          const Expanded(child: Divider(thickness: 1, color: Color(0xFFCBD5E1))),
                        ],
                      ),
                      
                      const SizedBox(height: 16),

                      // Google Icon Button
                      Center(
                        child: InkWell(
                          onTap: _isLoading ? null : _handleGoogleSignup,
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
                              'assets/images/google-icon.png', // Fallback or standard asset path for Google logo
                              width: 28,
                              height: 28,
                              errorBuilder: (context, error, stackTrace) {
                                // Simple text/icon fallback if google-icon.png is missing
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
