import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/iv_report.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DatabaseService? _instance;
  DatabaseService._internal();
  factory DatabaseService() => _instance ??= DatabaseService._internal();

  void initializeService() {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // ─── IV Sessions ──────────────────────────────────────────────

  /// Creates a session that auto-expires after [durationHours] (default 24h).
  Future<bool> createNewSession(
      String company,
      String dept, {
        String? createdBy,
        int durationHours = 24,
      }) async {
    if (company.trim().isEmpty || dept.trim().isEmpty) {
      debugPrint('createNewSession: company or dept is empty');
      return false;
    }
    try {
      final expiresAt = DateTime.now().add(Duration(hours: durationHours));
      await _db.collection('iv_sessions').add({
        'companyName': company.trim(),
        'department': dept.trim(),
        'date': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': true,
        'durationHours': durationHours,
        if (createdBy != null) 'createdBy': createdBy,
      });
      return true;
    } catch (e) {
      debugPrint('createNewSession error: $e');
      return false;
    }
  }

  Future<bool> deactivateSession(String sessionId) async {
    try {
      await _db.collection('iv_sessions').doc(sessionId).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('deactivateSession error: $e');
      return false;
    }
  }

  /// Fetch active sessions that haven't expired yet.
  Future<List<IVSession>> getActiveSessions() async {
    try {
      final now = Timestamp.now();
      final snap = await _db
          .collection('iv_sessions')
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt', descending: false)
          .get();

      return snap.docs
          .map((doc) => IVSession.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('getActiveSessions error: $e');
      return [];
    }
  }

  /// Live stream of active non-expired sessions.
  Stream<List<IVSession>> getActiveSessionsStream() {
    final now = Timestamp.now();
    return _db
        .collection('iv_sessions')
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: false)
        .snapshots()
        .map((sn) => sn.docs
        .map((doc) => IVSession.fromMap(doc.data(), doc.id))
        .where((s) =>
    s.expiresAt != null &&
        s.expiresAt!.isAfter(DateTime.now()))
        .toList())
        .handleError((e) {
      debugPrint('getActiveSessionsStream error: $e');
      return <IVSession>[];
    });
  }

  /// Live stream of a single session — used for countdown timer.
  Stream<IVSession?> getSessionStream(String sessionId) {
    return _db
        .collection('iv_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) =>
    doc.exists ? IVSession.fromMap(doc.data()!, doc.id) : null)
        .handleError((e) {
      debugPrint('getSessionStream error: $e');
      return null;
    });
  }

  // ─── Reports ──────────────────────────────────────────────────

  /// Live stream of ALL reports — admin live dashboard.
  Stream<List<IVReport>> getAllReportsStream() {
    return _db
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((sn) =>
        sn.docs.map((doc) => IVReport.fromMap(doc.data(), doc.id)).toList())
        .handleError((e) {
      debugPrint('getAllReportsStream error: $e');
      return <IVReport>[];
    });
  }

  /// Live stream of reports for a specific session — faculty live dashboard.
  Stream<List<IVReport>> getReportsBySession(
      String companyName, String department) {
    return _db
        .collection('reports')
        .where('companyName', isEqualTo: companyName)
        .where('department', isEqualTo: department)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((sn) =>
        sn.docs.map((doc) => IVReport.fromMap(doc.data(), doc.id)).toList())
        .handleError((e) {
      debugPrint('getReportsBySession error: $e');
      return <IVReport>[];
    });
  }

  Future<List<IVReport>> getReportsByFaculty(String facultyId) async {
    try {
      final snap = await _db
          .collection('reports')
          .where('facultyId', isEqualTo: facultyId)
          .orderBy('timestamp', descending: true)
          .get();

      return snap.docs
          .map((doc) => IVReport.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('getReportsByFaculty error: $e');
      return [];
    }
  }

  Future<bool> deleteReport(String reportId) async {
    try {
      await _db.collection('reports').doc(reportId).delete();
      return true;
    } catch (e) {
      debugPrint('deleteReport error: $e');
      return false;
    }
  }
}