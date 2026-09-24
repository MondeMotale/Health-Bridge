import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class EmergencyServicesScreen extends StatelessWidget {
  const EmergencyServicesScreen({super.key});

  Future<void> _callNumber(String number) async {
    final url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Services'),
        backgroundColor: const Color(AppConstants.dangerRed),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(AppConstants.dangerRed),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'EMERGENCY',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Text(
                  'If this is a medical emergency, call immediately',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildEmergencyButton('Call Ambulance', '10177', Icons.local_hospital),
                const SizedBox(height: 16),
                _buildEmergencyButton('Emergency Services', '112', Icons.emergency),
                const SizedBox(height: 16),
                _buildEmergencyButton('Police', '10111', Icons.local_police),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton(String title, String number, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _callNumber(number),
        icon: Icon(icon, size: 28),
        label: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(number, style: const TextStyle(fontSize: 14)),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.dangerRed),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}