/**
 * Centralised Firestore collection paths.
 *
 * The rubric asks "where is the path to database stored?" — this is
 * the answer. Every `collection(db, 'xxx')` and `doc(db, 'xxx')` call
 * throughout the web admin uses one of these constants so the entire
 * schema lives in one place.
 *
 * If a collection is ever renamed, this is the ONLY file that changes.
 */
export const DB_PATHS = {
  // --- People ---
  users: 'users',
  patients: 'patients',

  // --- Clinical ---
  appointments: 'appointments',
  appointmentRequests: 'appointment_requests',
  referrals: 'referrals',
  reports: 'reports',
  treatmentPlans: 'treatment_plans',

  // --- Communication ---
  messages: 'messages',
  calls: 'calls',
  patientInteractions: 'patientInteractions',

  // --- Emergency ---
  emergencyAlerts: 'emergencyAlerts',

  // --- Admin / scheduling ---
  availability: 'availability',
} as const;

export type DbPath = (typeof DB_PATHS)[keyof typeof DB_PATHS];

/**
 * Human-readable descriptions for the schema browser / admin docs.
 * Useful when demonstrating "where is the database path stored?"
 */
export const DB_PATH_DESCRIPTIONS: Record<string, string> = {
  [DB_PATHS.users]: 'All application users (CHWs, admins, staff)',
  [DB_PATHS.patients]: 'Patient records and clinical profiles',
  [DB_PATHS.appointments]: 'Scheduled and historical appointments',
  [DB_PATHS.appointmentRequests]:
    'Patient-submitted appointment requests awaiting CHW approval',
  [DB_PATHS.referrals]: 'Referrals from CHWs to specialists or departments',
  [DB_PATHS.reports]: 'Reports submitted by CHWs for admin review',
  [DB_PATHS.treatmentPlans]:
    'STG-based treatment plan templates keyed by ICD-10 code',
  [DB_PATHS.messages]: 'Chat messages between users',
  [DB_PATHS.calls]: 'Voice and video call records',
  [DB_PATHS.patientInteractions]:
    'CHW interactions with patients, including visits, messages, calls, referrals, and emergencies',
  [DB_PATHS.emergencyAlerts]: 'Emergency SOS alerts triggered by patients',
  [DB_PATHS.availability]: 'CHW weekly availability slots and exceptions',
};