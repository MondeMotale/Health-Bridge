/// Dart model for a treatment plan, matching assets/treatment_plans.json.
class TreatmentPlan {
  final String icd10Code;
  final String conditionName;
  final String overview;
  final bool isChronic;
  final int durationWeeks;
  final String? treatmentDurationText;

  // Optional content (only some conditions have these)
  final List<SeverityLevel>? severityLevels;
  final String? targetBP;
  final List<GlycaemicTarget>? glycaemicTargets;
  final Map<String, String>? nonGlycaemicTargets;
  final List<String>? phases;
  final List<Medication> medications;
  final List<String> lifestyleAdvice;
  final Map<String, List<String>>? monitoring;
  final String followUpSchedule;
  final List<String> warningSigns;
  final List<String> referralCriteria;
  final EmergencyProtocol? emergencyProtocol;
  final List<SpecialCase>? specialCases;
  final Map<String, String>? portionGuide;
  final String source;

  TreatmentPlan({
    required this.icd10Code,
    required this.conditionName,
    required this.overview,
    required this.isChronic,
    required this.durationWeeks,
    this.treatmentDurationText,
    this.severityLevels,
    this.targetBP,
    this.glycaemicTargets,
    this.nonGlycaemicTargets,
    this.phases,
    required this.medications,
    required this.lifestyleAdvice,
    this.monitoring,
    required this.followUpSchedule,
    required this.warningSigns,
    required this.referralCriteria,
    this.emergencyProtocol,
    this.specialCases,
    this.portionGuide,
    required this.source,
  });

  factory TreatmentPlan.fromMap(Map<String, dynamic> map) {
    return TreatmentPlan(
      icd10Code: map['icd10Code'] ?? '',
      conditionName: map['conditionName'] ?? '',
      overview: map['overview'] ?? '',
      isChronic: map['isChronic'] ?? false,
      durationWeeks: map['durationWeeks'] ?? 0,
      treatmentDurationText: map['treatmentDurationText'],
      severityLevels: (map['severityLevels'] as List?)
          ?.map((e) => SeverityLevel.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      targetBP: map['targetBP'],
      glycaemicTargets: (map['glycaemicTargets'] as List?)
          ?.map((e) => GlycaemicTarget.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      nonGlycaemicTargets: map['nonGlycaemicTargets'] != null
          ? Map<String, String>.from(map['nonGlycaemicTargets'])
          : null,
      phases: (map['phases'] as List?)?.map((e) => e.toString()).toList(),
      medications: (map['medications'] as List? ?? [])
          .map((e) => Medication.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      lifestyleAdvice: (map['lifestyleAdvice'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      monitoring: map['monitoring'] != null
          ? (map['monitoring'] as Map).map(
              (k, v) => MapEntry(
                k.toString(),
                (v as List).map((e) => e.toString()).toList(),
              ),
            )
          : null,
      followUpSchedule: map['followUpSchedule'] ?? '',
      warningSigns: (map['warningSigns'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      referralCriteria: (map['referralCriteria'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      emergencyProtocol: map['emergencyProtocol'] != null
          ? EmergencyProtocol.fromMap(
              Map<String, dynamic>.from(map['emergencyProtocol']))
          : null,
      specialCases: (map['specialCases'] as List?)
          ?.map((e) => SpecialCase.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      portionGuide: map['portionGuide'] != null
          ? Map<String, String>.from(map['portionGuide'])
          : null,
      source: map['source'] ?? '',
    );
  }
}

class Medication {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String? phase;
  final String notes;
  final bool isClinical;
  final List<WeightBand>? weightBands;

  Medication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.phase,
    required this.notes,
    this.isClinical = false,
    this.weightBands,
  });

  factory Medication.fromMap(Map<String, dynamic> m) => Medication(
        name: m['name'] ?? '',
        dosage: m['dosage'] ?? '',
        frequency: m['frequency'] ?? '',
        duration: m['duration'] ?? '',
        phase: m['phase'],
        notes: m['notes'] ?? '',
        isClinical: m['isClinical'] ?? false,
        weightBands: (m['weightBands'] as List?)
            ?.map((e) => WeightBand.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// A single weight-band dose for a medication (used for paediatric / TB dosing).
class WeightBand {
  final String weight; // e.g. "30–37 kg"
  final String dose; // e.g. "2 tablets"

  WeightBand({required this.weight, required this.dose});

  factory WeightBand.fromMap(Map<String, dynamic> m) => WeightBand(
        weight: m['weight'] ?? '',
        dose: m['dose'] ?? '',
      );
}

class SeverityLevel {
  final String level;
  final String systolic;
  final String diastolic;

  SeverityLevel({
    required this.level,
    required this.systolic,
    required this.diastolic,
  });

  factory SeverityLevel.fromMap(Map<String, dynamic> m) => SeverityLevel(
        level: m['level'] ?? '',
        systolic: m['systolic'] ?? '',
        diastolic: m['diastolic'] ?? '',
      );
}

class GlycaemicTarget {
  final String patientType;
  final String hba1c;
  final String fbg;
  final String ppg;

  GlycaemicTarget({
    required this.patientType,
    required this.hba1c,
    required this.fbg,
    required this.ppg,
  });

  factory GlycaemicTarget.fromMap(Map<String, dynamic> m) => GlycaemicTarget(
        patientType: m['patientType'] ?? '',
        hba1c: m['hba1c'] ?? '',
        fbg: m['fbg'] ?? '',
        ppg: m['ppg'] ?? '',
      );
}

class EmergencyProtocol {
  final String trigger;
  final String? immediateAction;
  final String? outcome;
  final List<Map<String, String>>? classification;
  final Map<String, String>? hypoglycaemiaTreatment;

  EmergencyProtocol({
    required this.trigger,
    this.immediateAction,
    this.outcome,
    this.classification,
    this.hypoglycaemiaTreatment,
  });

  factory EmergencyProtocol.fromMap(Map<String, dynamic> m) {
    return EmergencyProtocol(
      trigger: m['trigger'] ?? '',
      immediateAction: m['immediateAction'],
      outcome: m['outcome'],
      classification: (m['classification'] as List?)
          ?.map((e) => Map<String, String>.from(e))
          .toList(),
      hypoglycaemiaTreatment: m['hypoglycaemiaTreatment'] != null
          ? Map<String, String>.from(m['hypoglycaemiaTreatment'])
          : null,
    );
  }
}

class SpecialCase {
  final String case_;
  final String note;

  SpecialCase({required this.case_, required this.note});

  factory SpecialCase.fromMap(Map<String, dynamic> m) => SpecialCase(
        case_: m['case'] ?? '',
        note: m['note'] ?? '',
      );
}