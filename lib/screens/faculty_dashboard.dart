import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/iv_report.dart';
import 'login_screen.dart';
import 'camera_screen.dart';

class FacultyDashboard extends StatefulWidget {
  const FacultyDashboard({super.key});

  @override
  FacultyDashboardState createState() => FacultyDashboardState();
}

class FacultyDashboardState extends State<FacultyDashboard> {
  final _dbService = DatabaseService();
  final _authService = AuthService();

  String? _selectedCompany;
  String? _selectedDept;
  IVSession? _selectedSession;

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Portal'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('LIVE',
                    style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSessionSelector(),
          if (_selectedSession != null)
            _buildCountdownBanner(_selectedSession!),
          _buildActionButtons(context),
          const Divider(height: 1),
          Expanded(child: _buildReportList()),
        ],
      ),
    );
  }

  // ─── Countdown Banner ─────────────────────────────────────────

  Widget _buildCountdownBanner(IVSession session) {
    final remaining = session.timeRemaining;
    final isExpiringSoon = remaining.inHours < 2 && remaining > Duration.zero;
    final isExpired = session.isExpired;

    Color bgColor;
    Color textColor;
    IconData icon;

    if (isExpired) {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
      icon = Icons.timer_off;
    } else if (isExpiringSoon) {
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
      icon = Icons.timer_outlined;
    } else {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
      icon = Icons.timer_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(
            'Session active · ${session.countdownLabel}',
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const Spacer(),
          if (!isExpired && session.expiresAt != null)
            Text(
              'Ends ${_formatTime(session.expiresAt!)}',
              style: TextStyle(color: textColor, fontSize: 11),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ─── Session Selector ─────────────────────────────────────────

  Widget _buildSessionSelector() {
    return StreamBuilder<List<IVSession>>(
      stream: _dbService.getActiveSessionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        final sessions = snapshot.data ?? [];
        if (sessions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.amber.shade50,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber),
                SizedBox(width: 8),
                Text('No active sessions. Create one below.'),
              ],
            ),
          );
        }

        final companies = sessions.map((s) => s.companyName).toSet().toList();
        final departments = sessions.map((s) => s.department).toSet().toList();

        final effectiveCompany = companies.contains(_selectedCompany)
            ? _selectedCompany
            : companies.first;
        final effectiveDept = departments.contains(_selectedDept)
            ? _selectedDept
            : departments.first;

        final matched = sessions.firstWhere(
              (s) =>
          s.companyName == effectiveCompany &&
              s.department == effectiveDept,
          orElse: () => sessions.first,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_selectedCompany != effectiveCompany ||
              _selectedDept != effectiveDept ||
              _selectedSession?.id != matched.id) {
            setState(() {
              _selectedCompany = effectiveCompany;
              _selectedDept = effectiveDept;
              _selectedSession = matched;
            });
          }
        });

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('company_$effectiveCompany'),
                  value: effectiveCompany,
                  decoration: InputDecoration(
                    labelText: 'Company',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: companies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCompany = val;
                      _selectedSession = sessions.firstWhere(
                            (s) =>
                        s.companyName == val &&
                            s.department == _selectedDept,
                        orElse: () => sessions.first,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('dept_$effectiveDept'),
                  value: effectiveDept,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: departments
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDept = val;
                      _selectedSession = sessions.firstWhere(
                            (s) =>
                        s.companyName == _selectedCompany &&
                            s.department == val,
                        orElse: () => sessions.first,
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Action Buttons ───────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    final sessionExpired = _selectedSession?.isExpired ?? false;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showCreateSessionDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Session'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: sessionExpired ? null : () => goToCamera(context),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(sessionExpired ? 'Session Expired' : 'Submit Proof'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> goToCamera(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    // If selectedSession is null, try to fetch it directly
    if (_selectedSession == null) {
      try {
        final sessions = await _dbService.getActiveSessions();
        final match = sessions.firstWhere(
              (s) =>
          s.companyName == _selectedCompany &&
              s.department == _selectedDept,
          orElse: () => sessions.first,
        );
        if (mounted) setState(() => _selectedSession = match);
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Session not found. Please create a new one.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
    }

    if (_selectedSession!.isExpired) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content:
          Text('This session has expired. Please contact your faculty.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    if (mounted) {
      nav.push(MaterialPageRoute(
          builder: (_) => FacultyReportScreen(session: _selectedSession!)));
    }
  }

  // ─── Live Report List ─────────────────────────────────────────

  Widget _buildReportList() {
    if (_selectedCompany == null || _selectedDept == null) {
      return const Center(child: Text('Select a session to view reports.'));
    }

    return StreamBuilder<List<IVReport>>(
      stream:
      _dbService.getReportsBySession(_selectedCompany!, _selectedDept!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];

        return Column(
          children: [
            _buildLiveReportHeader(reports.length),
            Expanded(
              child: reports.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No reports yet — waiting for submissions.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: reports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    buildReportCard(reports[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveReportHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        children: [
          Text(
            '$count report${count == 1 ? '' : 's'} submitted',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Colors.white),
                SizedBox(width: 4),
                Text('Live',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReportCard(IVReport report) {
    return Card(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: report.photoUrl.isNotEmpty
              ? Image.network(
            report.photoUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 40),
          )
              : const Icon(Icons.image_not_supported, size: 40),
        ),
        title: Text(report.facultyName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                5,
                    (i) => Icon(
                  i < report.rating.round()
                      ? Icons.star
                      : Icons.star_border,
                  size: 14,
                  color: Colors.amber,
                ),
              ),
            ),
            if (report.feedback.isNotEmpty)
              Text(report.feedback,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Chip(
          label: Text(report.status,
              style: const TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: Colors.green,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ─── Create Session Dialog ────────────────────────────────────

  void showCreateSessionDialog(BuildContext context) {
    final compController = TextEditingController();
    final deptController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int selectedDuration = 24;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create IV Session'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: compController,
                  decoration: InputDecoration(
                    labelText: 'Company Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: deptController,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Active for:',
                        style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: selectedDuration,
                      items: const [
                        DropdownMenuItem(value: 4, child: Text('4 hours')),
                        DropdownMenuItem(value: 8, child: Text('8 hours')),
                        DropdownMenuItem(
                            value: 12, child: Text('12 hours')),
                        DropdownMenuItem(
                            value: 24, child: Text('24 hours')),
                        DropdownMenuItem(
                            value: 48, child: Text('48 hours')),
                      ],
                      onChanged: (val) => setDialogState(
                              () => selectedDuration = val ?? 24),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Expires at ${_formatExpiryTime(selectedDuration)}',
                  style:
                  TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final nav = Navigator.of(ctx);
                final success = await _dbService.createNewSession(
                  compController.text.trim(),
                  deptController.text.trim(),
                  createdBy: _authService.currentUser?.uid,
                  durationHours: selectedDuration,
                );
                nav.pop();
                if (mounted && success) {
                  setState(() {
                    _selectedCompany = compController.text.trim();
                    _selectedDept = deptController.text.trim();
                  });
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatExpiryTime(int hours) {
    final expiry = DateTime.now().add(Duration(hours: hours));
    final h = expiry.hour.toString().padLeft(2, '0');
    final m = expiry.minute.toString().padLeft(2, '0');
    final day = hours >= 24 ? ' tomorrow' : ' today';
    return '$h:$m$day';
  }
}