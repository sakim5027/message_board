import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final AuthService auth = AuthService();

    return Scaffold(
      appBar: AppBar(title: const Text('Message Board')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Login Successful!', style: TextStyle(fontSize: 24)),

            const SizedBox(height: 20),

            // Show the signed-in user's email.
            Text('Email: ${user.email}'),

            const SizedBox(height: 20),

            const Text('Message Board will be added later.'),

            const SizedBox(height: 20),

            // Logout button
            ElevatedButton(
              onPressed: () async {
                try {
                  await auth.signOut();

                  // AuthGate automatically shows LoginScreen.
                } on FirebaseAuthException {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logout failed. Please try again.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
