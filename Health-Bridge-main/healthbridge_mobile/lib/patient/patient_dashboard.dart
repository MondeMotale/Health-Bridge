import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'emergency_services.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  String _patientName = 'Patient';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(AppConstants.prefUserName);
    if (name != null) {
      setState(() {
        _patientName = name;
      });
    }
  }

  // --- CENTERED INFO POP-UP DIALOGS ---
  void _showInfoDialog(String title, String message, IconData icon, Color color) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 10,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Matches app background
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        backgroundColor: const Color(0xFF1E3A8A), // <--- Dark Navy
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PATIENT PROFILE CARD (Dark Navy Theme) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFF1E3A8A), // <--- Dark Navy
                    child: Text(
                      _patientName[0],
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_patientName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('Patient', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.health_and_safety, color: Color(0xFF1E3A8A), size: 32),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- VITAL SIGNS (Modern 2x2 Grid) ---
            const Text(
              '📊 Your Vitals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildVitalCard('Blood Pressure', '120/80', 'mmHg', Icons.monitor_heart, const Color(0xFFEF4444))),
                const SizedBox(width: 12),
                Expanded(child: _buildVitalCard('Heart Rate', '72', 'bpm', Icons.favorite, const Color(0xFFEF4444))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildVitalCard('Oxygen Level', '98', '%', Icons.air, const Color(0xFF3B82F6))),
                const SizedBox(width: 12),
                Expanded(child: _buildVitalCard('Weight', '78', 'kg', Icons.monitor_weight, const Color(0xFFF59E0B))),
              ],
            ),
            const SizedBox(height: 24),

            // --- MEDICATION REMINDERS ---
            const Text(
              '💊 Medication Reminders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 12),
            _buildMedicationCard('Amlodipine 5mg', '1 tablet daily', 'Morning with food', Colors.blue.shade50),
            const SizedBox(height: 12),
            _buildMedicationCard('Lisinopril 10mg', '1 tablet daily', 'At bedtime', Colors.green.shade50),
            const SizedBox(height: 24),

            // --- CHW CONTACT ---
            const Text(
              '👨‍⚕️ Your CHW',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF1E3A8A), // <--- Dark Navy
                    child: Text('SD', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sipho Dlamini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Community Health Worker', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone, color: Color(0xFF1E3A8A)), // <--- Dark Navy
                    onPressed: () {
                      _showInfoDialog(
                        'Contact CHW',
                        'Calling Sipho Dlamini...\n(076) 432-4657',
                        Icons.phone,
                        const Color(0xFF1E3A8A),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- ACTION BUTTONS ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showInfoDialog(
                    'Request Visit',
                    'Your home visit request has been sent to your CHW. They will confirm the date and time with you shortly.',
                    Icons.home_repair_service,
                    const Color(0xFF10B981), // Green
                  );
                },
                icon: const Icon(Icons.home_repair_service),
                label: const Text('Request a Visit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyServicesScreen()));
                },
                icon: const Icon(Icons.emergency),
                label: const Text('Emergency Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444), // Red
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- VITAL CARD WIDGET ---
  Widget _buildVitalCard(String title, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // --- MEDICATION CARD WIDGET ---
  Widget _buildMedicationCard(String name, String dosage, String instruction, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication, color: Color(0xFF1E3A8A), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('$dosage • $instruction', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}