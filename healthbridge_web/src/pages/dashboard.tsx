import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import { collection, query, where, onSnapshot, orderBy, limit, doc, updateDoc, getDocs } from 'firebase/firestore';
import Layout from '../components/Layout';

export default function Dashboard() {
  const router = useRouter();
  const [currentTime, setCurrentTime] = useState('');
  const [loading, setLoading] = useState(true);
  const [activeCHWs, setActiveCHWs] = useState(0); // <--- NEW STATE

  // Real-time data states
  const [stats, setStats] = useState({ total: 0, critical: 0, followUp: 0, chwCount: 0 });
  const [urgentPatients, setUrgentPatients] = useState<any[]>([]);
  const [recentActivity, setRecentActivity] = useState<any[]>([]);

  useEffect(() => {
    const date = new Date();
    const options: Intl.DateTimeFormatOptions = { weekday: 'long', month: 'long', day: 'numeric' };
    setCurrentTime(date.toLocaleDateString('en-US', options));

    const unsubscribeAuth = onAuthStateChanged(auth, (user) => {
      if (!user) {
        router.push('/login');
        return;
      }
      setLoading(false);
    });

    return () => unsubscribeAuth();
  }, [router]);

  // Real-time listeners for Firestore data
  useEffect(() => {
    if (loading) return;

    // 1. Stats: Count patients and critical cases
    const unsubPatients = onSnapshot(collection(db, 'patients'), (snapshot) => {
      const total = snapshot.size;
      const critical = snapshot.docs.filter(d => d.data().status === 'Critical').length;
      const followUp = snapshot.docs.filter(d => d.data().status === 'Needs Follow-up').length;
      setStats(prev => ({ ...prev, total, critical, followUp }));
    });

    // 2. Count ACTIVE CHWs (LIVE COUNT)
    const qCHWs = query(collection(db, 'users'), where('role', 'in', ['chw', ['chw']]));
    const unsubCHWs = onSnapshot(qCHWs, (snapshot) => {
      const docs = snapshot.docs.map(d => d.data());
      // Count only those with status 'Active'
      const activeCount = docs.filter((d: any) => d.status === 'Active').length;
      setActiveCHWs(activeCount);
    });

    // 3. Urgent Referrals: Patients with 'Critical' or 'Needs Follow-up'
    const qUrgent = query(
      collection(db, 'patients'),
      where('status', 'in', ['Critical', 'Needs Follow-up']),
      orderBy('createdAt', 'desc'),
      limit(10)
    );
    const unsubUrgent = onSnapshot(qUrgent, (snapshot) => {
      const urgent = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      setUrgentPatients(urgent);
    });

    // 4. Recent Activity (FIXED DATE HANDLING)
    const qActivity = query(
      collection(db, 'patients'),
      orderBy('createdAt', 'desc'),
      limit(5)
    );
    const unsubActivity = onSnapshot(qActivity, (snapshot) => {
      const activities = snapshot.docs.map((doc) => {
        const data = doc.data();
        let timeString = 'Just now';
        
        if (data.createdAt) {
          if (typeof data.createdAt.toDate === 'function') {
            timeString = new Date(data.createdAt.toDate()).toLocaleString();
          } else if (typeof data.createdAt === 'string') {
            timeString = new Date(data.createdAt).toLocaleString();
          }
        }

        return {
          id: doc.id,
          action: 'New patient registered',
          name: data.name || 'Unknown Patient',
          time: timeString,
          type: 'patient'
        };
      });
      setRecentActivity(activities);
    });

    return () => {
      unsubPatients();
      unsubCHWs();
      unsubUrgent();
      unsubActivity();
    };
  }, [loading]);

  if (loading) {
    return <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>Loading dashboard...</div>;
  }

  return (
    <Layout>
      <div style={styles.container}>
        {/* Welcome Section */}
        <div style={styles.welcomeSection}>
          <div>
            <h1 style={styles.title}>Welcome back, Admin</h1>
            <p style={styles.subtitle}>Today is {currentTime}. Here's the real-time clinic overview.</p>
          </div>
          <div style={styles.dateBadge}>
            <span>📅 {currentTime}</span>
          </div>
        </div>

        {/* Real-time Stats Grid */}
        <div style={styles.statsGrid}>
          {[
            { title: 'Total Patients', value: stats.total, icon: '👥' },
            { title: 'Critical Cases', value: stats.critical, icon: '🚨' },
            { title: 'Needs Follow-up', value: stats.followUp, icon: '📋' },
            { title: 'Active CHWs', value: activeCHWs, icon: '👩‍⚕️' }, // <--- LIVE COUNT
          ].map((stat, index) => (
            <div key={index} style={styles.statCard}>
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
          {/* Urgent Referrals Column */}
          <div style={styles.column}>
            <div style={styles.card}>
              <div style={styles.cardHeader}>
                <h3 style={styles.cardTitle}>Urgent Referrals Needing Action</h3>
              </div>
              <p style={styles.cardSubtitle}>Real-time critical and high-priority patients</p>
              <div style={styles.referralsList}>
                {urgentPatients.length === 0 ? (
                  <p style={{ color: '#888' }}>No urgent patients at this moment.</p>
                ) : (
                  urgentPatients.map((patient: any) => (
                    <div key={patient.id} style={styles.referralItem}>
                      <div style={styles.referralHeader}>
                        <div style={styles.referralInfo}>
                          <span style={{
                            ...styles.urgencyBadge,
                            backgroundColor: patient.status === 'Critical' ? '#fee2e2' : '#e0f2fe',
                            color: patient.status === 'Critical' ? '#991b1b' : '#0369a1',
                          }}>
                            {patient.status}
                          </span>
                          <span style={styles.referralTime}>
                            {patient.createdAt ? new Date(patient.createdAt?.toDate ? patient.createdAt.toDate() : patient.createdAt).toLocaleString() : 'Recently'}
                          </span>
                        </div>
                      </div>
                      <h4 style={styles.referralName}>{patient.name}</h4>
                      <p style={styles.referralCondition}>{patient.condition}</p>
                      <p style={styles.referralLocation}>📍 {patient.address || 'Address not listed'}</p>
                      <button style={styles.primaryButton} onClick={() => console.log('Action for', patient.id)}>
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
                <h3 style={styles.cardTitle}>Recent Patient Registrations</h3>
              </div>
              <div style={styles.activityList}>
                {recentActivity.length === 0 ? (
                  <p style={{ color: '#888' }}>No recent activity.</p>
                ) : (
                  recentActivity.map((activity: any) => (
                    <div key={activity.id} style={styles.activityItem}>
                      <div style={styles.activityIcon}>👤</div>
                      <div style={styles.activityContent}>
                        <p style={styles.activityAction}>{activity.action}</p>
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
    </Layout>
  );
}

const styles = {
  container: { display: 'flex', flexDirection: 'column' as const, padding: '24px', backgroundColor: '#f9fafb', fontFamily: "'Segoe UI', Roboto, Helvetica, Arial, sans-serif" },
  welcomeSection: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '28px' },
  title: { fontSize: '26px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  subtitle: { color: '#666', marginTop: '8px', marginBottom: 0, fontSize: '14px' },
  dateBadge: { padding: '8px 14px', backgroundColor: 'white', borderRadius: '10px', fontSize: '13px', color: '#2563eb', fontWeight: '500' as const, boxShadow: '0 1px 3px rgba(0,0,0,0.1)' },
  statsGrid: { display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '20px', marginBottom: '28px' },
  statCard: { backgroundColor: 'white', padding: '20px', borderRadius: '14px', boxShadow: '0 2px 6px rgba(0,0,0,0.1)', transition: 'all 0.2s ease', cursor: 'pointer' },
  statHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' },
  statIcon: { fontSize: '32px' },
  statValue: { fontSize: '34px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  statTitle: { fontSize: '14px', color: '#666', margin: '8px 0 0' },
  twoColumn: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' },
  column: { display: 'flex', flexDirection: 'column' as const },
  card: { backgroundColor: 'white', borderRadius: '14px', padding: '20px', boxShadow: '0 2px 6px rgba(0,0,0,0.1)' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' },
  cardTitle: { fontSize: '18px', fontWeight: '600' as const, margin: 0, color: '#1a1a2e' },
  cardSubtitle: { fontSize: '13px', color: '#888', margin: '0 0 16px 0' },
  referralsList: { display: 'flex', flexDirection: 'column' as const, gap: '14px' },
  referralItem: { padding: '16px', border: '1px solid #e5e7eb', borderRadius: '12px', transition: 'all 0.2s ease', cursor: 'pointer' },
  referralHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' },
  referralInfo: { display: 'flex', gap: '10px', alignItems: 'center' },
  urgencyBadge: { padding: '3px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: '600' as const },
  referralTime: { fontSize: '11px', color: '#888' },
  referralName: { fontSize: '16px', fontWeight: '600' as const, margin: '0 0 6px 0', color: '#1a1a2e' },
  referralCondition: { fontSize: '13px', color: '#666', margin: '0 0 4px' },
  referralLocation: { fontSize: '12px', color: '#888', margin: '0 0 14px' },
  primaryButton: { backgroundColor: '#2563eb', color: 'white', padding: '8px 16px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: '500' as const, transition: 'background-color 0.2s' },
  activityList: { display: 'flex', flexDirection: 'column' as const, gap: '16px' },
  activityItem: { display: 'flex', gap: '14px', padding: '10px 0', borderBottom: '1px solid #f0f0f0' },
  activityIcon: { fontSize: '28px' },
  activityContent: { flex: 1 },
  activityAction: { fontSize: '14px', fontWeight: '500' as const, margin: 0, color: '#333' },
  activityName: { fontSize: '13px', color: '#666', margin: '4px 0 0' },
  activityTime: { fontSize: '11px', color: '#999', margin: '4px 0 0' },
};