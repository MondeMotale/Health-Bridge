import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import { collection, query, onSnapshot, orderBy, doc, updateDoc } from 'firebase/firestore';
import Layout from '../components/Layout';

export default function Referrals() {
  const router = useRouter();
  const [referrals, setReferrals] = useState<any[]>([]);
  const [filter, setFilter] = useState('All');
  const [loading, setLoading] = useState(true);

  // 1. Protect page
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (!user) {
        router.push('/login');
        return;
      }
      setLoading(false);
    });
    return () => unsubscribe();
  }, [router]);

  // 2. Fetch LIVE referrals from Firestore
  useEffect(() => {
    if (loading) return;

    const q = query(collection(db, 'referrals'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const data = snapshot.docs.map((doc) => {
        const raw = doc.data();
        
        // Safe Date formatting
        let displayDate = 'Just now';
        if (raw.createdAt) {
          try {
            if (typeof raw.createdAt === 'string') {
              displayDate = new Date(raw.createdAt).toLocaleDateString();
            } else if (raw.createdAt.toDate && typeof raw.createdAt.toDate === 'function') {
              displayDate = raw.createdAt.toDate().toLocaleDateString();
            }
          } catch (e) {
            displayDate = 'Unknown';
          }
        }

        return {
          id: doc.id,
          ...raw,
          _displayDate: displayDate,
        };
      });
      setReferrals(data);
    });

    return () => unsubscribe();
  }, [loading]);

  // 3. Update Status in Firestore
  const updateStatus = async (id: string, newStatus: string) => {
    try {
      await updateDoc(doc(db, 'referrals', id), { status: newStatus });
    } catch (e) {
      console.error("Failed to update status:", e);
    }
  };

  // 4. Filter Logic
  const filteredReferrals = filter === 'All' 
    ? referrals 
    : referrals.filter(r => r.status === filter);

  // 5. Stats Calculation
  const stats = {
    total: referrals.length,
    pending: referrals.filter(r => r.status === 'Pending').length,
    review: referrals.filter(r => r.status === 'In Review').length,
    completed: referrals.filter(r => r.status === 'Completed').length,
  };

  if (loading) {
    return <div style={{ padding: '50px', textAlign: 'center', color: '#666' }}>Loading referrals...</div>;
  }

  return (
    <Layout>
      <div style={styles.container}>
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Referrals</h1>
            <p style={styles.pageSubtitle}>Manage patient referrals and track status</p>
          </div>
        </div>

        {/* Stats Cards */}
        <div style={styles.statsGrid}>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{stats.total}</p>
            <p style={styles.statLabel}>Total Referrals</p>
          </div>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{stats.pending}</p>
            <p style={styles.statLabel}>Pending Action</p>
          </div>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{stats.review}</p>
            <p style={styles.statLabel}>In Review</p>
          </div>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{stats.completed}</p>
            <p style={styles.statLabel}>Completed</p>
          </div>
        </div>

        {/* Filter Buttons */}
        <div style={styles.filterBar}>
          {['All', 'Pending', 'In Review', 'Approved', 'Completed'].map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              style={{
                ...styles.filterBtn,
                ...(filter === f ? styles.filterActive : {}),
              }}
            >
              {f}
            </button>
          ))}
        </div>

        {/* Table */}
        <div style={styles.tableContainer}>
          <table style={styles.table}>
            <thead>
              <tr>
                <th style={styles.th}>Patient</th>
                <th style={styles.th}>Condition</th>
                <th style={styles.th}>Department</th>
                <th style={styles.th}>Location</th>
                <th style={styles.th}>Urgency</th>
                <th style={styles.th}>Status</th>
                <th style={styles.th}>Date</th>
                <th style={styles.th}></th>
              </tr>
            </thead>
            <tbody>
              {filteredReferrals.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ padding: '40px', textAlign: 'center', color: '#888' }}>
                    No referrals found for this filter.
                  </td>
                </tr>
              ) : (
                filteredReferrals.map((r) => (
                  <tr key={r.id} style={styles.tr}>
                    <td style={styles.td}><b>{r.patientName || 'Unknown'}</b></td>
                    <td style={styles.td}>{r.condition || 'N/A'}</td>
                    <td style={styles.td}>{r.department || 'N/A'}</td>
                    <td style={styles.td}>{r.location || 'N/A'}</td>
                    <td style={styles.td}>
                      <span style={{
                        ...styles.badge,
                        backgroundColor: r.urgency === 'Critical' ? '#fee2e2' : r.urgency === 'High' ? '#fef3c7' : '#d1fae5',
                        color: r.urgency === 'Critical' ? '#991b1b' : r.urgency === 'High' ? '#92400e' : '#065f46',
                      }}>
                        {r.urgency || 'Medium'}
                      </span>
                    </td>
                    <td style={styles.td}>
                      <select
                        value={r.status || 'Pending'}
                        onChange={(e) => updateStatus(r.id, e.target.value)}
                        style={{
                          ...styles.statusSelect,
                          backgroundColor: r.status === 'Completed' ? '#d1fae5' : r.status === 'In Review' ? '#fef3c7' : '#fee2e2',
                        }}
                      >
                        <option value="Pending">Pending</option>
                        <option value="In Review">In Review</option>
                        <option value="Approved">Approved</option>
                        <option value="Completed">Completed</option>
                      </select>
                    </td>
                    <td style={styles.td}>{r._displayDate || 'Just now'}</td>
                    <td style={styles.td}>
                      <button 
                        style={styles.viewBtn}
                        onClick={() => alert(`Viewing details for ${r.patientName || 'patient'}`)}
                      >
                        View
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </Layout>
  );
}

const styles = {
  container: { 
    padding: '24px', 
    backgroundColor: '#f9fafb', 
    fontFamily: "'Segoe UI', Roboto, sans-serif" 
  },
  header: { 
    display: 'flex', 
    justifyContent: 'space-between', 
    marginBottom: '24px' 
  },
  pageTitle: { 
    fontSize: '26px', 
    fontWeight: 'bold' as const, 
    margin: 0, 
    color: '#1a1a2e' 
  },
  pageSubtitle: { 
    color: '#666', 
    marginTop: '8px' 
  },
  statsGrid: { 
    display: 'grid', 
    gridTemplateColumns: 'repeat(4, 1fr)', 
    gap: '20px', 
    marginBottom: '24px' 
  },
  statCard: { 
    backgroundColor: 'white', 
    padding: '20px', 
    borderRadius: '14px', 
    textAlign: 'center' as const, 
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)' 
  },
  statValue: { 
    fontSize: '32px', 
    fontWeight: 'bold' as const, 
    margin: 0, 
    color: '#2563eb' 
  },
  statLabel: { 
    fontSize: '13px', 
    color: '#666', 
    margin: '8px 0 0' 
  },
  filterBar: { 
    display: 'flex', 
    gap: '12px', 
    marginBottom: '20px', 
    flexWrap: 'wrap' as const,
  },
  filterBtn: { 
    padding: '8px 16px', 
    borderRadius: '20px', 
    border: 'none', 
    cursor: 'pointer', 
    backgroundColor: '#f3f4f6', 
    color: '#666', 
    fontSize: '13px',
    fontWeight: '500' as const,
    transition: 'all 0.2s',
  },
  filterActive: { 
    backgroundColor: '#2563eb', 
    color: 'white' 
  },
  tableContainer: { 
    backgroundColor: 'white', 
    borderRadius: '14px', 
    padding: '20px', 
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)' 
  },
  table: { 
    width: '100%', 
    borderCollapse: 'collapse' as const 
  },
  th: { 
    textAlign: 'left' as const, 
    padding: '12px 16px', 
    borderBottom: '1px solid #e5e7eb', 
    color: '#666', 
    fontSize: '13px', 
    fontWeight: '500' as const 
  },
  tr: { 
    borderBottom: '1px solid #f0f0f0' 
  },
  td: { 
    padding: '12px 16px', 
    fontSize: '14px', 
    color: '#333' 
  },
  badge: { 
    padding: '4px 12px', 
    borderRadius: '20px', 
    fontSize: '12px', 
    fontWeight: '500' as const, 
    display: 'inline-block' as const 
  },
  statusSelect: { 
    padding: '6px 12px', 
    borderRadius: '8px', 
    border: 'none', 
    fontSize: '12px', 
    fontWeight: '500' as const, 
    cursor: 'pointer' as const,
    outline: 'none',
  },
  viewBtn: { 
    backgroundColor: '#2563eb', 
    color: 'white', 
    padding: '6px 14px', 
    border: 'none', 
    borderRadius: '8px', 
    cursor: 'pointer', 
    fontSize: '12px', 
    fontWeight: '500' as const,
    transition: 'all 0.2s',
  },
};