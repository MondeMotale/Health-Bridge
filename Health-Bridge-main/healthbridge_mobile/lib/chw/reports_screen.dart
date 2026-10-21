import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'create_report_screen.dart';
import '../../services/report_service.dart';
import '../../auth/auth_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? chwId = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Reports'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: chwId == null
          ? const Center(child: Text('User not logged in'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: ReportService().getReportsForChw(chwId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final reports = snapshot.data ?? [];

                if (reports.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No reports sent yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('Tap the + button to create one.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _buildReportCard(context, report);
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateReportScreen()),
          );
        },
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- MAIN REPORT CARD (CLICKABLE) ---
  Widget _buildReportCard(BuildContext context, Map<String, dynamic> report) {
    final bool isRead = report['isRead'] ?? false;
    final String title = report['title'] ?? 'Untitled Report';
    final String content = report['content'] ?? 'No content';
    final String dateStr = report['_displayDate'] ?? 'Just now';

    return InkWell(
      onTap: () {
        _showReportDetailDialog(context, report);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border(left: BorderSide(color: isRead ? Colors.green : Colors.orange, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A2E)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isRead ? 'Read by Admin' : 'Pending',
                    style: TextStyle(
                      color: isRead ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // --- CENTERED POP-UP WITH EDIT FUNCTIONALITY (FIXED) ---
  void _showReportDetailDialog(BuildContext context, Map<String, dynamic> report) {
    final TextEditingController titleController = TextEditingController(text: report['title'] ?? '');
    final TextEditingController contentController = TextEditingController(text: report['content'] ?? '');
    final String reportId = report['id'];

    // Moved the state variables OUTSIDE the builder
    bool isEditing = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setState) {

            // Helper to update the report in Firestore
            Future<void> updateReport() async {
              if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and content cannot be empty'), backgroundColor: Colors.red),
                );
                return;
              }

              setState(() => isSaving = true);

              try {
                // Update Firestore AND reset isRead to false
                await ReportService().updateReport(
                  reportId: reportId,
                  newTitle: titleController.text.trim(),
                  newContent: contentController.text.trim(),
                  resetReadStatus: true,
                );

                if (context.mounted) {
                  setState(() {
                    isEditing = false;
                    isSaving = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report updated! Admin will see your changes as new.'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  setState(() => isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isEditing ? 'Edit Report' : report['title'] ?? 'Untitled',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                          ),
                        ),
                        if (!isEditing)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
                            onPressed: () {
                              setState(() {
                                isEditing = true;
                              });
                            },
                          ),
                        if (isEditing)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                isEditing = false;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // --- DATE ---
                   Text('Sent: ${report['_displayDate'] ?? 'Just now'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 16),

                    // --- CONTENT / EDIT FORM ---
                    if (!isEditing) ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(report['content'] ?? 'No content', style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Status: ${report['isRead'] == true ? "Read by Admin" : "Pending"}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ] else ...[
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Report Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Report Details',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : updateReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                          ),
                          child: isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                              : const Text('Save Changes'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // --- CLOSE BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}