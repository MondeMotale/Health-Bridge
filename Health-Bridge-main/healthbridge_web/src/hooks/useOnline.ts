export const DB_PATHS = {
  // People
  users: 'users',
  patients: 'patients',

  // Clinical
  appointments: 'appointments',
  appointmentRequests: 'appointment_requests',
  referrals: 'referrals',
  reports: 'reports',
  treatmentPlans: 'treatment_plans',

  // Communication
  messages: 'messages',
  calls: 'calls',

  // Emergency
  emergencyAlerts: 'emergencyAlerts',

  // Scheduling
  availability: 'availability',
} as const;