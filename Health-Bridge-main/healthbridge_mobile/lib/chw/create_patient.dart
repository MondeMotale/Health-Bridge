import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/patient.dart';
import '../../services/firestore_service.dart';
import '../../auth/auth_provider.dart';
import '../../widgets/icd10_picker.dart';
import '../firebase_options.dart';

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key});

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _saIdController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _selectedIcd10Code;
  String? _selectedIcd10Name;

  String _selectedStatus = 'Stable';
  final List<String> _statusOptions = ['Stable', 'Needs Follow-up', 'Critical'];
  bool _isSaving = false;

  String _generateStrongTemporaryPassword() {
    const uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lowercase = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    const symbols = '!@#\$%^&*()-_=+';
    const allCharacters = uppercase + lowercase + digits + symbols;
    final random = math.Random.secure();

    final characters = <String>[
      uppercase[random.nextInt(uppercase.length)],
      lowercase[random.nextInt(lowercase.length)],
      digits[random.nextInt(digits.length)],
      symbols[random.nextInt(symbols.length)],
    ];
    while (characters.length < 20) {
      characters.add(allCharacters[random.nextInt(allCharacters.length)]);
    }
    characters.shuffle(random);
    return characters.join();
  }

  // ============================================================
  // SA ID VALIDATION
  // ============================================================
  String? _validateSaId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the patient\'s SA ID number';
    }

    final id = value.trim();
    if (id.length != 13) {
      return 'SA ID must be exactly 13 digits';
    }

    if (!RegExp(r'^[0-9]{13}$').hasMatch(id)) {
      return 'SA ID must contain only numbers';
    }

    int sum = 0;
    bool alternate = false;
    for (int i = id.length - 1; i >= 0; i--) {
      int n = int.parse(id[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    if (sum % 10 != 0) {
      return 'Invalid SA ID number (checksum failed)';
    }

    final yy = int.parse(id.substring(0, 2));
    final mm = int.parse(id.substring(2, 4));
    final dd = int.parse(id.substring(4, 6));
    if (mm < 1 || mm > 12) return 'Invalid month in SA ID';
    if (dd < 1 || dd > 31) return 'Invalid day in SA ID';

    final now = DateTime.now();
    final currentYear2 = now.year % 100;
    final birthYear = yy <= currentYear2 ? 2000 + yy : 1900 + yy;
    final birthDate = DateTime(birthYear, mm, dd);
    final age = now.year -
        birthDate.year -
        ((now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day))
            ? 1
            : 0);

    if (age < 0 || age > 150) {
      return 'Invalid birth date in SA ID';
    }

    return null;
  }

  int? _extractAgeFromSaId(String id) {
    if (id.length != 13) return null;
    try {
      final yy = int.parse(id.substring(0, 2));
      final mm = int.parse(id.substring(2, 4));
      final dd = int.parse(id.substring(4, 6));
      final now = DateTime.now();
      final currentYear2 = now.year % 100;
      final birthYear = yy <= currentYear2 ? 2000 + yy : 1900 + yy;
      final birthDate = DateTime(birthYear, mm, dd);
      return now.year -
          birthDate.year -
          ((now.month < birthDate.month ||
                  (now.month == birthDate.month && now.day < birthDate.day))
              ? 1
              : 0);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // SAVE PATIENT
  // ============================================================
  Future<void> _savePatient() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedIcd10Code == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a medical condition (ICD-10)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSaving = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chwId = authProvider.user?.uid;

      if (chwId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      try {
        final tempPassword = _generateStrongTemporaryPassword();
        final patientApp = await Firebase.initializeApp(
          name: 'patient-invite-${DateTime.now().microsecondsSinceEpoch}',
          options: DefaultFirebaseOptions.currentPlatform,
        );
        late final String patientUid;
        try {
          final patientAuth = FirebaseAuth.instanceFor(app: patientApp);
          final userCredential =
              await patientAuth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: tempPassword,
          );
          patientUid = userCredential.user!.uid;
        } finally {
          await patientApp.delete();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(patientUid)
            .set({
          'uid': patientUid,
          'role': 'patient',
          'displayName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'saIdNumber': _saIdController.text.trim(),
        });

        final newPatient = Patient(
          id: patientUid,
          name: _nameController.text.trim(),
          age: int.parse(_ageController.text.trim()),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          condition: _selectedIcd10Name ?? '',
          icd10Code: _selectedIcd10Code,
          saIdNumber: _saIdController.text.trim(),
          status: _selectedStatus,
          notes: _notesController.text.trim(),
          assignedChwId: chwId,
          createdAt: DateTime.now(),
        );

        final firestoreService = FirestoreService();
        await firestoreService.addPatient(newPatient);

        await Future.delayed(const Duration(seconds: 3));
        await FirebaseAuth.instance
            .sendPasswordResetEmail(email: _emailController.text.trim());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient created successfully! Login email sent.'),
              backgroundColor: Colors.green,
            ),
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
    _saIdController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for full-height sheet
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      // Transparent so blurred content behind is visible
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ----- BLURRED BACKDROP -----
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),

          // ----- FULL-SCREEN SHEET FROM BOTTOM -----
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: screenHeight * 0.95, // 95% of screen height
              width: double.infinity, // Full width — no side bezels
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // ----- DRAG HANDLE + HEADER (sticky, doesn't scroll) -----
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Title + close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Add New Patient',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ----- SCROLLABLE FORM CONTENT -----
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ----- FULL NAME -----
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // ----- SA ID NUMBER -----
                            TextFormField(
                              controller: _saIdController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(13),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'SA ID Number',
                                hintText: '13-digit South African ID',
                                prefixIcon: Icon(Icons.badge),
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateSaId,
                              onChanged: (value) {
                                if (value.length == 13) {
                                  final age = _extractAgeFromSaId(value);
                                  if (age != null) {
                                    _ageController.text = age.toString();
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // ----- AGE -----
                            TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Age',
                                helperText:
                                    'Auto-filled from SA ID (can be edited)',
                                prefixIcon: Icon(Icons.cake),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter an age';
                                }
                                final age = int.tryParse(value.trim());
                                if (age == null || age < 0 || age > 150) {
                                  return 'Please enter a valid age (0-150)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // ----- PHONE -----
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                final phoneRegex = RegExp(r'^[0-9+\- ]+$');
                                if (!phoneRegex.hasMatch(value.trim())) {
                                  return 'Please enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // ----- EMAIL -----
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Patient Email (For Login)',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a patient email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // ----- ADDRESS -----
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Address',
                                prefixIcon: Icon(Icons.home),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ----- ICD-10 PICKER -----
                            const Text(
                              'Medical Condition (ICD-10)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Icd10Picker(
                              initialCode: _selectedIcd10Code,
                              onChanged: (code, name) {
                                setState(() {
                                  _selectedIcd10Code = code;
                                  _selectedIcd10Name = name;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // ----- STATUS -----
                            DropdownButtonFormField<String>(
                              initialValue: _selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                prefixIcon: Icon(Icons.health_and_safety),
                                border: OutlineInputBorder(),
                              ),
                              items: _statusOptions.map((status) {
                                return DropdownMenuItem(
                                    value: status, child: Text(status));
                              }).toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedStatus = value!),
                            ),
                            const SizedBox(height: 12),

                            // ----- NOTES -----
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

                            // ----- ACTION BUTTONS -----
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade200,
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
