import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'board_service.dart';
import 'message.dart';
import 'auth_service.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, required this.user, required this.authorName});

  final User user;
  final String authorName;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  // Message input
  final messageController = TextEditingController();

  // Use BoardService for all Firestore operations.
  final BoardService _board = BoardService();

  final AuthService _auth = AuthService();

  // Keep one stream instead of creating it in build().
  late Stream<List<Message>> _messages;

  bool _isPosting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();

    _messages = _board.messageBoard();
  }

  // CREATE: Post a new message.
  Future<void> _postMessage() async {
    if (_isPosting) return;

    final text = messageController.text.trim();

    // Do not allow empty messages.
    if (text.isEmpty) {
      setState(() {
        _error = 'Please enter a message.';
      });
      return;
    }

    setState(() {
      _isPosting = true;
      _error = '';
    });

    try {
      // Call BoardService instead of Firestore directly.
      await _board.postMessage(
        authorUid: widget.user.uid,
        authorName: widget.authorName,
        text: text,
      );

      if (!mounted) return;

      // Clear the input after posting successfully.
      messageController.clear();
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        if (e.code == 'permission-denied') {
          _error = 'Permission denied. Check Firestore rules.';
        } else if (e.code == 'unavailable') {
          _error = 'Firestore is unavailable. Try again later.';
        } else {
          _error = 'Could not post message. Please try again.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not post message. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await _auth.signOut();
                // AuthGate automatically returns to LoginScreen.
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
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Column(
          children: [
            // Welcome message for the signed-in user
            Text(
              'Hello ${widget.authorName}! \nWelcome to Message Board!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),
            // Message input
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Write a message',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // Post button
            ElevatedButton(
              onPressed: _isPosting ? null : _postMessage,
              child: Text(_isPosting ? 'Posting...' : 'Post'),
            ),

            const SizedBox(height: 12),

            // Error message
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red)),

            const SizedBox(height: 20),

            const Text(
              'Recent Messages',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            // READ: Display live messages.
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _messages,
                builder: (context, snapshot) {
                  // Loading state
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Error state
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load messages. '
                        'Check your connection or Firestore rules.',
                      ),
                    );
                  }

                  final messages = snapshot.data ?? [];

                  // Empty state
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('No messages yet. Be the first to post!'),
                    );
                  }

                  // Display the message list.
                  return ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];

                      return Card(
                        child: ListTile(
                          title: Text(message.authorName),

                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),

                              Text(message.text),

                              const SizedBox(height: 8),

                              // Display server timestamp.
                              Text(
                                message.createdAt == null
                                    ? 'Sending...'
                                    : 'Posted: ${message.createdAt!.toLocal()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
