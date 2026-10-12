import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'encryption_service.dart';
import 'firebase_service.dart';
import 'saved_trip_plans_manager.dart';
import 'saved_places_manager.dart';

class AuthService {
  static final ValueNotifier<Map<String, dynamic>?> currentUserNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  static bool forceLocalFallback = false;

  // Check if Firebase is successfully initialized and available (and not placeholders)
  static bool get _isFirebaseAvailable {
    if (forceLocalFallback) return false;
    try {
      if (Firebase.apps.isEmpty) return false;
      final options = Firebase.app().options;
      if (options.apiKey == 'placeholder-api-key') {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle and persist local fallback
  static Future<void> setForceLocalFallback(bool value) async {
    forceLocalFallback = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('force_local_fallback', value);
    await init();
  }

  /// Initialize Auth State
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    forceLocalFallback = prefs.getBool('force_local_fallback') ?? false;

    // 1. Immediately restore cached user session so app doesn't flash WelcomeScreen
    final cachedUserStr = prefs.getString('current_session_user');
    if (cachedUserStr != null) {
      try {
        currentUserNotifier.value = Map<String, dynamic>.from(json.decode(cachedUserStr));
      } catch (_) {}
    }
    
    if (_isFirebaseAvailable) {
      try {
        await GoogleSignIn.instance.initialize();
      } catch (e) {
        print("Google Sign In initialize failed: $e");
      }

      // 2. Check if Firebase Auth already has a logged-in user
      final currentFirebaseUser = FirebaseAuth.instance.currentUser;
      if (currentFirebaseUser != null) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(currentFirebaseUser.uid).get();
          if (doc.exists) {
            final data = doc.data()!;
            final sessionData = {
              'uid': currentFirebaseUser.uid,
              'name': data['name'] ?? currentFirebaseUser.displayName ?? 'vennis',
              'email': currentFirebaseUser.email ?? data['email'] ?? '',
              'nationality': data['nationality'] ?? 'Malaysia',
              'joinedDate': data['joinedDate'] ?? 'August 2026',
            };
            await _setLocalSession({...data, ...sessionData});
          }
        } catch (e) {
          print("Error restoring initial Firebase session: $e");
        }
      } else {
        // If Firebase is available and no user is logged in, clear session
        currentUserNotifier.value = null;
        await prefs.remove('current_session_user');
      }

      // 3. Listen to real FirebaseAuth state changes
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (user != null) {
          try {
            final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            if (doc.exists) {
              final data = doc.data()!;
              final sessionData = {
                'uid': user.uid,
                'name': data['name'] ?? user.displayName ?? 'vennis',
                'email': user.email ?? data['email'] ?? '',
                'nationality': data['nationality'] ?? 'Malaysia',
                'joinedDate': data['joinedDate'] ?? 'August 2026',
              };
              await _setLocalSession({...data, ...sessionData});
            }
          } catch (e) {
            print("authStateChanges sync error: $e");
          }
        } else {
          currentUserNotifier.value = null;
          final p = await SharedPreferences.getInstance();
          await p.remove('current_session_user');
          await SavedTripPlansManager.clearOnLogout();
          await SavedPlacesManager.clearOnLogout();
        }
      });
    } else {
      // Local fallback mode: Load cached user session
      if (currentUserNotifier.value != null) {
        await UserProfileManager.loadProfile();
      }
    }
  }

  /// Sign Up with Email and Password
  static Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String nationality,
    bool isEmailVerified = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final encodedPassword = EncryptionService.encode(password);

    if (_isFirebaseAvailable) {
      try {
        // Create user in Firebase Auth
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );

        final userData = {
          'uid': credential.user!.uid,
          'name': name,
          'email': cleanEmail,
          'nationality': nationality,
          'nationalityLastUpdatedYear': DateTime.now().year,
          'password': encodedPassword, // Stored encoded in Firestore
          'joinedDate': 'August 2026',
          'isEmailVerified': isEmailVerified,
          'rank': 0,
          'completedRoutes': 0,
          'distanceTravelled': 0.0,
          'travelStyles': <String>[],
        };

        // Write additional user info to Firestore, including the ENCODED password
        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set(userData);

        await _setLocalSession(userData);
        return true;
      } catch (e) {
        print("Firebase Sign Up Error: $e");
        rethrow;
      }
    } else {
      // Local fallback using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('mock_users') ?? '{}';
      final Map<String, dynamic> users = Map<String, dynamic>.from(json.decode(usersJson));

      if (users.containsKey(cleanEmail)) {
        throw Exception("An account already exists with this email address.");
      }

      final uid = 'mock_uid_${Random().nextInt(900000) + 100000}';
      final newUser = {
        'uid': uid,
        'name': name,
        'email': cleanEmail,
        'nationality': nationality,
        'nationalityLastUpdatedYear': DateTime.now().year,
        'password': encodedPassword, // Encoded password stored in database
        'joinedDate': 'August 2026',
        'isEmailVerified': isEmailVerified,
        'rank': 0,
        'completedRoutes': 0,
        'distanceTravelled': 0.0,
        'travelStyles': [],
      };

      users[cleanEmail] = newUser;
      await prefs.setString('mock_users', json.encode(users));

      // Cache profile locally for active session
      await _setLocalSession(newUser);
      return true;
    }
  }

  /// Log In with Email and Password
  static Future<bool> logIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (_isFirebaseAvailable) {
      try {
        // Step 1: Sign in with Firebase Auth (standard check)
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );

        // Step 2: Fetch Firestore document to verify & compare ENCODED password
        final doc = await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final storedEncodedPassword = data['password'] as String?;
          
          if (storedEncodedPassword != null) {
            // DECODE & VERIFY (as explicitly requested: "decode to check")
            final isMatch = EncryptionService.verify(password, storedEncodedPassword);
            if (!isMatch) {
              await FirebaseAuth.instance.signOut();
              throw Exception("Incorrect password.");
            }
          }

          final sessionData = {
            'uid': credential.user!.uid,
            'name': data['name'] ?? credential.user!.displayName ?? 'vennis',
            'email': cleanEmail,
            'nationality': data['nationality'] ?? 'Malaysia',
            'joinedDate': data['joinedDate'] ?? 'August 2026',
          };
          await _setLocalSession({...data, ...sessionData});
        }
        return true;
      } catch (e) {
        print("Firebase Log In Error: $e");
        rethrow;
      }
    } else {
      // Local fallback database check
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('mock_users') ?? '{}';
      final Map<String, dynamic> users = Map<String, dynamic>.from(json.decode(usersJson));

      if (!users.containsKey(cleanEmail)) {
        throw Exception("No user found with this email address.");
      }

      final userData = Map<String, dynamic>.from(users[cleanEmail]);
      final storedEncodedPassword = userData['password'] as String;

      // DECODE & VERIFY to check matches
      final isMatch = EncryptionService.verify(password, storedEncodedPassword);
      if (!isMatch) {
        throw Exception("Incorrect password.");
      }

      await _setLocalSession(userData);
      return true;
    }
  }

  /// Sign Up / Log In with Google Account
  static Future<bool> signInWithGoogle() async {
    if (_isFirebaseAvailable) {
      try {
        final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
        if (googleUser == null) return false; // User cancelled

        final googleAuth = googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final user = userCredential.user;

        if (user != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (!doc.exists) {
            // New sign up via Google: save info & auto-set nationality so we don't ask again
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'name': user.displayName ?? googleUser.displayName ?? 'Google Explorer',
              'email': user.email ?? googleUser.email,
              'nationality': 'Malaysia', // Auto-filled (no need to ask again)
              'password': '', // Empty for Google auth
              'joinedDate': 'August 2026',
              'rank': 0,
              'completedRoutes': 0,
              'distanceTravelled': 0.0,
              'travelStyles': [],
            });
          }
        }
        return true;
      } catch (e) {
        print("Google Sign In Error: $e");
        rethrow;
      }
    } else {
      // Mock Google Login fallback
      final mockGoogleUser = {
        'uid': 'mock_google_uid_12345',
        'name': 'Google Explorer',
        'email': 'explorer.penang@gmail.com',
        'nationality': 'Malaysia', // Auto-filled (no need to ask again)
        'password': '',
        'joinedDate': 'August 2026',
        'rank': 0,
        'completedRoutes': 0,
        'distanceTravelled': 0.0,
        'travelStyles': ['Sightseeing'],
      };

      // Add to users database if not exists
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('mock_users') ?? '{}';
      final Map<String, dynamic> users = Map<String, dynamic>.from(json.decode(usersJson));
      
      final email = mockGoogleUser['email'] as String;
      if (!users.containsKey(email)) {
        users[email] = mockGoogleUser;
        await prefs.setString('mock_users', json.encode(users));
      }

      await _setLocalSession(mockGoogleUser);
      return true;
    }
  }

  /// Request Forgot Password Code (sends a code to user's email)
  static Future<String> requestPasswordResetCode(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // Check user exists first
    bool userExists = false;
    if (_isFirebaseAvailable) {
      // In a real system, Firebase Auth handles this.
      // For custom password encoding verification, we check Firestore
      final users = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      userExists = users.docs.isNotEmpty;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('mock_users') ?? '{}';
      final Map<String, dynamic> users = Map<String, dynamic>.from(json.decode(usersJson));
      userExists = users.containsKey(cleanEmail);
    }

    if (!userExists) {
      throw Exception("No account registered with this email address.");
    }

    // Generate a 6-digit random code
    final code = (Random().nextInt(900000) + 100000).toString();

    // Save code to SharedPreferences for verification
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reset_code_$cleanEmail', code);

    // Send reset code - for mock/demo, we print to console and return it so the UI can display it
    print("------------------------------------------");
    print("PASSWORD RESET CODE FOR $cleanEmail: $code");
    print("------------------------------------------");

    // Also if Firebase is available, we could trigger Firebase's standard reset email:
    if (_isFirebaseAvailable) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
      } catch (e) {
        print("Firebase reset email failed (using code backup instead): $e");
      }
    }

    return code;
  }

  /// Confirm Password Reset with Code
  static Future<bool> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    
    final savedCode = prefs.getString('reset_code_$cleanEmail');
    if (savedCode == null || savedCode != code) {
      throw Exception("Invalid or expired verification code.");
    }

    final newEncodedPassword = EncryptionService.encode(newPassword);

    if (_isFirebaseAvailable) {
      // 1. Update password in Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        throw Exception("User not found.");
      }

      final docId = querySnapshot.docs.first.id;
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'password': newEncodedPassword,
      });

      // Note: Admin SDK would be needed to update FirebaseAuth password directly.
      // The user will reset password on Auth via email link, but this updates the Firestore credential field.
    } else {
      // Local database update
      final usersJson = prefs.getString('mock_users') ?? '{}';
      final Map<String, dynamic> users = Map<String, dynamic>.from(json.decode(usersJson));

      if (!users.containsKey(cleanEmail)) {
        throw Exception("User not found.");
      }

      final userData = Map<String, dynamic>.from(users[cleanEmail]);
      userData['password'] = newEncodedPassword;
      users[cleanEmail] = userData;

      await prefs.setString('mock_users', json.encode(users));
    }

    // Clean up code
    await prefs.remove('reset_code_$cleanEmail');
    return true;
  }

  /// Log Out
  static Future<void> logOut() async {
    final prefs = await SharedPreferences.getInstance();

    if (_isFirebaseAvailable) {
      await FirebaseAuth.instance.signOut();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }

    await prefs.remove('current_session_user');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    await prefs.remove('user_joined');
    await prefs.remove('user_rank');
    await prefs.remove('user_routes');
    await prefs.remove('user_distance');
    await prefs.remove('user_styles');

    currentUserNotifier.value = null;
    await UserProfileManager.loadProfile();
    await SavedTripPlansManager.clearOnLogout();
    await SavedPlacesManager.clearOnLogout();
  }

  // Helper to save session locally for fallback database & persistent cache
  static Future<void> _setLocalSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    
    final name = (userData['name'] as String?)?.isNotEmpty == true ? userData['name'] as String : 'vennis';
    final email = userData['email'] as String? ?? '';
    final nationality = userData['nationality'] as String? ?? 'Malaysia';
    final joined = userData['joinedDate'] as String? ?? 'August 2026';
    final phone = userData['phone'] as String? ?? '';
    final rank = (userData['rank'] as num?)?.toInt() ?? 0;
    final routes = (userData['completedRoutes'] as num?)?.toInt() ?? 0;
    final distance = (userData['distanceTravelled'] as num?)?.toDouble() ?? 0.0;
    final styles = List<String>.from(userData['travelStyles'] ?? []);
    final isEmailVerified = userData['isEmailVerified'] as bool? ?? false;

    final sessionData = {
      'uid': userData['uid'],
      'name': name,
      'email': email,
      'nationality': nationality,
      'joinedDate': joined,
    };

    await prefs.setString('current_session_user', json.encode(sessionData));
    
    // Seed UserProfileManager profile values
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_joined', joined);
    final natYear = (userData['nationalityLastUpdatedYear'] as num?)?.toInt();
    if (natYear != null) {
      await prefs.setInt('user_nationality_last_updated_year', natYear);
    }
    await prefs.setString('user_nationality', nationality);
    await prefs.setBool('user_email_verified', isEmailVerified);
    await prefs.setInt('user_rank', rank);
    await prefs.setInt('user_routes', routes);
    await prefs.setDouble('user_distance', distance);
    final dietary = List<String>.from(userData['dietaryPreferences'] ?? ['Halal', 'Pork-Free']);
    await prefs.setStringList('user_dietary_preferences', dietary);
    await prefs.setStringList('user_styles', styles);

    currentUserNotifier.value = sessionData;
    await UserProfileManager.loadProfile();
    await SavedTripPlansManager.syncWithFirestore();
    await SavedPlacesManager.syncWithFirestore();
  }
}
