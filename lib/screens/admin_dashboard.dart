import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/iv_report.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _authService = AuthService();
  String _searchQuery = '';
  String _filterDept = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoVision — Admin Portal'),
        actions: [
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allReports = snapshot.data!.docs
              .map((d) => IVReport.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();

          // Collect unique departments
          final depts = {'All', ...allReports.map((r) => r.department)}.toList()
            ..sort();

          // Apply filters
          final filtered = allReports.where((r) {
            final matchesDept =
                _filterDept == 'All' || r.department == _filterDept;
            final q = _searchQuery.toLowerCase();
            final matchesSearch = q.isEmpty ||
                r.facultyName.toLowerCase().contains(q) ||
                r.companyName.toLowerCase().contains(q) ||
                r.department.toLowerCase().contains(q);
            return matchesDept && matchesSearch;
          }).toList();

          return Column(
            children: [
              _buildStatsHeader(allReports),
              _buildFilterBar(depts),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No reports match your filter.'))
                    : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _buildReportCard(context, filtered[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsHeader(List<IVReport> reports) {
    final avgRating = reports.isEmpty
        ? 0.0
        : reports.map((r) => r.rating).reduce((a, b) => a + b) / reports.length;
    final companies = reports.map((r) => r.companyName).toSet().length;

    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total Reports', '${reports.length}', Icons.description_outlined),
          _statItem('Companies', '$companies', Icons.business_outlined),
          _statItem(
              'Avg Rating',
              avgRating.toStringAsFixed(1),
              Icons.star_half_outlined),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildFilterBar(List<String> depts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search faculty, company, dept…',
              prefixIcon: const Icon(Icons.search),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: depts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final dept = depts[i];
                final isSelected = _filterDept == dept;
                return FilterChip(
                  label: Text(dept),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _filterDept = dept),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, IVReport report) {
    return Card(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: report.photoUrl.isNotEmpty
                  ? Image.network(
                report.photoUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image),
                ),
              )
                  : Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.companyName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          report.status,
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(report.department,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Faculty: ${report.facultyName}',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                            (i) => Icon(
                          i < report.rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${report.rating.toStringAsFixed(1)} / 5',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  if (report.feedback.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      report.feedback,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                  if (report.locationAccuracy != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.gps_fixed, size: 12,
                            color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'GPS ±${report.locationAccuracy!.toStringAsFixed(0)}m',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
