import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/iv_report.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'camera_screen.dart';
import 'login_screen.dart';

class SessionSelectionScreen extends StatefulWidget {
  const SessionSelectionScreen({super.key});

  @override
  State<SessionSelectionScreen> createState() => _SessionSelectionScreenState();
}

class _SessionSelectionScreenState extends State<SessionSelectionScreen> {
  final _dbService = DatabaseService();
  final _authService = AuthService();

  List<IVSession> _sessions = [];
  IVSession? _selectedSession;
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final sessions = await _dbService.getActiveSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
          if (sessions.isEmpty) {
            _errorMessage = 'No active IV sessions found.\nPlease contact your faculty.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load sessions. Tap retry.';
        });
      }
    }
  }

  void _proceedToReporting() {
    if (_selectedSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an IV session to proceed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => FacultyReportScreen(session: _selectedSession!)),
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  List<IVSession> get _filteredSessions {
    if (_searchQuery.isEmpty) return _sessions;
    final q = _searchQuery.toLowerCase();
    return _sessions
        .where((s) =>
    s.companyName.toLowerCase().contains(q) ||
        s.department.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select IV Session'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadSessions,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: SpinKitFadingCircle(
          color: Theme.of(context).colorScheme.primary,
          size: 50,
        ),
      )
          : _errorMessage.isNotEmpty
          ? _buildErrorUI()
          : _buildSessionListUI(),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionListUI() {
    final filtered = _filteredSessions;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                      'Select the company visit to submit your attendance proof.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by company or department…',
              prefixIcon: const Icon(Icons.search),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 12),

          // Session count
          Text(
            '${filtered.length} active session${filtered.length == 1 ? '' : 's'}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Session list
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No sessions match your search.'))
                : ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final session = filtered[index];
                final isSelected = _selectedSession?.id == session.id;

                return Card(
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      child: Icon(
                        Icons.location_city,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    title: Text(
                      session.companyName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Dept: ${session.department}'),
                    trailing: Radio<IVSession>(
                      value: session,
                      groupValue: _selectedSession,
                      onChanged: (val) =>
                          setState(() => _selectedSession = val),
                    ),
                    onTap: () =>
                        setState(() => _selectedSession = session),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Proceed button
          FilledButton.icon(
            onPressed: _proceedToReporting,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Proceed to Report Submission',
                style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
