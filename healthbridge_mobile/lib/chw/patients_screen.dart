import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/patient.dart';
import '../../services/firestore_service.dart';
import '../../services/referral_service.dart';
import '../../services/appointment_service.dart'; // <--- New Service
import '../../models/referral.dart';
import '../../models/appointment.dart'; // <--- New Model
import '../../auth/auth_provider.dart';
import 'create_patient.dart'; 

class PatientsScreen extends StatefulWidget {
  final String initialFilter; // 'all', 'followUp', 'done'
  
  const PatientsScreen({
    super.key, 
    this.initialFilter = 'all'
  });

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  Stream<List<Patient>>? _patientsStream;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String? chwId = authProvider.user?.uid;
    if (chwId != null) {
      _patientsStream = FirestoreService().getPatientsForChw(chwId);
    }
  }

  List<Patient> _filterPatients(List<Patient> allPatients) {
    if (widget.initialFilter == 'all') return allPatients;
    if (widget.initialFilter == 'followUp') {
      return allPatients.where((p) => p.status == 'Needs Follow-up').toList();
    }
    if (widget.initialFilter == 'done') {
      return allPatients.where((p) => p.status == 'Stable').toList();
    }
    return allPatients;
  }

  // --- CLEAN MAIN POP-UP (Info Only + 1 Action Button) ---
  void _showPatientQuickInfo(Patient patient) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- PATIENT HEADER ---
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                      child: Text(
                        patient.name[0],
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patient.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('${patient.age} yrs old', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                _buildInfoRow('Condition', patient.condition),
                _buildInfoRow('Status', patient.status),
                _buildInfoRow('Phone', patient.phone),
                _buildInfoRow('Address', patient.address),
                if (patient.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  Text(patient.notes, style: const TextStyle(color: Colors.grey)),
                ],
                const SizedBox(height: 24),

                // --- SINGLE CLEAN ACTION BUTTON ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close info pop-up
                      _showActionSheet(patient); // Open bottom sheet
                    },
                    icon: const Icon(Icons.more_horiz),
                    label: const Text('Actions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- CENTERED ACTION DIALOG ---
  void _showActionSheet(Patient patient) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
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
                const Center(
                  child: Text(
                    'Choose an Action',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                  ),
                ),
                const SizedBox(height: 24),
                
                // --- OPTION 1: REFER ---
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    _showReferralDialog(patient);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.medical_services, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Refer Patient', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                              const Text('Send to specialist or department', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                
                // --- OPTION 2: BOOK APPOINTMENT ---
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    _showBookAppointmentDialog(patient);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                              const Text('Schedule a date and time for visit', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                
                // --- OPTION 3: DELETE ---
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDeletePatient(context, patient);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Delete Patient', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                              const Text('Permanently remove this record', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // --- CLOSE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // --- REFERRAL DIALOG ---
  void _showReferralDialog(Patient patient) {
    final TextEditingController deptController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    String selectedUrgency = 'Medium';
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Refer Patient', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 16),
                
                TextField(
                  controller: deptController,
                  decoration: const InputDecoration(
                    labelText: 'Department (e.g. Cardiology)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (e.g. Soweto)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedUrgency,
                  items: ['Low', 'Medium', 'High', 'Critical']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => selectedUrgency = val!,
                  decoration: const InputDecoration(
                    labelText: 'Urgency',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final chwId = authProvider.user?.uid;
                      final chwName = authProvider.user?.displayName ?? 'CHW';
                      
                      final referral = Referral(
                        id: const Uuid().v4(),
                        patientId: patient.id,
                        patientName: patient.name,
                        chwId: chwId ?? '',
                        chwName: chwName,
                        condition: patient.condition,
                        department: deptController.text.trim(),
                        location: locationController.text.trim(),
                        urgency: selectedUrgency,
                        status: 'Pending',
                        createdAt: DateTime.now(),
                      );
                      
                      try {
                        await ReferralService().submitReferral(referral);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Referral sent successfully!'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Submit Referral', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- APPOINTMENT DIALOG (With working Date/Time pickers) ---
  void _showBookAppointmentDialog(Patient patient) {
    final TextEditingController locationController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    
    // Initial date/time (default to 7 days from now at 10:00 AM)
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        // Use StatefulBuilder to update the UI inside the Dialog
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Book Appointment', 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 16),
                    
                    // --- DATE PICKER ---
                    ListTile(
                      leading: const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A)),
                      title: Text('Date: ${selectedDate.toLocal().toString().split(' ')[0]}'),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    
                    // --- TIME PICKER ---
                    ListTile(
                      leading: const Icon(Icons.access_time, color: Color(0xFF1E3A8A)),
                      title: Text('Time: ${selectedTime.format(context)}'),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final chwId = authProvider.user?.uid;
                          final chwName = authProvider.user?.displayName ?? 'CHW';
                          
                          // Combine Date + Time correctly
                          final DateTime finalDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );

                          final appointment = Appointment(
                            id: const Uuid().v4(),
                            patientId: patient.id,
                            patientName: patient.name,
                            chwId: chwId ?? '',
                            chwName: chwName,
                            dateTime: finalDateTime,
                            location: locationController.text.trim(),
                            notes: notesController.text.trim(),
                            status: 'Scheduled',
                          );
                          
                          try {
                            await AppointmentService().bookAppointment(appointment);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Appointment booked successfully!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Confirm Appointment', style: TextStyle(color: Colors.white, fontSize: 16)),
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

  // --- DELETE CONFIRMATION DIALOG ---
  void _confirmDeletePatient(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Patient?'),
          content: Text('Are you sure you want to permanently delete ${patient.name}? This action cannot be undone.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop(); // Close the dialog
                try {
                  await FirestoreService().deletePatient(patient.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${patient.name} deleted successfully.'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF1A1A2E)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Patients';
    if (widget.initialFilter == 'followUp') title = 'Pending Visits';
    if (widget.initialFilter == 'done') title = 'Completed Visits';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Patient>>(
        stream: _patientsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_hasLoadedOnce) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allPatients = snapshot.data ?? [];
          final patients = _filterPatients(allPatients);

          if (allPatients.isEmpty) {
            _hasLoadedOnce = true;
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No patients yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Tap the + button to add one.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (patients.isEmpty) {
            _hasLoadedOnce = true;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.filter_list, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No patients match the "${widget.initialFilter}" filter.', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          _hasLoadedOnce = true;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final patient = patients[index];
              return _buildPatientCard(patient);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePatientScreen()),
          );
        },
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPatientCard(Patient patient) {
    return GestureDetector(
      onTap: () => _showPatientQuickInfo(patient),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                child: Text(
                  patient.name[0],
                  style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.bold,
                    fontSize: 18
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${patient.age} yrs • ${patient.condition}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: patient.status == 'Critical'
                      ? Colors.red.withValues(alpha: 0.1)
                      : patient.status == 'Needs Follow-up'
                          ? Colors.orange.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  patient.status,
                  style: TextStyle(
                    color: patient.status == 'Critical'
                        ? Colors.red
                        : patient.status == 'Needs Follow-up'
                            ? Colors.orange
                            : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}