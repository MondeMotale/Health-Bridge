import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Send a text message
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    try {
      await _firestore.collection('messages').add({
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'deletedFor': <String>[], // who has hidden this message
      });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // 2. Listen for messages between two users
  //    Hides messages the current user has "deleted for me"
  Stream<List<Map<String, dynamic>>> getMessages({
    required String user1,
    required String user2,
  }) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return _firestore
        .collection('messages')
        .where('senderId', whereIn: [user1, user2])
        .snapshots()
        .map((snapshot) {
          // Attach doc id so the UI can delete a specific message
          List<Map<String, dynamic>> allMessages = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Keep only messages between user1 and user2
          List<Map<String, dynamic>> filteredMessages = allMessages
              .where((msg) =>
                  (msg['senderId'] == user1 && msg['receiverId'] == user2) ||
                  (msg['senderId'] == user2 && msg['receiverId'] == user1))
              // Hide messages the current user deleted for themselves
              .where((msg) {
                final deletedFor = (msg['deletedFor'] as List?) ?? [];
                return !deletedFor.contains(currentUserId);
              })
              .toList();

          // Sort by timestamp
          filteredMessages.sort((a, b) {
            final dynamic aTime = a['timestamp'];
            final dynamic bTime = b['timestamp'];

            if (aTime == null || bTime == null) return 0;
            if (aTime is Timestamp && bTime is Timestamp) {
              return aTime.compareTo(bTime);
            }
            return 0;
          });

          return filteredMessages;
        });
  }

  // 3. Delete a message ONLY for the current user (soft delete)
  Future<void> deleteForMe(String messageId, String userId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'deletedFor': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // 4. Delete a message for EVERYONE (hard delete)
  Future<void> deleteForEveryone(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // 5. Generate a unique channel name for the call
  String generateCallChannel(String user1, String user2) {
    return 'call_${user1}_$user2';
  }
}