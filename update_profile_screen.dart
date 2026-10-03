import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/firebase_service.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  late List<String> _selectedStyles;
  final List<String> _availableStyles = [
    'Foodie',
    'Adventure',
    'Nature Lover',
    'History Buff',
    'Culture Seeker',
    'Shopping Lover',
    'Art & Design',
  ];

  late UserProfile _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = UserProfileManager.profileNotifier.value;
    _nameController = TextEditingController(text: _currentProfile.name);
    _emailController = TextEditingController(text: _currentProfile.email);
    _phoneController = TextEditingController(text: _currentProfile.phone);
    _selectedStyles = List<String>.from(_currentProfile.travelStyles);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newPhone = _phoneController.text.trim();

    final isEmailChanged = newEmail != _currentProfile.email;
    final isPhoneChanged = newPhone != _currentProfile.phone;

    if (isPhoneChanged) {
      final verified = await _showVerificationDialog(
        title: 'Verify via Email',
        description: 'A 6-digit verification code has been sent to your email:\n${_currentProfile.email}\n\nEnter the code to verify your phone number change.',
        mockCode: '123456',
      );
      if (!verified) return;
    }

    if (isEmailChanged) {
      final verified = await _showVerificationDialog(
        title: 'Verify via SMS',
        description: 'A 6-digit SMS verification code has been sent to your phone:\n$newPhone\n\nEnter the code to verify your email change.',
        mockCode: '654321',
      );
      if (!verified) return;
    }

    await UserProfileManager.updateProfile(
      name: newName,
      email: newEmail,
      phone: newPhone,
      travelStyles: _selectedStyles,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<bool> _showVerificationDialog({
    required String title,
    required String description,
    required String mockCode,
  }) async {
    final codeController = TextEditingController();
    bool isSuccess = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18, // Spec Label: 18px
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDarkNavy,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12, // Spec Desc: 12px
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '(Mock verification code is $mockCode)',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Verification Code',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (codeController.text.trim() == mockCode) {
                  isSuccess = true;
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid code! Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryRoyalBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Verify',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    codeController.dispose();
    return isSuccess;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 16),
          ),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF303030), // Colors.grey[850]
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18, // Spec Label: 18px
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDarkNavy,
                ),
              ),
              const SizedBox(height: 16),
              
              // Name Field
              _buildTextField(
                controller: _nameController,
                labelText: 'Full Name',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Phone Field
              _buildTextField(
                controller: _phoneController,
                labelText: 'Phone Number',
                keyboardType: TextInputType.phone,
                helperText: 'Changing phone number requires email verification.',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Email Field
              _buildTextField(
                controller: _emailController,
                labelText: 'Email Address',
                keyboardType: TextInputType.emailAddress,
                helperText: 'Changing email requires SMS verification.',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Travel Style Preferences',
                style: TextStyle(
                  fontSize: 18, // Spec Label: 18px
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDarkNavy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the categories you enjoy. These help personalize your recommendations. You can update this anytime.',
                style: TextStyle(
                  fontSize: 12, // Spec Body/Desc: 12px
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 12),
              
              // Travel Style Wrap
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _availableStyles.map((style) {
                  final isSelected = _selectedStyles.contains(style);
                  return FilterChip(
                    label: Text(
                      style,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primaryDarkNavy,
                    checkmarkColor: Colors.white,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedStyles.add(style);
                        } else {
                          _selectedStyles.remove(style);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 36),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF304FFE), // indigoAccent[700] button rule
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    'Save Profile',
                    style: TextStyle(
                      fontSize: 14, // Button text spec: 14px
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? helperText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.black), // Spec Normal: 14px
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.secondaryRoyalBlue, width: 1.5),
            ),
            errorStyle: const TextStyle(fontSize: 11, color: Colors.red),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: Text(
              helperText,
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
          ),
        ],
      ],
    );
  }
}
