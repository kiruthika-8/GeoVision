import 'package:cloud_firestore/cloud_firestore.dart';

class IVSession {
  final String id;
  final String companyName;
  final String department;
  final DateTime date;
  final DateTime? expiresAt;
  final bool isActive;
  final String? createdBy;
  final int durationHours;

  const IVSession({
    required this.id,
    required this.companyName,
    required this.department,
    required this.date,
    this.expiresAt,
    required this.isActive,
    this.createdBy,
    this.durationHours = 24,
  });

  factory IVSession.fromMap(Map<String, dynamic> map, String id) {
    return IVSession(
      id: id,
      companyName: map['companyName']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      date: (map['date'] is Timestamp)
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: (map['expiresAt'] is Timestamp)
          ? (map['expiresAt'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] as bool? ?? true,
      createdBy: map['createdBy']?.toString(),
      durationHours: (map['durationHours'] as int?) ?? 24,
    );
  }

  /// True if the session has passed its expiry time.
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Remaining duration before session expires.
  Duration get timeRemaining {
    if (expiresAt == null) return Duration.zero;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Human-readable countdown e.g. "18h 42m remaining"
  String get countdownLabel {
    final r = timeRemaining;
    if (r == Duration.zero) return 'Expired';
    final h = r.inHours;
    final m = r.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m remaining';
    return '${m}m remaining';
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'department': department,
      'date': Timestamp.fromDate(date),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'isActive': isActive,
      if (createdBy != null) 'createdBy': createdBy,
      'durationHours': durationHours,
    };
  }
}

class IVReport {
  final String? id;
  final String facultyId;
  final String facultyName;
  final String companyName;
  final String department;
  final String? sessionId;
  final double latitude;
  final double longitude;
  final double? locationAccuracy;
  final String photoUrl;
  final DateTime timestamp;
  final double rating;
  final String feedback;
  final String? keyLearnings;
  final String status;

  const IVReport({
    this.id,
    required this.facultyId,
    required this.facultyName,
    required this.companyName,
    required this.department,
    this.sessionId,
    required this.latitude,
    required this.longitude,
    this.locationAccuracy,
    required this.photoUrl,
    required this.timestamp,
    required this.rating,
    required this.feedback,
    this.keyLearnings,
    this.status = 'Verified',
  });

  factory IVReport.fromMap(Map<String, dynamic> map, String id) {
    double lat = 0.0;
    double lng = 0.0;

    if (map['location'] is GeoPoint) {
      final gp = map['location'] as GeoPoint;
      lat = gp.latitude;
      lng = gp.longitude;
    }

    return IVReport(
      id: id,
      facultyId: map['facultyId']?.toString() ?? '',
      facultyName: map['facultyName']?.toString() ?? 'Unknown',
      companyName: map['companyName']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      sessionId: map['sessionId']?.toString(),
      latitude: lat,
      longitude: lng,
      locationAccuracy: (map['locationAccuracy'] as num?)?.toDouble(),
      photoUrl: map['photoUrl']?.toString() ?? '',
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      feedback: map['feedback']?.toString() ?? '',
      keyLearnings: map['keyLearnings']?.toString(),
      status: map['status']?.toString() ?? 'Verified',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'facultyId': facultyId,
      'facultyName': facultyName,
      'companyName': companyName,
      'department': department,
      if (sessionId != null) 'sessionId': sessionId,
      'location': GeoPoint(latitude, longitude),
      if (locationAccuracy != null) 'locationAccuracy': locationAccuracy,
      'photoUrl': photoUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'rating': rating,
      'feedback': feedback,
      if (keyLearnings != null) 'keyLearnings': keyLearnings,
      'status': status,
    };
  }
}