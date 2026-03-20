import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/iv_report.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import 'faculty_dashboard.dart';

class FacultyReportScreen extends StatefulWidget {
  final IVSession session;
  const FacultyReportScreen({super.key, required this.session});

  @override
  State<FacultyReportScreen> createState() => _FacultyReportScreenState();
}

class _FacultyReportScreenState extends State<FacultyReportScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  final _locationService = LocationService();
  final _authService = AuthService();
  final _reportService = ReportService();

  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isCapturing = false;
  double _rating = 3.0;
  final _feedbackController = TextEditingController();
  final _keyLearningsController = TextEditingController();
  Map<String, dynamic>? _locationData;
  String _locationStatus = 'Fetching GPS…';
  bool _locationSuccess = false;
  double? _locationAccuracy;

  // Captured photo (works on both web and mobile)
  XFile? _capturedPhoto;
  Uint8List? _capturedBytes;
  bool _photoCaptured = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _getLocation();
  }

  // ─── Camera Init (works on Web + Mobile) ─────────────────────

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _isCameraReady = true);
        return;
      }

      // On web prefer front camera, on mobile prefer back
      CameraDescription selectedCam;
      if (kIsWeb) {
        selectedCam = _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );
      } else {
        selectedCam = _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );
      }

      await _startCamera(selectedCam);
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _isCameraReady = true);
    }
  }

  Future<void> _startCamera(CameraDescription cam) async {
    try {
      _cameraController?.dispose();
      _cameraController = CameraController(
        cam,
        kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Start camera error: $e');
      if (mounted) setState(() => _isCameraReady = true);
    }
  }

  // Switch between front/back camera
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final current = _cameraController?.description;
    final next = _cameras.firstWhere(
          (c) => c != current,
      orElse: () => _cameras.first,
    );
    setState(() => _isCameraReady = false);
    await _startCamera(next);
  }

  // ─── Capture Photo ────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      setState(() => _isCapturing = true);
      final pic = await _cameraController!.takePicture();
      final bytes = await pic.readAsBytes();
      setState(() {
        _capturedPhoto = pic;
        _capturedBytes = bytes;
        _photoCaptured = true;
        _isCapturing = false;
      });
    } catch (e) {
      debugPrint('Capture error: $e');
      setState(() => _isCapturing = false);
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedPhoto = null;
      _capturedBytes = null;
      _photoCaptured = false;
    });
  }

  // ─── Location ─────────────────────────────────────────────────

  Future<void> _getLocation() async {
    setState(() {
      _locationStatus = 'Fetching GPS…';
      _locationSuccess = false;
    });
    final loc = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _locationData = loc;
        _locationSuccess = loc['success'] == true;
        _locationAccuracy =
        _locationSuccess ? (loc['accuracy'] as num?)?.toDouble() : null;
        _locationStatus = _locationSuccess
            ? _locationService.accuracyLabel(_locationAccuracy)
            : '${loc['message'] ?? 'Location error'}';
      });
    }
  }

  // ─── Submit ───────────────────────────────────────────────────

  Future<void> _submitReport() async {
    if (!_locationSuccess || _locationData == null) {
      _showSnack('Waiting for GPS signal. Please retry.');
      return;
    }
    if (!_photoCaptured || _capturedBytes == null) {
      _showSnack('Please capture a photo first.');
      return;
    }
    if (_feedbackController.text.trim().isEmpty) {
      _showSnack('Please add your observations before submitting.');
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    try {
      final facultyName = await _authService.getStudentName();

      await _reportService.submitIVReport(
        facultyId: _authService.currentUser!.uid,
        facultyName: facultyName,
        companyName: widget.session.companyName,
        department: widget.session.department,
        sessionId: widget.session.id,
        imageFile: kIsWeb ? null : File(_capturedPhoto!.path),
        imageBytes: kIsWeb ? _capturedBytes : null,
        rating: _rating,
        feedback: _feedbackController.text.trim(),
        keyLearnings: _keyLearningsController.text.trim(),
        location: GeoPoint(
            _locationData!['latitude'], _locationData!['longitude']),
        locationAccuracy: _locationAccuracy,
      );

      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const FacultyDashboard()));
      }
    } catch (e) {
      debugPrint('submitReport error: $e');
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _feedbackController.dispose();
    _keyLearningsController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Starting camera…'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submit Attendance Proof'),
            Text(
              '${widget.session.companyName} · ${widget.session.department}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          // Switch camera button
          if (!_photoCaptured && _cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              tooltip: 'Switch Camera',
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Camera / Preview Section ──
            _buildCameraSection(),

            // ── Form Section ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGpsStatusCard(),
                  const SizedBox(height: 20),
                  Text(
                    'Experience Rating: ${_rating.toInt()} / 5 Stars',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _rating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '${_rating.toInt()}★',
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyLearningsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Key Learnings / Industrial Focus',
                      hintText: 'What did you learn or observe?',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Additional Observations *',
                      hintText: 'Required — describe your visit experience.',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : _submitReport,
                      icon: _isProcessing
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        _isProcessing
                            ? 'Uploading Report…'
                            : 'Submit Proof to Portal',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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

  // ─── Camera Section Widget ────────────────────────────────────

  Widget _buildCameraSection() {
    return SizedBox(
      height: 380,
      width: double.infinity,
      child: Stack(
        children: [
          // Live preview OR captured photo
          if (_photoCaptured && _capturedBytes != null)
            Image.memory(
              _capturedBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CameraPreview(_cameraController!),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off,
                        color: Colors.white54, size: 48),
                    SizedBox(height: 8),
                    Text('Camera unavailable',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: _photoCaptured
              // After capture — Retake + Confirmed
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retakePhoto,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 18),
                        SizedBox(width: 6),
                        Text('Photo Captured',
                            style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              )
              // Shutter button
                  : GestureDetector(
                onTap: _isCapturing ? null : _capturePhoto,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing
                        ? Colors.white38
                        : Colors.white,
                    border: Border.all(
                        color: Colors.white70, width: 3),
                  ),
                  child: _isCapturing
                      ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black),
                  )
                      : const Icon(Icons.camera_alt,
                      color: Colors.black, size: 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── GPS Status Card ──────────────────────────────────────────

  Widget _buildGpsStatusCard() {
    final color = _locationSuccess ? Colors.green : Colors.red;
    final icon = _locationSuccess ? Icons.gps_fixed : Icons.gps_off;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Geotag Status',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color)),
                Text(_locationStatus,
                    style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
          if (!_locationSuccess)
            TextButton(
              onPressed: _getLocation,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}