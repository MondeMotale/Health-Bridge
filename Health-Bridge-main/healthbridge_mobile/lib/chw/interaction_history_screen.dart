import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/auth_provider.dart';
import '../../services/patient_interaction_service.dart';

class InteractionHistoryScreen extends StatefulWidget {
  const InteractionHistoryScreen({super.key});

  @override
  State<InteractionHistoryScreen> createState() =>
      _InteractionHistoryScreenState();
}

class _InteractionHistoryScreenState extends State<InteractionHistoryScreen> {
  final PatientInteractionService _service = PatientInteractionService();
  bool _exporting = false;

  String _csvValue(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  DateTime? _dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _timeLabel(dynamic value) {
    if (value is DateTime) return DateFormat.yMd().add_jm().format(value);
    return 'Time unavailable';
  }

  Future<void> _export(String chwId) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final records = await _service.getForChw(chwId);
      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('There are no records to export yet.')),
          );
        }
        return;
      }
      const headers = [
        'Date and time',
        'Patient',
        'Interaction type',
        'Summary',
        'Details',
        'Actor',
        'Record ID',
      ];
      final rows = records.map((record) {
        return [
          _timeLabel(_dateOf(record['createdAt'])),
          record['patientName'],
          record['type'],
          record['summary'],
          record['details'],
          record['actorName'],
          record['relatedRecordId'],
        ].map(_csvValue).join(',');
      });
      final csv = '${headers.map(_csvValue).join(',')}\n${rows.join('\n')}';
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}patient-interactions-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
      );
      await file.writeAsString(csv, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Patient interaction history',
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export records: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chwId = Provider.of<AuthProvider>(context).user?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Patient Interaction History'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Export interaction records as CSV',
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            onPressed:
                _exporting || chwId == null ? null : () => _export(chwId),
          ),
        ],
      ),
      body: chwId == null
          ? const Center(
              child: Text('Please log in to view interaction records.'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.watchForChw(chwId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Semantics(
                      label: 'Loading patient interaction records',
                      liveRegion: true,
                      child: const CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load interaction records. Check your connection and try again.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final records = snapshot.data ?? [];
                if (records.isEmpty) {
                  return Center(
                    child: Semantics(
                      label: 'No patient interactions have been recorded yet.',
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: const Text(
                          'No patient interactions have been recorded yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final details = record['details']?.toString() ?? '';
                    return Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    record['patientName']?.toString() ??
                                        'Unknown patient',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    record['type']?.toString() ?? 'Interaction',
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              record['summary']?.toString() ??
                                  'Interaction recorded',
                              style: const TextStyle(color: Color(0xFF1F2937)),
                            ),
                            if (details.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                details,
                                style:
                                    const TextStyle(color: Color(0xFF374151)),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              _timeLabel(_dateOf(record['createdAt'])),
                              style: const TextStyle(
                                color: Color(0xFF4B5563),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
