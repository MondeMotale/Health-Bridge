import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- ADDED THIS
import '../../models/patient.dart';
import '../../services/firestore_service.dart';
import '../../auth/auth_provider.dart' as AuthService;

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key});

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _selectedStatus = 'Stable';
  final List<String> _statusOptions = ['Stable', 'Needs Follow-up', 'Critical'];
  bool _isSaving = false;

  Future<void> _savePatient() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final authProvider = Provider.of<AuthService.AuthProvider>(context, listen: false) as dynamic;
      final chwId = authProvider.user?.uid;

      if (chwId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in'), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
        return;
      }

      try {
        // STEP 1: SAVE THE CHW'S EMAIL AND PASSWORD SO WE CAN LOG THEM BACK IN LATER
        final chwEmail = authProvider.user?.email ?? '';
        final chwPassword = 'Chw@123'; // <--- REPLACE WITH YOUR CHW PASSWORD

        // STEP 2: CREATE THE PATIENT'S ACCOUNT
        final tempPassword = 'Patient@123';
        final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: tempPassword,
        );
        final patientUid = userCredential.user!.uid;

        // STEP 3: IMMEDIATELY LOG THE PATIENT OUT
        await FirebaseAuth.instance.signOut();

        // STEP 4: LOG THE CHW BACK IN (SO THEY STAY ON THEIR DASHBOARD)
        if (chwEmail.isNotEmpty && chwPassword.isNotEmpty) {
          await authProvider.login(chwEmail, chwPassword);
        }

        // STEP 4.5: SAVE TO 'users' COLLECTION SO FIRESTORE KNOWS THEIR ROLE!
        await FirebaseFirestore.instance.collection('users').doc(patientUid).set({
          'uid': patientUid,
          'role': 'patient', // <--- This makes them a 'patient'
          'displayName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        });

        // STEP 5: SAVE THE PATIENT'S PROFILE TO FIRESTORE
        final newPatient = Patient(
          id: patientUid,
          name: _nameController.text.trim(),
          age: int.parse(_ageController.text.trim()),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          condition: _conditionController.text.trim(),
          status: _selectedStatus,
          notes: _notesController.text.trim(),
          assignedChwId: chwId,
          createdAt: DateTime.now(),
        );

        final firestoreService = FirestoreService();
        await firestoreService.addPatient(newPatient);

        // STEP 6: WAIT 3 SECONDS BEFORE SENDING PASSWORD RESET EMAIL
        await Future.delayed(const Duration(seconds: 3));
        await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient created successfully! Login email sent.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _conditionController.dispose();
    _notesController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54, // Semi-transparent background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Patient',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      prefixIcon: Icon(Icons.cake),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter an age';
                      final age = int.tryParse(value.trim());
                      if (age == null || age < 0 || age > 150) return 'Please enter a valid age (0-150)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final RegExp phoneRegex = RegExp(r'^[0-9+\- ]+$');
                      if (!phoneRegex.hasMatch(value.trim())) return 'Please enter a valid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Patient Email (For Login)',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a patient email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.home),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _conditionController,
                    decoration: const InputDecoration(
                      labelText: 'Medical Condition',
                      prefixIcon: Icon(Icons.medical_services),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter a medical condition';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.health_and_safety),
                      border: OutlineInputBorder(),
                    ),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem(value: status, child: Text(status));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedStatus = value!),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _savePatient,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Create Login'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}