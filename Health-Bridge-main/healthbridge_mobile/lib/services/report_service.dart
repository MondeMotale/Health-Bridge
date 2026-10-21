import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // CREATE: Submit a new report from a CHW
  Future<void> submitReport({
    required String chwId,
    required String chwName,
    required String title,
    required String content,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'chwId': chwId,
        'chwName': chwName,
        'title': title,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false, // New report flag for the Admin
      });
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  // READ (ADMIN): Get all reports in real-time
  Stream<List<Map<String, dynamic>>> getReports() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  // READ (CHW): Get reports submitted by THIS specific CHW
  Stream<List<Map<String, dynamic>>> getReportsForChw(String chwId) {
    return _firestore
        .collection('reports')
        .where('chwId', isEqualTo: chwId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          
          // Format the date safely for display
          if (data['createdAt'] != null) {
            try {
              // If it's a Firebase Timestamp, convert it to a readable date
              if (data['createdAt'].toDate != null) {
                data['_displayDate'] = data['createdAt'].toDate().toLocaleString();
              }
            } catch (_) {
              data['_displayDate'] = 'Just now';
            }
          } else {
            data['_displayDate'] = 'Just now';
          }
          return data;
        }).toList());
  }

  // MARK AS READ (ADMIN): Mark a report as read
  Future<void> markAsRead(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({
      'isRead': true,
    });
  }

  // --- NEW: UPDATE / EDIT a report from the CHW ---
  Future<void> updateReport({
    required String reportId,
    required String newTitle,
    required String newContent,
    required bool resetReadStatus,
  }) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'title': newTitle,
        'content': newContent,
        'isRead': resetReadStatus ? false : true,
      });
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }
}