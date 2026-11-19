import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'user_record_service.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.user});

  final User user;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  final AuthService _auth = AuthService();
  final UserRecordService _userRecord = UserRecordService();

  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final roleController = TextEditingController();

  bool _isLoading = false;
  String _error = '';

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();

    // Listen to the user's Firestore record.
    _profileStream = _userRecord.watchUserRecord(widget.user);
  }

  // Retry reading the profile.
  void _retry() {
    setState(() {
      _error = '';
      _profileStream = _userRecord.watchUserRecord(widget.user);
    });
  }

  // Save a profile if it is missing.
  Future<void> _saveProfile() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Make sure the same user is signed in.
      if (_auth.currentUser?.uid != widget.user.uid) {
        throw StateError('User is no longer signed in.');
      }

      // Do not overwrite an existing user record.
      final exists = await _userRecord.userRecordExists(widget.user.uid);

      if (exists) {
        _retry();
        return;
      }

      await _userRecord.saveUserRecord(
        widget.user,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        role: roleController.text.trim(),
      );

      // Firestore stream updates the screen automatically.
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        if (e.code == 'permission-denied') {
          _error = 'Permission denied. Check Firestore rules.';
        } else {
          _error = 'Could not save profile. Please retry.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not complete profile. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Sign out using AuthService.
  Future<void> _signOut() async {
    try {
      await _auth.signOut();

      // AuthGate automatically returns to LoginScreen.
    } on FirebaseAuthException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board'),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileStream,
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load user profile.'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _retry, child: const Text('Retry')),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('Waiting for profile information.'),
            );
          }

          final document = snapshot.data!;

          // Waiting for a Firestore write to finish.
          if (document.metadata.hasPendingWrites) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = document.data();

          // Check whether the profile has all five fields.
          if (document.exists && data != null) {
            final validProfile =
                data['uid'] == widget.user.uid &&
                data['firstName'] is String &&
                (data['firstName'] as String).trim().isNotEmpty &&
                data['lastName'] is String &&
                (data['lastName'] as String).trim().isNotEmpty &&
                data['role'] is String &&
                (data['role'] as String).trim().isNotEmpty &&
                data['registrationDateTime'] is Timestamp;

            if (validProfile) {
              // Profile exists and contains all required fields.
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Profile Verified!',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    Text('Welcome, ${data['firstName']}!'),
                    const SizedBox(height: 12),
                    Text('Email: ${widget.user.email}'),
                    const SizedBox(height: 12),
                    Text('Role: ${data['role']}'),
                    const SizedBox(height: 20),
                    const Text('Message Board will be added later.'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _signOut,
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            }

            // Existing profile is incomplete.
            // Do not overwrite its registration timestamp.
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('User profile is incomplete.'),
                  const SizedBox(height: 12),
                  const Text('Please correct the existing Firestore record.'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _retry, child: const Text('Retry')),
                ],
              ),
            );
          }

          // No document exists: allow profile completion.
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(fontSize: 24),
                  ),

                  const SizedBox(height: 20),

                  TextFormField(
                    controller: firstNameController,
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

                  TextFormField(
                    controller: lastNameController,
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

                  TextFormField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Role',
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

                  if (_error.isNotEmpty)
                    Text(_error, style: const TextStyle(color: Colors.red)),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    child: Text(_isLoading ? 'Saving...' : 'Save Profile'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
