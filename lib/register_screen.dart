import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'user_record_service.dart';

// RegisterScreen allows users to create an account.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // User information
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final roleController = TextEditingController();

  // Login information
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Use the professor's services.
  final AuthService _auth = AuthService();
  final UserRecordService _userRecord = UserRecordService();

  bool _isLoading = false;
  String _error = '';

  // Remember the created account if the Firestore save fails.
  User? _createdUser;

  Future<void> _signUp() async {
    if (_isLoading) return;

    // Validate only before creating the account.
    if (_createdUser == null && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Step 1: Create Firebase Authentication account.
      // Do not register again if the account already exists.
      if (_createdUser == null) {
        final credential = await _auth.register(
          email: emailController.text,
          password: passwordController.text,
        );

        if (credential.user == null) {
          throw StateError('Registration returned no user.');
        }

        _createdUser = credential.user;
      }

      // Make sure the same user is still signed in.
      if (_auth.currentUser?.uid != _createdUser!.uid) {
        throw StateError('Please sign in to your new account before retrying.');
      }

      // Step 2: Save user information to Firestore.
      // On retry, check whether the record already exists.
      bool recordExists = false;

      if (_createdUser != null) {
        // A first save also uses this check to avoid
        // overwriting an existing user document.
        recordExists = await _userRecord.userRecordExists(_createdUser!.uid);
      }

      if (!recordExists) {
        await _userRecord.saveUserRecord(
          _createdUser!,
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim(),
          role: roleController.text.trim(),
        );
      }

      // Step 3: Registration and profile save completed.
      // Return to AuthGate.
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        if (e.code == 'email-already-in-use') {
          _error = 'This email is already registered.';
        } else if (e.code == 'weak-password') {
          _error = 'Password is too weak.';
        } else if (e.code == 'invalid-email') {
          _error = 'Please enter a valid email.';
        } else if (e.code == 'network-request-failed') {
          _error = 'Check your internet connection.';
        } else {
          _error = 'Registration failed. Please try again.';
        }
      });
    } on FirebaseException {
      if (!mounted) return;

      setState(() {
        _error = _createdUser != null
            ? 'Account created, profile not saved. '
                  'Please retry saving your profile.'
            : 'Registration failed. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _createdUser != null
            ? 'Profile could not be completed. '
                  'Please retry or sign in to recover your profile.'
            : 'Registration could not be confirmed. '
                  'Please sign in to check your account.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    roleController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message Board Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 30),

              const Text(
                'Create an Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 24),

              // First Name
              TextFormField(
                controller: firstNameController,
                enabled: _createdUser == null,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your first name.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Last Name
              TextFormField(
                controller: lastNameController,
                enabled: _createdUser == null,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your last name.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Role
              TextFormField(
                controller: roleController,
                enabled: _createdUser == null,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  hintText: 'e.g., student',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your role.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: emailController,
                enabled: _createdUser == null,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email.';
                  }

                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(value.trim())) {
                    return 'Please enter a valid email.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: passwordController,
                enabled: _createdUser == null,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password.';
                  }

                  if (value.length < 6) {
                    return 'Password must be at least 6 characters.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Display error message
              if (_error.isNotEmpty)
                Text(_error, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 20),

              // Register or retry saving the profile
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                child: Text(
                  _isLoading
                      ? 'Processing...'
                      : _createdUser != null
                      ? 'Retry Save Profile'
                      : 'Sign Up',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
