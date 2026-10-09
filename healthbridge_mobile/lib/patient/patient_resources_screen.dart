import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../models/patient.dart';
import '../../models/treatment_plan.dart';
import '../../services/firestore_service.dart';
import '../../services/treatment_plan_service.dart';

class PatientResourcesScreen extends StatefulWidget {
  const PatientResourcesScreen({super.key});

  @override
  State<PatientResourcesScreen> createState() => _PatientResourcesScreenState();
}

class _PatientResourcesScreenState extends State<PatientResourcesScreen> {
  final TreatmentPlanService _planService = TreatmentPlanService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? uid = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Treatment Plan'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text('Not logged in'))
          : FutureBuilder<Patient?>(
              future: FirestoreService().getPatientProfile(uid),
              builder: (context, patientSnap) {
                if (patientSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final patient = patientSnap.data;
                if (patient == null) {
                  return _emptyState('No patient profile found.');
                }

                return FutureBuilder<TreatmentPlan?>(
                  future: _planService.getPlanFor(patient.icd10Code),
                  builder: (context, planSnap) {
                    if (planSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final plan = planSnap.data;
                    if (plan == null) {
                      return _emptyState(
                        patient.icd10Code == null
                            ? 'No treatment plan has been assigned yet.\nYour CHW will set your condition.'
                            : 'No treatment plan available for ${patient.icd10Code} yet.',
                      );
                    }

                    return _buildPlanView(plan, patient);
                  },
                );
              },
            ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_information_outlined,
                size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanView(TreatmentPlan plan, Patient patient) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(plan),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.warningSigns.isNotEmpty) ...[
                  _buildWarningBox(plan.warningSigns),
                  const SizedBox(height: 20),
                ],
                _buildSection('About your condition', [
                  Text(plan.overview, style: _bodyStyle),
                ]),
                const SizedBox(height: 20),

                if (plan.phases != null && plan.phases!.isNotEmpty) ...[
                  _buildSection(
                    '📋 Treatment Steps',
                    plan.phases!.map((p) => _buildBullet(p)).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (plan.medications.isNotEmpty) ...[
                  _buildSection(
                    '💊 Your Medications',
                    plan.medications
                        .where((m) => !m.isClinical)
                        .map((m) => _buildMedicationCard(m))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Inhaler technique (asthma / COPD)
                if (plan.inhalerTechnique != null) ...[
                  _buildInhalerTechniqueSection(plan.inhalerTechnique!),
                  const SizedBox(height: 20),
                ],

                if (plan.lifestyleAdvice.isNotEmpty) ...[
                  _buildSection(
                    '🥗 Lifestyle Recommendations',
                    plan.lifestyleAdvice.map(_buildBullet).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (plan.portionGuide != null) ...[
                  _buildSection(
                    '🍽️ Portion Guide',
                    plan.portionGuide!.entries
                        .map((e) => _buildKeyValue(e.key, e.value))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (plan.followUpSchedule.isNotEmpty) ...[
                  _buildSection(
                    '📅 Follow-up Schedule',
                    [Text(plan.followUpSchedule, style: _bodyStyle)],
                  ),
                  const SizedBox(height: 20),
                ],

                if (plan.treatmentDurationText != null) ...[
                  _buildSection('⏱️ Treatment Duration', [
                    Text(plan.treatmentDurationText!, style: _bodyStyle),
                  ]),
                  const SizedBox(height: 20),
                ],

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Source: ${plan.source}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Inhaler technique section ----------
  Widget _buildInhalerTechniqueSection(InhalerTechnique tech) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🌬️ Inhaler Technique',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Getting the technique right is essential — most treatment failures are due to poor technique.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),

        if (tech.mdi != null)
          _buildTechniqueCard(
            title: 'Using an Inhaler (MDI)',
            icon: Icons.air,
            color: const Color(0xFF1E3A8A),
            body: tech.mdi!,
          ),

        if (tech.spacer != null) ...[
          const SizedBox(height: 10),
          _buildTechniqueCard(
            title: 'Using a Spacer',
            icon: Icons.blur_circular,
            color: const Color(0xFF10B981),
            body: tech.spacer!,
          ),
        ],

        if (tech.nebulizer != null) ...[
          const SizedBox(height: 10),
          _buildTechniqueCard(
            title: 'Using a Nebulizer',
            icon: Icons.cloud,
            color: const Color(0xFF3B82F6),
            body: tech.nebulizer!,
          ),
        ],

        if (tech.generalTips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.lightbulb_outline,
                        color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Important Tips',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...tech.generalTips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A2E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTechniqueCard({
    required String title,
    required IconData icon,
    required Color color,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A1A2E),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TreatmentPlan plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF1E3A8A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Diagnosis',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            plan.conditionName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  plan.icd10Code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                plan.isChronic ? 'Chronic — ongoing care' : 'Short-term',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox(List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'When to get help immediately',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: Colors.red, fontSize: 14)),
                    Expanded(
                      child: Text(
                        w,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1A1A2E)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildMedicationCard(Medication m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${m.dosage} · ${m.frequency}',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),

          if (m.weightBands != null && m.weightBands!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Your weight',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Your dose',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...m.weightBands!.map(
                    (band) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: const Color(0xFF1E3A8A)
                                .withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              band.weight,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF1A1A2E)),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              band.dose,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (m.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(m.notes,
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
          ],
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: _bodyStyle)),
        ],
      ),
    );
  }

  Widget _buildKeyValue(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          Expanded(child: Text(value, style: _bodyStyle)),
        ],
      ),
    );
  }

  TextStyle get _bodyStyle => const TextStyle(
        fontSize: 14,
        color: Color(0xFF1A1A2E),
        height: 1.4,
      );
}