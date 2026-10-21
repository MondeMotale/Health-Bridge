import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import {
  collection,
  query,
  where,
  onSnapshot,
  orderBy,
  limit,
  doc,
  updateDoc,
  Timestamp,
} from 'firebase/firestore';
import Layout from '../components/Layout';
import { DB_PATHS } from '../lib/dbPaths';

// ---------- Row types ----------
interface PatientRow {
  id: string;
  name?: string;
  status?: string;
  condition?: string;
  address?: string;
  phone?: string;
  age?: number;
  createdAt?: Timestamp | string;
}

interface ActivityRow {
  id: string;
  action: string;
  name: string;
  time: string;
  type: string;
}

export default function Dashboard() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [activeCHWs, setActiveCHWs] = useState(0);
  const [urgentLoading, setUrgentLoading] = useState(true);
  const [activityLoading, setActivityLoading] = useState(true);
  const [urgentError, setUrgentError] = useState('');
  const [activityError, setActivityError] = useState('');

  // Real-time data states
  const [stats, setStats] = useState({
    total: 0,
    critical: 0,
    followUp: 0,
    chwCount: 0,
  });
  const [urgentPatients, setUrgentPatients] = useState<PatientRow[]>([]);
  const [recentActivity, setRecentActivity] = useState<ActivityRow[]>([]);

  // Modal state
  const [selectedPatient, setSelectedPatient] = useState<PatientRow | null>(null);

  // Formatted date for the header — computed directly, no state needed.
  // (Avoids the React lint warning about setState inside useEffect.)
  const currentTime = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });

  // Auth guard
  useEffect(() => {
    const unsubscribeAuth = onAuthStateChanged(auth, (user) => {
      if (!user) {
        router.push('/login');
        return;
      }
      setLoading(false);
    });

    return () => unsubscribeAuth();
  }, [router]);

  // Real-time Firestore listeners
  useEffect(() => {
    if (loading) return;

    // 1. Patients stats
    const unsubPatients = onSnapshot(
      collection(db, DB_PATHS.patients),
      (snapshot) => {
        const total = snapshot.size;
        const critical = snapshot.docs.filter(
          (d) => d.data().status === 'Critical'
        ).length;
        const followUp = snapshot.docs.filter(
          (d) => d.data().status === 'Needs Follow-up'
        ).length;
        setStats((prev) => ({ ...prev, total, critical, followUp }));
      }
    );

    // 2. Active CHWs
    const qCHWs = query(
      collection(db, DB_PATHS.users),
      where('role', 'in', ['chw', ['chw']])
    );
    const unsubCHWs = onSnapshot(qCHWs, (snapshot) => {
      const docs = snapshot.docs.map((d) => d.data());
      const activeCount = docs.filter(
        (d) => (d as { status?: string }).status === 'Active'
      ).length;
      setActiveCHWs(activeCount);
    });

    // 3. Urgent referrals
    const qUrgent = query(
      collection(db, DB_PATHS.patients),
      where('status', 'in', ['Critical', 'Needs Follow-up']),
      orderBy('createdAt', 'desc'),
      limit(10)
    );
    const unsubUrgent = onSnapshot(qUrgent, (snapshot) => {
      const urgent: PatientRow[] = snapshot.docs.map((doc) => {
        const raw = doc.data() as Record<string, unknown>;
        return {
          id: doc.id,
          name: (raw.name as string) ?? undefined,
          status: (raw.status as string) ?? undefined,
          condition: (raw.condition as string) ?? undefined,
          address: (raw.address as string) ?? undefined,
          phone: (raw.phone as string) ?? undefined,
          age: (raw.age as number) ?? undefined,
          createdAt: raw.createdAt as Timestamp | string | undefined,
        };
      });
      setUrgentPatients(urgent);
      setUrgentLoading(false);
      setUrgentError('');
    }, (error) => {
      console.error('Failed to load urgent patients:', error);
      setUrgentLoading(false);
      setUrgentError('Unable to load urgent patients. Check your connection and refresh.');
    });

    // 4. Recent activity
    const qActivity = query(
      collection(db, DB_PATHS.patients),
      orderBy('createdAt', 'desc'),
      limit(5)
    );
    const unsubActivity = onSnapshot(qActivity, (snapshot) => {
      const activities: ActivityRow[] = snapshot.docs.map((doc) => {
        const data = doc.data() as Record<string, unknown>;
        let timeString = 'Just now';

        if (data.createdAt) {
          const dt = data.createdAt as Timestamp | string;
          if (
            typeof dt === 'object' &&
            typeof (dt as Timestamp).toDate === 'function'
          ) {
            timeString = new Date((dt as Timestamp).toDate()).toLocaleString();
          } else if (typeof dt === 'string') {
            timeString = new Date(dt).toLocaleString();
          }
        }

        return {
          id: doc.id,
          action: 'New patient registered',
          name: (data.name as string) || 'Unknown Patient',
          time: timeString,
          type: 'patient',
        };
      });
      setRecentActivity(activities);
      setActivityLoading(false);
      setActivityError('');
    }, (error) => {
      console.error('Failed to load recent activity:', error);
      setActivityLoading(false);
      setActivityError('Unable to load recent activity. Check your connection and refresh.');
    });

    return () => {
      unsubPatients();
      unsubCHWs();
      unsubUrgent();
      unsubActivity();
    };
  }, [loading]);

  // --- HANDLE TAKE ACTION ---
  const handleTakeAction = (patient: PatientRow) => {
    setSelectedPatient(patient);
  };

  const handleMarkAsReviewed = async () => {
    if (!selectedPatient) return;
    try {
      await updateDoc(doc(db, DB_PATHS.patients, selectedPatient.id), {
        status: 'Reviewed',
        reviewedAt: new Date().toISOString(),
      });
      setSelectedPatient(null);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      alert('Failed to update: ' + message);
    }
  };

  const handleViewFullRecord = () => {
    setSelectedPatient(null);
    router.push('/patients');
  };

  if (loading) {
    return (
      <Layout>
        <p role="status" style={{ textAlign: 'center', padding: '50px', color: '#4b5563' }}>
          Checking your account…
        </p>
      </Layout>
    );
  }

  return (
    <Layout>
      <div style={styles.container}>
        {/* Welcome Section */}
        <div style={styles.welcomeSection}>
          <div>
            <h1 style={styles.title}>Welcome back, Admin</h1>
            <p style={styles.subtitle}>Today is {currentTime}.</p>
          </div>
          <div style={styles.dateBadge}>
            <span>📅 {currentTime}</span>
          </div>
        </div>

        {/* Real-time Stats Grid */}
        <div style={styles.statsGrid}>
          {[
            { title: 'Total Patients', value: stats.total, icon: '👥', href: '/patients' },
            { title: 'Critical Cases', value: stats.critical, icon: '🚨', href: '/patients' },
            { title: 'Needs Follow-up', value: stats.followUp, icon: '📋', href: '/patients' },
            { title: 'Active CHWs', value: activeCHWs, icon: '👩‍⚕️', href: '/hbc' },
          ].map((stat, index) => (
            <div
              key={index}
              style={styles.statCard}
              onClick={() => router.push(stat.href)}
            >
              <div style={styles.statHeader}>
                <span style={styles.statIcon}>{stat.icon}</span>
              </div>
              <p style={styles.statValue}>{stat.value}</p>
              <p style={styles.statTitle}>{stat.title}</p>
            </div>
          ))}
        </div>

        {/* Two Column Layout */}
        <div style={styles.twoColumn}>
          {(urgentError || activityError) && (
            <p role="alert" style={styles.listError}>
              {urgentError || activityError} <button type="button" onClick={() => router.reload()} style={styles.retryButton}>Refresh dashboard</button>
            </p>
          )}
          {/* Urgent Referrals Column */}
          <div style={styles.column}>
            <div style={styles.card}>
              <div style={styles.cardHeader}>
                <h3 style={styles.cardTitle}>
                  Urgent Referrals Needing Action
                </h3>
              </div>
              <p style={styles.cardSubtitle}>
                Real-time critical and high-priority patients
              </p>
              <div style={styles.referralsList} role="list" aria-label="Urgent patients" aria-busy={urgentLoading}>
                {urgentLoading ? (
                  <p role="status" style={{ color: '#4b5563' }}>Loading urgent patients…</p>
                ) : urgentError ? (
                  <p style={{ color: '#4b5563' }}>Urgent patients are unavailable.</p>
                ) : urgentPatients.length === 0 ? (
                  <p style={{ color: '#4b5563' }}>
                    No urgent patients at this moment.
                  </p>
                ) : (
                  urgentPatients.map((patient) => (
                    <div key={patient.id} style={styles.referralItem} role="listitem">
                      <div style={styles.referralHeader}>
                        <div style={styles.referralInfo}>
                          <span
                            style={{
                              ...styles.urgencyBadge,
                              backgroundColor:
                                patient.status === 'Critical'
                                  ? '#fee2e2'
                                  : '#e0f2fe',
                              color:
                                patient.status === 'Critical'
                                  ? '#991b1b'
                                  : '#0369a1',
                            }}
                          >
                            {patient.status}
                          </span>
                          <span style={styles.referralTime}>
                            {patient.createdAt
                              ? new Date(
                                  (patient.createdAt as Timestamp).toDate
                                    ? (patient.createdAt as Timestamp).toDate()
                                    : (patient.createdAt as string)
                                ).toLocaleString()
                              : 'Recently'}
                          </span>
                        </div>
                      </div>
                      <h4 style={styles.referralName}>{patient.name}</h4>
                      <p style={styles.referralCondition}>
                        {patient.condition}
                      </p>
                      <p style={styles.referralLocation}>
                        📍 {patient.address || 'Address not listed'}
                      </p>
                      <button
                        style={styles.primaryButton}
                        onClick={() => handleTakeAction(patient)}
                      >
                        Take Action →
                      </button>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>

          {/* Recent Activity Column */}
          <div style={styles.column}>
            <div style={styles.card}>
              <div style={styles.cardHeader}>
                <h3 style={styles.cardTitle}>
                  Recent Patient Registrations
                </h3>
              </div>
              <div style={styles.activityList} role="list" aria-label="Recent patient registrations" aria-busy={activityLoading}>
                {activityLoading ? (
                  <p role="status" style={{ color: '#4b5563' }}>Loading recent activity…</p>
                ) : activityError ? (
                  <p style={{ color: '#4b5563' }}>Recent activity is unavailable.</p>
                ) : recentActivity.length === 0 ? (
                  <p style={{ color: '#4b5563' }}>No recent activity.</p>
                ) : (
                  recentActivity.map((activity) => (
                    <div key={activity.id} style={styles.activityItem} role="listitem">
                      <div style={styles.activityIcon}>👤</div>
                      <div style={styles.activityContent}>
                        <p style={styles.activityAction}>
                          {activity.action}
                        </p>
                        <p style={styles.activityName}>{activity.name}</p>
                        <p style={styles.activityTime}>{activity.time}</p>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* --- PATIENT ACTION MODAL --- */}
      {selectedPatient && (
        <div
          style={styles.modalOverlay}
          onClick={() => setSelectedPatient(null)}
        >
          <div
            style={styles.modalContent}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={styles.modalHeader}>
              <h2 style={styles.modalTitle}>
                {selectedPatient.name || 'Patient'}
              </h2>
              <button
                onClick={() => setSelectedPatient(null)}
                style={styles.closeButton}
              >
                ×
              </button>
            </div>

            <div style={styles.modalBody}>
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Status:</span>
                <span
                  style={{
                    ...styles.urgencyBadge,
                    backgroundColor:
                      selectedPatient.status === 'Critical'
                        ? '#fee2e2'
                        : '#e0f2fe',
                    color:
                      selectedPatient.status === 'Critical'
                        ? '#991b1b'
                        : '#0369a1',
                  }}
                >
                  {selectedPatient.status}
                </span>
              </div>
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Condition:</span>
                <span style={styles.modalValue}>
                  {selectedPatient.condition || 'N/A'}
                </span>
              </div>
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Address:</span>
                <span style={styles.modalValue}>
                  {selectedPatient.address || 'N/A'}
                </span>
              </div>
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Phone:</span>
                <span style={styles.modalValue}>
                  {selectedPatient.phone || 'N/A'}
                </span>
              </div>
              {selectedPatient.age && (
                <div style={styles.modalRow}>
                  <span style={styles.modalLabel}>Age:</span>
                  <span style={styles.modalValue}>
                    {selectedPatient.age} yrs
                  </span>
                </div>
              )}
            </div>

            <div style={styles.modalFooter}>
              <button
                style={styles.modalSecondaryBtn}
                onClick={handleViewFullRecord}
              >
                View Full Record →
              </button>
              <button
                style={styles.modalPrimaryBtn}
                onClick={handleMarkAsReviewed}
              >
                ✓ Mark as Reviewed
              </button>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
}

const styles = {
  container: {
    display: 'flex',
    flexDirection: 'column' as const,
    padding: '24px',
    backgroundColor: '#f9fafb',
    fontFamily: "'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
  },
  welcomeSection: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '28px',
  },
  title: {
    fontSize: '26px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  subtitle: {
    color: '#666',
    marginTop: '8px',
    marginBottom: 0,
    fontSize: '14px',
  },
  dateBadge: {
    padding: '8px 14px',
    backgroundColor: 'white',
    borderRadius: '10px',
    fontSize: '13px',
    color: '#2563eb',
    fontWeight: '500' as const,
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(4, 1fr)',
    gap: '20px',
    marginBottom: '28px',
  },
  statCard: {
    backgroundColor: 'white',
    padding: '20px',
    borderRadius: '14px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    transition: 'all 0.2s ease',
    cursor: 'pointer',
  },
  statHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '14px',
  },
  statIcon: { fontSize: '32px' },
  statValue: {
    fontSize: '34px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  statTitle: { fontSize: '14px', color: '#666', margin: '8px 0 0' },
  twoColumn: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '24px',
  },
  column: { display: 'flex', flexDirection: 'column' as const },
  card: {
    backgroundColor: 'white',
    borderRadius: '14px',
    padding: '20px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
  },
  cardHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '8px',
  },
  cardTitle: {
    fontSize: '18px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  cardSubtitle: { fontSize: '13px', color: '#888', margin: '0 0 16px 0' },
  listError: {
    gridColumn: '1 / -1',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    flexWrap: 'wrap' as const,
    gap: '12px',
    color: '#991b1b',
    backgroundColor: '#fee2e2',
    border: '1px solid #fecaca',
    borderRadius: '8px',
    padding: '12px 16px',
    margin: 0,
  },
  retryButton: {
    minHeight: '44px',
    padding: '8px 14px',
    border: 0,
    borderRadius: '6px',
    backgroundColor: '#991b1b',
    color: 'white',
    cursor: 'pointer',
    fontWeight: '600' as const,
  },
  referralsList: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '14px',
  },
  referralItem: {
    padding: '16px',
    border: '1px solid #e5e7eb',
    borderRadius: '12px',
    transition: 'all 0.2s ease',
    cursor: 'pointer',
  },
  referralHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '10px',
  },
  referralInfo: { display: 'flex', gap: '10px', alignItems: 'center' },
  urgencyBadge: {
    padding: '3px 10px',
    borderRadius: '20px',
    fontSize: '11px',
    fontWeight: '600' as const,
  },
  referralTime: { fontSize: '11px', color: '#888' },
  referralName: {
    fontSize: '16px',
    fontWeight: '600' as const,
    margin: '0 0 6px 0',
    color: '#1a1a2e',
  },
  referralCondition: { fontSize: '13px', color: '#666', margin: '0 0 4px' },
  referralLocation: { fontSize: '12px', color: '#888', margin: '0 0 14px' },
  primaryButton: {
    backgroundColor: '#2563eb',
    color: 'white',
    padding: '8px 16px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: '500' as const,
    transition: 'background-color 0.2s',
  },
  activityList: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '16px',
  },
  activityItem: {
    display: 'flex',
    gap: '14px',
    padding: '10px 0',
    borderBottom: '1px solid #f0f0f0',
  },
  activityIcon: { fontSize: '28px' },
  activityContent: { flex: 1 },
  activityAction: {
    fontSize: '14px',
    fontWeight: '500' as const,
    margin: 0,
    color: '#333',
  },
  activityName: { fontSize: '13px', color: '#666', margin: '4px 0 0' },
  activityTime: { fontSize: '11px', color: '#999', margin: '4px 0 0' },
  modalOverlay: {
    position: 'fixed' as const,
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.5)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000,
  },
  modalContent: {
    backgroundColor: 'white',
    padding: '24px',
    borderRadius: '16px',
    maxWidth: '500px',
    width: '90%',
    boxShadow: '0 10px 30px rgba(0,0,0,0.2)',
  },
  modalHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '20px',
  },
  modalTitle: {
    fontSize: '22px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  closeButton: {
    background: 'none',
    border: 'none',
    fontSize: '28px',
    cursor: 'pointer',
    color: '#888',
  },
  modalBody: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '14px',
    marginBottom: '24px',
  },
  modalRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  modalLabel: {
    color: '#6B7280',
    fontWeight: '500' as const,
    fontSize: '14px',
  },
  modalValue: {
    color: '#1A1A2E',
    fontWeight: '500' as const,
    fontSize: '14px',
  },
  modalFooter: { display: 'flex', gap: '12px' },
  modalSecondaryBtn: {
    flex: 1,
    backgroundColor: '#f3f4f6',
    color: '#374151',
    padding: '12px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontWeight: '500' as const,
    fontSize: '14px',
  },
  modalPrimaryBtn: {
    flex: 1,
    backgroundColor: '#10b981',
    color: 'white',
    padding: '12px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontWeight: '500' as const,
    fontSize: '14px',
  },
};