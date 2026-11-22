import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'board_service.dart';
import 'message.dart';
import 'auth_service.dart';
import 'notification_service.dart';

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

  // Keep the same ID and text if a post needs a retry.
  String? _pendingMessageId;
  String? _pendingMessageText;

  String _error = '';

  // Firebase Cloud Messaging
  final NotificationService _notificationService = NotificationService();

  bool _isEnablingNotifications = false;
  String _notificationMessage = '';

  @override
  void initState() {
    super.initState();

    _messages = _board.messageBoard();
  }

  // CREATE: Post a new message.
  Future<void> _postMessage() async {
    // Prevent overlapping taps.
    if (_isPosting) return;

    // Reuse the original text when retrying.
    final text = _pendingMessageText ?? messageController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a message.')));
      return;
    }

    // Generate an ID once, then reuse it for retries.
    _pendingMessageId ??= _board.newMessageId();
    _pendingMessageText ??= text;

    final messageId = _pendingMessageId!;

    setState(() {
      _isPosting = true;
    });

    try {
      await _board.postMessage(
        messageId: messageId,
        authorUid: widget.user.uid,
        authorName: widget.authorName,
        text: text,
      );

      // The operation completed successfully.
      _pendingMessageId = null;
      _pendingMessageText = null;

      if (!mounted) return;

      if (messageController.text.trim() == text) {
        messageController.clear();
      }
    } catch (e) {
      if (!mounted) return;

      // Keep the same message ID for the next retry.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not post message. Tap Post to retry.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  // Ask for notification permission only when the user clicks the button.
  Future<void> _enableNotifications() async {
    if (_isEnablingNotifications) return;

    setState(() {
      _isEnablingNotifications = true;
      _notificationMessage = '';
    });

    try {
      // Request permission and register only after consent.
      final result = await _notificationService.enableNotifications();

      if (!mounted) return;

      setState(() {
        _notificationMessage = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _notificationMessage = 'Notifications could not be enabled.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEnablingNotifications = false;
        });
      }
    }
  }

  // UPDATE: Edit my own message.
  Future<void> _editMessage(Message message) async {
    String editedText = message.text;

    // Ask the user for the updated message.
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextFormField(
            initialValue: message.text,
            onChanged: (value) {
              editedText = value;
            },
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, editedText.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || newText == null) return;

    // Do not allow empty messages.
    if (newText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message cannot be empty.')));
      return;
    }

    try {
      // Use the professor's BoardService.
      await _board.editMessage(messageId: message.id, newText: newText);

      // StreamBuilder automatically updates the list.
    } on FirebaseException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Could not edit message. Please try again.';

      if (e.code == 'permission-denied') {
        errorMessage = 'You can only edit your own messages.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  // DELETE: Delete my own message.
  Future<void> _deleteMessage(Message message) async {
    // Ask the user to confirm deletion.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    // Stop if the user cancels.
    if (!mounted || confirm != true) return;

    try {
      // Use the professor's BoardService.
      await _board.deleteMessage(messageId: message.id);

      // StreamBuilder automatically removes the message.
    } on FirebaseException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Could not delete message. Please try again.';

      if (e.code == 'permission-denied') {
        errorMessage = 'You can only delete your own messages.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
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

            const SizedBox(height: 16),

            // Optional notification permission
            const Text(
              'Message Board Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Notifications are optional. '
              'You can use the Message Board without enabling them.',
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _isEnablingNotifications ? null : _enableNotifications,
              icon: const Icon(Icons.notifications),
              label: Text(
                _isEnablingNotifications
                    ? 'Enabling...'
                    : 'Enable Notifications',
              ),
            ),

            if (_notificationMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_notificationMessage),
              ),

            const SizedBox(height: 16),

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

                              const SizedBox(height: 8),

                              // Only the author can see Edit and Delete buttons.
                              if (message.authorUid == widget.user.uid)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Edit button
                                    TextButton.icon(
                                      onPressed: () => _editMessage(message),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit'),
                                    ),

                                    // Delete button
                                    TextButton.icon(
                                      onPressed: () => _deleteMessage(message),
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Delete'),
                                    ),
                                  ],
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
