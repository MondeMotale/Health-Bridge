import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import { collection, query, orderBy, onSnapshot } from 'firebase/firestore';
import Layout from '../components/Layout';

export default function Analytics() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);

  // Raw collections
  const [patients, setPatients] = useState<any[]>([]);
  const [appointments, setAppointments] = useState<any[]>([]);
  const [referrals, setReferrals] = useState<any[]>([]);
  const [chws, setChws] = useState<any[]>([]);

  // Computed stats
  const [stats, setStats] = useState({
    totalPatients: 0,
    appointments: 0,
    criticalCases: 0,
    followUps: 0,
    activeCHWs: 0,
    totalReferrals: 0,
    completedReferrals: 0,
    pendingReferrals: 0,
  });

  // 1. Auth guard
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (user) => {
      if (!user) {
        router.push('/login');
        return;
      }
      setLoading(false);
    });
    return () => unsub();
  }, [router]);

  // 2. Real-time listeners
  useEffect(() => {
    if (loading) return;

    // Patients
    const unsubPatients = onSnapshot(
      query(collection(db, 'patients'), orderBy('createdAt', 'desc')),
      (snapshot) => {
        const data = snapshot.docs.map((doc) => {
          const raw = doc.data();
          let dateStr = 'N/A';
          if (raw.createdAt) {
            if (typeof raw.createdAt.toDate === 'function') {
              dateStr = raw.createdAt.toDate().toLocaleDateString();
            } else if (typeof raw.createdAt === 'string') {
              dateStr = new Date(raw.createdAt).toLocaleDateString();
            }
          }
          return {
            id: doc.id,
            ...raw,
            _createdDate: dateStr,
            _createdMs:
              raw.createdAt?.toDate?.()?.getTime?.() ||
              (typeof raw.createdAt === 'string' ? new Date(raw.createdAt).getTime() : 0) ||
              0,
          };
        });
        setPatients(data);
      }
    );

    // Appointments
    const unsubAppointments = onSnapshot(
      collection(db, 'appointments'),
      (snapshot) => {
        setAppointments(snapshot.docs.map((d) => ({ id: d.id, ...d.data() })));
      }
    );

    // Referrals
    const unsubReferrals = onSnapshot(
      collection(db, 'referrals'),
      (snapshot) => {
        setReferrals(snapshot.docs.map((d) => ({ id: d.id, ...d.data() })));
      }
    );

    // CHWs
    const unsubChws = onSnapshot(
      collection(db, 'users'),
      (snapshot) => {
        const all = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
        const chwOnly = all.filter((u: any) => {
          const role = u.role;
          return typeof role === 'string'
            ? role === 'chw'
            : Array.isArray(role)
            ? role.includes('chw')
            : false;
        });
        setChws(chwOnly);
      }
    );

    return () => {
      unsubPatients();
      unsubAppointments();
      unsubReferrals();
      unsubChws();
    };
  }, [loading]);

  // 3. Compute stats whenever raw data changes
  useEffect(() => {
    const criticalCases = patients.filter((p) => p.status === 'Critical').length;
    const followUps = patients.filter((p) => p.status === 'Needs Follow-up').length;
    const activeCHWs = chws.filter((c) => c.status === 'Active').length;
    const completedReferrals = referrals.filter((r) => r.status === 'Completed').length;
    const pendingReferrals = referrals.filter((r) => r.status === 'Pending').length;

    setStats({
      totalPatients: patients.length,
      appointments: appointments.length,
      criticalCases,
      followUps,
      activeCHWs,
      totalReferrals: referrals.length,
      completedReferrals,
      pendingReferrals,
    });
  }, [patients, appointments, referrals, chws]);

  // 4. Most active patients — sorted by number of appointments per patient
  const mostActivePatients = (() => {
    const counts: Record<string, { name: string; visits: number; lastVisit: string }> = {};

    // Count appointments per patient name
    appointments.forEach((apt: any) => {
      const key = apt.patient || apt.patientName || 'Unknown';
      if (!counts[key]) counts[key] = { name: key, visits: 0, lastVisit: 'N/A' };
      counts[key].visits += 1;
    });

    // Fallback: if no appointments, use patients with a `visits` field
    if (Object.keys(counts).length === 0) {
      patients.forEach((p) => {
        if (p.visits) {
          counts[p.name] = {
            name: p.name,
            visits: Number(p.visits),
            lastVisit: p._createdDate || 'N/A',
          };
        }
      });
    }

    return Object.values(counts)
      .sort((a, b) => b.visits - a.visits)
      .slice(0, 5);
  })();

  // 5. Patients registered in the last 7 days
  const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
  const recentRegistrations = patients.filter((p) => p._createdMs >= sevenDaysAgo).length;

  // 6. Referral completion rate
  const completionRate =
    stats.totalReferrals > 0
      ? Math.round((stats.completedReferrals / stats.totalReferrals) * 100)
      : 0;

  // 7. Critical case percentage
  const criticalRate =
    stats.totalPatients > 0
      ? Math.round((stats.criticalCases / stats.totalPatients) * 100)
      : 0;

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: '50px', color: '#666' }}>
        Loading analytics...
      </div>
    );
  }

  const statCards = [
    {
      label: 'Total Patients',
      value: stats.totalPatients,
      sub: `${recentRegistrations} new this week`,
      icon: '👥',
      color: '#2563eb',
    },
    {
      label: 'Appointments',
      value: stats.appointments,
      sub: 'All time',
      icon: '📅',
      color: '#10b981',
    },
    {
      label: 'Critical Cases',
      value: stats.criticalCases,
      sub: `${criticalRate}% of total`,
      icon: '🚨',
      color: '#ef4444',
    },
    {
      label: 'Active CHWs',
      value: stats.activeCHWs,
      sub: `${chws.length} total`,
      icon: '👩‍⚕️',
      color: '#8b5cf6',
    },
    {
      label: 'Total Referrals',
      value: stats.totalReferrals,
      sub: `${completionRate}% completed`,
      icon: '📤',
      color: '#f59e0b',
    },
    {
      label: 'Pending Referrals',
      value: stats.pendingReferrals,
      sub: 'Awaiting action',
      icon: '⏳',
      color: '#ef4444',
    },
    {
      label: 'Follow-ups',
      value: stats.followUps,
      sub: 'Needs attention',
      icon: '📋',
      color: '#0ea5e9',
    },
    {
      label: 'Completed Referrals',
      value: stats.completedReferrals,
      sub: `${completionRate}% rate`,
      icon: '✅',
      color: '#10b981',
    },
  ];

  return (
    <Layout>
      <div style={styles.container}>
        {/* Header */}
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Analytics</h1>
            <p style={styles.pageSubtitle}>Live practice statistics — updates in real time</p>
          </div>
          <div style={styles.liveBadge}>
            <span style={styles.liveDot}></span>
            LIVE
          </div>
        </div>

        {/* Stats Grid */}
        <div style={styles.statsGrid}>
          {statCards.map((stat, index) => (
            <div
              key={index}
              style={styles.statCard}
              onMouseEnter={(e) =>
                (e.currentTarget.style.boxShadow = '0 6px 12px rgba(0,0,0,0.15)')
              }
              onMouseLeave={(e) =>
                (e.currentTarget.style.boxShadow = '0 2px 6px rgba(0,0,0,0.1)')
              }
            >
              <div style={styles.statHeader}>
                <div style={{ ...styles.statIconWrap, backgroundColor: `${stat.color}15` }}>
                  <span style={styles.statIcon}>{stat.icon}</span>
                </div>
              </div>
              <p style={{ ...styles.statValue, color: stat.color }}>{stat.value}</p>
              <p style={styles.statLabel}>{stat.label}</p>
              <p style={styles.statSub}>{stat.sub}</p>
            </div>
          ))}
        </div>

        {/* Two-Column Layout */}
        <div style={styles.twoColumn}>
          {/* Most Active Patients */}
          <div style={styles.tableContainer}>
            <h3 style={styles.tableTitle}>Most Active Patients</h3>
            <p style={styles.tableSubtitle}>Based on appointment frequency (live)</p>

            <div style={styles.patientList}>
              {mostActivePatients.length === 0 ? (
                <p style={{ color: '#888', padding: '16px 0' }}>
                  No appointment data yet.
                </p>
              ) : (
                mostActivePatients.map((patient, index) => (
                  <div
                    key={index}
                    style={styles.patientRow}
                    onMouseEnter={(e) =>
                      (e.currentTarget.style.backgroundColor = '#f9fafb')
                    }
                    onMouseLeave={(e) =>
                      (e.currentTarget.style.backgroundColor = 'transparent')
                    }
                  >
                    <div style={styles.patientRank}>
                      <span
                        style={{
                          ...styles.rankNumber,
                          ...(index === 0 ? styles.rankGold : {}),
                          ...(index === 1 ? styles.rankSilver : {}),
                          ...(index === 2 ? styles.rankBronze : {}),
                        }}
                      >
                        {index + 1}
                      </span>
                    </div>
                    <div style={styles.patientInfo}>
                      <p style={styles.patientName}>{patient.name}</p>
                      <p style={styles.patientMeta}>Last visit: {patient.lastVisit}</p>
                    </div>
                    <div style={styles.patientVisits}>
                      <p style={styles.visitsNumber}>{patient.visits}</p>
                      <p style={styles.visitsLabel}>visits</p>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Referral Breakdown */}
          <div style={styles.tableContainer}>
            <h3 style={styles.tableTitle}>Referral Status Breakdown</h3>
            <p style={styles.tableSubtitle}>Live snapshot of the referral pipeline</p>

            {[
              {
                label: 'Completed',
                value: stats.completedReferrals,
                total: stats.totalReferrals,
                color: '#10b981',
              },
              {
                label: 'Pending',
                value: stats.pendingReferrals,
                total: stats.totalReferrals,
                color: '#ef4444',
              },
              {
                label: 'Other / In Progress',
                value:
                  stats.totalReferrals -
                  stats.completedReferrals -
                  stats.pendingReferrals,
                total: stats.totalReferrals,
                color: '#f59e0b',
              },
            ].map((row, i) => {
              const pct =
                row.total > 0 ? Math.round((row.value / row.total) * 100) : 0;
              return (
                <div key={i} style={styles.breakdownRow}>
                  <div style={styles.breakdownHeader}>
                    <span style={styles.breakdownLabel}>{row.label}</span>
                    <span style={styles.breakdownValue}>
                      {row.value}{' '}
                      <span style={styles.breakdownPct}>({pct}%)</span>
                    </span>
                  </div>
                  <div style={styles.progressBar}>
                    <div
                      style={{
                        ...styles.progressFill,
                        width: `${pct}%`,
                        backgroundColor: row.color,
                      }}
                    ></div>
                  </div>
                </div>
              );
            })}

            {/* Summary tiles */}
            <div style={styles.miniStats}>
              <div style={styles.miniStat}>
                <p style={styles.miniStatValue}>{stats.totalPatients}</p>
                <p style={styles.miniStatLabel}>Patients</p>
              </div>
              <div style={styles.miniStat}>
                <p style={styles.miniStatValue}>{stats.appointments}</p>
                <p style={styles.miniStatLabel}>Appointments</p>
              </div>
              <div style={styles.miniStat}>
                <p style={styles.miniStatValue}>{stats.totalReferrals}</p>
                <p style={styles.miniStatLabel}>Referrals</p>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Summary Bar */}
        <div style={styles.summaryBar}>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>{stats.totalPatients}</p>
            <p style={styles.summaryLabel}>Total Patients</p>
          </div>
          <div style={styles.summaryDivider}></div>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>{stats.criticalCases}</p>
            <p style={styles.summaryLabel}>Critical Cases</p>
          </div>
          <div style={styles.summaryDivider}></div>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>{stats.activeCHWs}</p>
            <p style={styles.summaryLabel}>Active CHWs</p>
          </div>
          <div style={styles.summaryDivider}></div>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>{completionRate}%</p>
            <p style={styles.summaryLabel}>Referral Completion</p>
          </div>
          <div style={styles.summaryDivider}></div>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>{recentRegistrations}</p>
            <p style={styles.summaryLabel}>New This Week</p>
          </div>
        </div>
      </div>
    </Layout>
  );
}

const styles = {
  container: {
    padding: '24px',
    backgroundColor: '#f9fafb',
    fontFamily: "'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
    minHeight: '100vh',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '24px',
    flexWrap: 'wrap' as const,
    gap: '12px',
  },
  pageTitle: { fontSize: '28px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  pageSubtitle: { color: '#666', marginTop: '8px', marginBottom: 0, fontSize: '14px' },
  liveBadge: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    padding: '6px 14px',
    backgroundColor: '#d1fae5',
    color: '#065f46',
    borderRadius: '20px',
    fontSize: '12px',
    fontWeight: 'bold' as const,
    letterSpacing: '0.5px',
  },
  liveDot: {
    width: '8px',
    height: '8px',
    borderRadius: '50%',
    backgroundColor: '#10b981',
    display: 'inline-block',
    animation: 'pulse 2s infinite',
  } as React.CSSProperties,
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
    gap: '20px',
    marginBottom: '32px',
  },
  statCard: {
    backgroundColor: 'white',
    padding: '20px',
    borderRadius: '14px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    transition: 'box-shadow 0.2s ease-in-out',
  },
  statHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '14px',
  },
  statIconWrap: {
    width: '44px',
    height: '44px',
    borderRadius: '12px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  statIcon: { fontSize: '22px' },
  statValue: {
    fontSize: '32px',
    fontWeight: 'bold' as const,
    margin: 0,
    lineHeight: 1.1,
  },
  statLabel: {
    fontSize: '14px',
    color: '#333',
    fontWeight: '500' as const,
    margin: '6px 0 0',
  },
  statSub: {
    fontSize: '12px',
    color: '#888',
    margin: '4px 0 0',
  },
  twoColumn: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '24px',
    marginBottom: '24px',
  },
  tableContainer: {
    backgroundColor: 'white',
    borderRadius: '14px',
    padding: '24px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
  },
  tableTitle: {
    fontSize: '18px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  tableSubtitle: {
    fontSize: '13px',
    color: '#888',
    margin: '4px 0 20px',
  },
  patientList: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '4px',
  },
  patientRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '15px',
    padding: '12px 8px',
    borderRadius: '8px',
    borderBottom: '1px solid #f0f0f0',
    transition: 'background-color 0.2s ease-in-out',
  },
  patientRank: { width: '34px' },
  rankNumber: {
    fontSize: '15px',
    fontWeight: 'bold' as const,
    color: '#666',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: '28px',
    height: '28px',
    borderRadius: '50%',
    backgroundColor: '#f3f4f6',
  },
  rankGold: { backgroundColor: '#fef3c7', color: '#92400e' },
  rankSilver: { backgroundColor: '#e5e7eb', color: '#374151' },
  rankBronze: { backgroundColor: '#fed7aa', color: '#9a3412' },
  patientInfo: { flex: 1 },
  patientName: {
    fontSize: '15px',
    fontWeight: '500' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  patientMeta: { fontSize: '12px', color: '#888', margin: '3px 0 0' },
  patientVisits: { textAlign: 'right' as const },
  visitsNumber: {
    fontSize: '18px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#2563eb',
  },
  visitsLabel: { fontSize: '10px', color: '#888', margin: 0, textTransform: 'uppercase' as const, letterSpacing: '0.5px' },

  breakdownRow: { marginBottom: '18px' },
  breakdownHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    marginBottom: '8px',
    fontSize: '14px',
  },
  breakdownLabel: { color: '#333', fontWeight: '500' as const },
  breakdownValue: { color: '#1a1a2e', fontWeight: '600' as const },
  breakdownPct: { color: '#888', fontWeight: '400' as const, fontSize: '12px' },
  progressBar: {
    height: '8px',
    backgroundColor: '#f3f4f6',
    borderRadius: '4px',
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: '4px',
    transition: 'width 0.5s ease',
  },

  miniStats: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '12px',
    marginTop: '24px',
    paddingTop: '20px',
    borderTop: '1px solid #f0f0f0',
  },
  miniStat: {
    textAlign: 'center' as const,
    padding: '12px 8px',
    backgroundColor: '#f9fafb',
    borderRadius: '10px',
  },
  miniStatValue: {
    fontSize: '20px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#2563eb',
  },
  miniStatLabel: { fontSize: '11px', color: '#666', margin: '4px 0 0' },

  summaryBar: {
    backgroundColor: 'white',
    borderRadius: '14px',
    padding: '24px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    display: 'flex',
    justifyContent: 'space-around',
    alignItems: 'center',
    flexWrap: 'wrap' as const,
    gap: '16px',
  },
  summaryItem: { textAlign: 'center' as const, minWidth: '100px' },
  summaryNumber: {
    fontSize: '24px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#2563eb',
  },
  summaryLabel: { fontSize: '12px', color: '#666', margin: '4px 0 0' },
  summaryDivider: {
    width: '1px',
    height: '40px',
    backgroundColor: '#e5e7eb',
  },
};