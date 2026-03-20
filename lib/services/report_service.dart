import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> submitIVReport({
    required String facultyId,
    required String facultyName,
    required String companyName,
    required String department,
    File? imageFile,
    Uint8List? imageBytes,
    required double rating,
    required String feedback,
    required GeoPoint location,
    double? locationAccuracy,
    String? keyLearnings,
    String? sessionId,
  }) async {
    // ── Input Validation ──────────────────────────────────────
    if (facultyId.trim().isEmpty) {
      throw Exception('Invalid user. Please log in again.');
    }
    if (companyName.trim().isEmpty || department.trim().isEmpty) {
      throw Exception('Invalid session. Company or department missing.');
    }
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5.');
    }
    if (feedback.trim().isEmpty) {
      throw Exception('Feedback is required.');
    }
    if (kIsWeb && imageBytes == null) {
      throw Exception('Photo is required. Please capture an image.');
    }
    if (!kIsWeb && imageFile == null) {
      throw Exception('Photo is required. Please capture an image.');
    }
    if (kIsWeb && imageBytes != null && imageBytes.lengthInBytes > 10 * 1024 * 1024) {
      throw Exception('Photo is too large. Maximum size is 10MB.');
    }

    // ── Sanitize inputs ───────────────────────────────────────
    final sanitizedCompany = companyName.trim().replaceAll(RegExp(r'[^\w\s\-]'), '');
    final sanitizedDept = department.trim().replaceAll(RegExp(r'[^\w\s\-]'), '');
    final sanitizedFeedback = feedback.trim();
    final sanitizedLearnings = keyLearnings?.trim();
    final sanitizedFacultyName = facultyName.trim();

    try {
      // ── Upload Image ──────────────────────────────────────
      final fileName =
          '${facultyId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage
          .ref()
          .child('reports')
          .child(sanitizedCompany)
          .child(sanitizedDept)
          .child(fileName);

      String downloadUrl;

      if (kIsWeb) {
        final uploadTask = storageRef.putData(
          imageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
      } else {
        final uploadTask = storageRef.putFile(
          imageFile!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
      }

      // ── Save to Firestore ─────────────────────────────────
      final docRef = await _db.collection('reports').add({
        'facultyId': facultyId,
        'facultyName': sanitizedFacultyName,
        'companyName': sanitizedCompany,
        'department': sanitizedDept,
        if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
        'photoUrl': downloadUrl,
        'rating': rating,
        'feedback': sanitizedFeedback,
        if (sanitizedLearnings != null && sanitizedLearnings.isNotEmpty)
          'keyLearnings': sanitizedLearnings,
        'location': location,
        if (locationAccuracy != null) 'locationAccuracy': locationAccuracy,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Verified',
        'platform': kIsWeb ? 'web' : 'mobile',
      });

      debugPrint('Report submitted: ${docRef.id}');
      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('Firebase error [${e.code}]: ${e.message}');
      switch (e.code) {
        case 'storage/unauthorized':
          throw Exception('Permission denied. Please log in again.');
        case 'storage/quota-exceeded':
          throw Exception('Storage quota exceeded. Contact admin.');
        case 'storage/canceled':
          throw Exception('Upload cancelled. Please try again.');
        case 'permission-denied':
          throw Exception('Access denied. Check your account role.');
        default:
          throw Exception('Upload failed: ${e.message}');
      }
    } catch (e) {
      debugPrint('ReportService.submitIVReport error: $e');
      rethrow;
    }
  }

  Future<void> deleteReport(String reportId, String photoUrl) async {
    if (reportId.trim().isEmpty) {
      throw Exception('Invalid report ID.');
    }
    try {
      // Delete Firestore document
      await _db.collection('reports').doc(reportId).delete();

      // Delete photo from Storage
      if (photoUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(photoUrl).delete();
        } catch (e) {
          // Photo might already be deleted — log but don't throw
          debugPrint('Photo delete warning: $e');
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('deleteReport Firebase error [${e.code}]: ${e.message}');
      throw Exception('Failed to delete report: ${e.message}');
    } catch (e) {
      debugPrint('ReportService.deleteReport error: $e');
      rethrow;
    }
  }
}