import 'package:flutter/material.dart';

class PatientResourcesScreen extends StatelessWidget {
  const PatientResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Treatment Plan'),
        backgroundColor: const Color(0xFF1E3A8A), // <--- Dark Navy
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER SECTION (Diagnosis) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 30, bottom: 30, left: 20, right: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A), // <--- Dark Navy
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Diagnosis',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hypertension (High Blood Pressure)',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Started: August 2026 • Duration: Ongoing',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- MEDICATION & TREATMENT CARDS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💊 Active Medications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 12),
                  _buildMedicationCard(
                    name: 'Amlodipine 5mg',
                    dosage: '1 Tablet Daily',
                    instructions: 'Take in the morning with food',
                    duration: '30-day supply',
                    refills: '1 refill remaining',
                  ),
                  const SizedBox(height: 12),
                  _buildMedicationCard(
                    name: 'Lisinopril 10mg',
                    dosage: '1 Tablet Daily',
                    instructions: 'Take at bedtime',
                    duration: '30-day supply',
                    refills: '2 refills remaining',
                  ),

                  const SizedBox(height: 24),

                  // --- LIFESTYLE & FOLLOW-UP ---
                  const Text(
                    '📋 Treatment Guidelines',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGuidelineRow('✅', 'Monitor blood pressure daily'),
                        const SizedBox(height: 8),
                        _buildGuidelineRow('🧂', 'Reduce sodium intake to < 2,000mg daily'),
                        const SizedBox(height: 8),
                        _buildGuidelineRow('🏃', 'Exercise at least 30 minutes per day'),
                        const SizedBox(height: 8),
                        _buildGuidelineRow('📅', 'Follow-up appointment scheduled for 09/15/2026'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- EMERGENCY CONTACT ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'If you experience severe side effects',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Call emergency services immediately or contact your CHW.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard({
    required String name,
    required String dosage,
    required String instructions,
    required String duration,
    required String refills,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication, color: Color(0xFF1E3A8A), size: 24),
              const SizedBox(width: 12),
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow('💊 Dosage:', dosage),
          const SizedBox(height: 6),
          _buildDetailRow('📝 Instructions:', instructions),
          const SizedBox(height: 6),
          _buildDetailRow('📦 Supply:', duration),
          const SizedBox(height: 6),
          _buildDetailRow('🔄 Refills:', refills),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildGuidelineRow(String icon, String text) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 14),
          ),
        ),
      ],
    );
  }
}