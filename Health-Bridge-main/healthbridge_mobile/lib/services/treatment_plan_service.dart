import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/treatment_plan.dart';

class TreatmentPlanService {
  Map<String, dynamic> _plans = {};
  bool _loaded = false;

  /// Load the JSON asset once, then cache the result.
  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/treatment_plans.json');
    final data = json.decode(raw);
    _plans = Map<String, dynamic>.from(data['plans'] ?? {});
    _loaded = true;
  }

  /// Look up a treatment plan for a given ICD-10 code.
  /// Returns null if no plan exists for that code.
  Future<TreatmentPlan?> getPlanFor(String? icd10Code) async {
    if (icd10Code == null || icd10Code.isEmpty) return null;
    await _ensureLoaded();
    final raw = _plans[icd10Code];
    if (raw == null) return null;
    return TreatmentPlan.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Returns true if a plan exists for the given code.
  Future<bool> hasPlan(String? icd10Code) async {
    if (icd10Code == null || icd10Code.isEmpty) return false;
    await _ensureLoaded();
    return _plans.containsKey(icd10Code);
  }

  /// List all available ICD-10 codes that have treatment plans.
  Future<List<String>> availableCodes() async {
    await _ensureLoaded();
    return _plans.keys.toList();
  }
}