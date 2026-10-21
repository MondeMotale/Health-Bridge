import icd10Departments from '../data/icd10Departments.json';
import icd10Treatments from '../data/icd10Treatments.json';
import icd10 from '../data/icd10.json';

type DeptEntry = { primary: string; referral: string };
type TreatmentEntry = { firstLine: string; treatment: string; referral: string };

// ----------------------------------------------------------------
// Department lookups
// ----------------------------------------------------------------

export function getDepartmentForCode(code: string): DeptEntry | null {
  if (!code) return null;
  const map = (icd10Departments as any).departments as Record<string, DeptEntry>;
  return map[code] || null;
}

export function resolveDepartment(
  conditionCode?: string | null,
  fallbackCondition?: string | null
): { primary: string; referral: string; source: 'code' | 'fallback' } {
  if (conditionCode) {
    const dept = getDepartmentForCode(conditionCode);
    if (dept) return { primary: dept.primary, referral: dept.referral, source: 'code' };
  }
  if (fallbackCondition) {
    const m = String(fallbackCondition).match(/^([A-Z]\d{2}(?:\.\d+)?)/);
    if (m) {
      const dept = getDepartmentForCode(m[1]);
      if (dept) return { primary: dept.primary, referral: dept.referral, source: 'code' };
    }
  }
  return { primary: 'General Practice', referral: 'General Practice', source: 'fallback' };
}

// ----------------------------------------------------------------
// Treatment lookups
// ----------------------------------------------------------------

export function getTreatmentForCode(code: string): TreatmentEntry | null {
  if (!code) return null;
  const map = icd10Treatments as Record<string, TreatmentEntry>;
  return map[code] || null;
}

/**
 * Smart resolver used across the app.
 *
 * Priority:
 *   1. Fields already stored on the object (patient / referral)
 *   2. Direct lookup on conditionCode
 *   3. Extract code from condition string ("I10 — …" → "I10")
 *   4. Match the condition name against icd10.json (exact, then partial)
 *   5. Fall back to the "consult guidelines" message
 */
export function resolveTreatment(
  source: any
): {
  code: string;
  firstLine: string;
  treatment: string;
  referral: string;
  notes: string;
  source: 'stored' | 'code' | 'parsed' | 'name' | 'fallback';
} {
  // 1. Already on the doc?
  if (source?.treatment || source?.treatmentFirstLine) {
    return {
      code: source.conditionCode || '',
      firstLine: source.treatmentFirstLine || '',
      treatment: source.treatment || '',
      referral: source.treatmentReferral || '',
      notes: source.treatmentNotes || '',
      source: 'stored',
    };
  }

  let code = source?.conditionCode || '';
  const conditionText = source?.condition || '';

  // 2/3. Try to extract a code
  if (!code && conditionText) {
    const m = String(conditionText).match(/^([A-Z]\d{2}(?:\.\d+)?)/);
    if (m) code = m[1];
  }

  // 4. Match by name in icd10.json
  let matchedBy: 'code' | 'parsed' | 'name' | 'fallback' = 'fallback';
  if (code) matchedBy = 'code';
  else if (conditionText) {
    const needle = String(conditionText).toLowerCase().trim();
    const codes = (icd10 as any).codes as Array<{ code: string; name: string; category: string }>;
    let match = codes.find((c) => c.name.toLowerCase() === needle);
    if (!match) {
      match = codes.find(
        (c) =>
          needle.includes(c.name.toLowerCase()) ||
          c.name.toLowerCase().includes(needle)
      );
    }
    if (match) {
      code = match.code;
      matchedBy = 'name';
    }
  }

  const entry = code ? getTreatmentForCode(code) : null;

  if (entry) {
    return {
      code,
      firstLine: entry.firstLine,
      treatment: entry.treatment,
      referral: entry.referral,
      notes: '',
      source: matchedBy,
    };
  }

  return {
    code,
    firstLine: '',
    treatment: '',
    referral: '',
    notes: '',
    source: 'fallback',
  };
}

// ----------------------------------------------------------------
// Convenience
// ----------------------------------------------------------------

export function resolveCondition(source: any) {
  const dept = resolveDepartment(source?.conditionCode, source?.condition);
  const treat = resolveTreatment(source);
  return {
    department: dept.primary,
    referralDepartment: dept.referral,
    treatmentFirstLine: treat.firstLine,
    treatment: treat.treatment,
    treatmentReferral: treat.referral,
    conditionCode: treat.code,
    source: dept.source,
  };
}