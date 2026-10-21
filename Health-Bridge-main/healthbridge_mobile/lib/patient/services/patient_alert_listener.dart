import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../models/emergency_alert.dart';
import '../../services/emergency_service.dart';
import '../widgets/patient_sos_banner.dart';

/// Wraps the patient's app and shows a global banner while their SOS
/// is active or being responded to.
class PatientAlertListener extends StatefulWidget {
  final Widget child;

  const PatientAlertListener({super.key, required this.child});

  @override
  State<PatientAlertListener> createState() => _PatientAlertListenerState();
}

class _PatientAlertListenerState extends State<PatientAlertListener> {
  final EmergencyService _service = EmergencyService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final uid = authProvider.user?.uid ?? '';

    if (uid.isEmpty) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        StreamBuilder<EmergencyAlert?>(
          stream: _service.watchMyActiveAlert(uid),
          builder: (context, snapshot) {
            final alert = snapshot.data;
            if (alert == null) return const SizedBox.shrink();

            if (alert.status != 'active' && alert.status != 'responding') {
              return const SizedBox.shrink();
            }

            return PatientSosBanner(
              status: alert.status,
              responseType: alert.responseType,
              chwName: alert.chwName ?? 'Your CHW',
              timeSince: alert.timeSinceCreated,
            );
          },
        ),
      ],
    );
  }
}