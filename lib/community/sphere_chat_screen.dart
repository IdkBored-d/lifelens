import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sphere.dart';

class SphereChatScreen extends StatefulWidget {
  final Sphere sphere;

  const SphereChatScreen({super.key, required this.sphere});

  @override
  State<SphereChatScreen> createState() => _SphereChatScreenState();
}

class _SphereChatScreenState extends State<SphereChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _userNickname;

  @override
  void initState() {
    super.initState();
    _loadUserNickname();
  }

  Future<void> _loadUserNickname() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final memberDoc = await FirebaseFirestore.instance
        .collection('spheres')
        .doc(widget.sphere.id)
        .collection('members')
        .doc(userId)
        .get();

    if (memberDoc.exists) {
      setState(() {
        _userNickname = memberDoc.data()?['nickname'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sphere.name),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('spheres')
                  .doc(widget.sphere.id)
                  .collection('members')
                  .snapshots(),
              builder: (context, snapshot) {
                final count =
                    snapshot.data?.docs.length ?? widget.sphere.memberCount;
                return Text(
                  '$count members',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                );
              },
            ),
          ],
        ),
        backgroundColor: cs.surface,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('spheres')
                  .doc(widget.sphere.id)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: cs.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final userId = FirebaseAuth.instance.currentUser?.uid;
                    final isMe = message['userId'] == userId;

                    return _buildMessageBubble(
                      context,
                      message['text'] ?? '',
                      message['nickname'] ?? 'Anonymous',
                      message['timestamp'] as Timestamp?,
                      isMe,
                    );
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  backgroundColor: cs.primary,
                  child: Icon(Icons.send, color: cs.onPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    String text,
    String nickname,
    Timestamp? timestamp,
    bool isMe,
  ) {
    final cs = Theme.of(context).colorScheme;
    final time = timestamp?.toDate();
    final timeStr = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  nickname,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? cs.primaryContainer : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18).copyWith(
                  topLeft: isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  topRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? cs.onPrimaryContainer.withOpacity(0.7)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _userNickname == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('spheres')
          .doc(widget.sphere.id)
          .collection('messages')
          .add({
            'text': text,
            'userId': userId,
            'nickname': _userNickname,
            'timestamp': FieldValue.serverTimestamp(),
          });

      _messageController.clear();

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
