import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import {
  collection,
  query,
  onSnapshot,
  orderBy,
  doc,
  updateDoc,
} from 'firebase/firestore';
import Layout from '../components/Layout';

export default function Reports() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // 1. Auth guard
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

  // 2. Live reports
  useEffect(() => {
    if (loading) return;
    const q = query(collection(db, 'reports'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const data = snapshot.docs.map((d) => {
          const raw = d.data();
          let displayDate = 'Just now';
          if (raw.createdAt) {
            try {
              if (typeof raw.createdAt === 'string') {
                displayDate = new Date(raw.createdAt).toLocaleDateString();
              } else if (raw.createdAt.toDate && typeof raw.createdAt.toDate === 'function') {
                displayDate = raw.createdAt.toDate().toLocaleDateString();
              }
            } catch {
              displayDate = 'Unknown';
            }
          }
          return {
            id: d.id,
            title: raw.title || 'Untitled Report',
            content: raw.content || 'No content',
            chwName: raw.chwName || '',
            chwId: raw.chwId || raw.userId || raw.submittedBy || '',
            chwEmail: raw.chwEmail || raw.email || '',
            isRead: raw.isRead || false,
            _displayDate: displayDate,
          };
        });
        setReports(data);
      },
      (err) => setError('Failed to load reports: ' + err.message)
    );
    return () => unsubscribe();
  }, [loading]);

  // 3. Live users — so we can resolve the real CHW name
  useEffect(() => {
    if (loading) return;
    const q = query(collection(db, 'users'));
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        setUsers(snapshot.docs.map((d) => ({ id: d.id, ...d.data() })));
      },
      (err) => setError('Failed to load users: ' + err.message)
    );
    return () => unsubscribe();
  }, [loading]);

  // -------------------------------------------------------------
  // Resolve the CHW name for a report
  // -------------------------------------------------------------
  const resolveChwName = (report: any): string => {
    // 1. If the report already has a real name (not a placeholder), use it
    const rawName = (report.chwName || '').trim();
    const placeholders = ['chw', 'unknown', 'unnamed', 'user', '-', ''];
    if (rawName && !placeholders.includes(rawName.toLowerCase())) {
      return rawName;
    }

    // 2. Match by CHW id / userId / submittedBy
    if (report.chwId) {
      const user = users.find(
        (u) => u.id === report.chwId || u.uid === report.chwId
      );
      if (user) {
        return (
          user.displayName ||
          user.name ||
          (user.email ? user.email.split('@')[0] : '') ||
          'CHW'
        );
      }
    }

    // 3. Match by email
    if (report.chwEmail) {
      const user = users.find(
        (u) =>
          (u.email || '').toLowerCase() === report.chwEmail.toLowerCase()
      );
      if (user) {
        return user.displayName || user.name || user.email || 'CHW';
      }
    }

    // 4. Try matching by the CHW's first name if it's embedded in the title
    //    (some CHWs type their own name into the title)
    if (report.title) {
      const titleLower = String(report.title).toLowerCase();
      const matchedUser = users.find((u) => {
        const name = (u.displayName || u.name || '').toLowerCase().trim();
        if (!name) return false;
        const firstName = name.split(' ')[0];
        return titleLower.includes(firstName) && firstName.length > 2;
      });
      if (matchedUser) {
        return matchedUser.displayName || matchedUser.name || 'CHW';
      }
    }

    // 5. Nothing worked
    return 'Unknown CHW';
  };

  const handleMarkAsRead = async (id: string) => {
    try {
      await updateDoc(doc(db, 'reports', id), { isRead: true });
    } catch (e: any) {
      setError('Failed to mark as read: ' + e.message);
    }
  };

  const unreadCount = reports.filter((r) => !r.isRead).length;

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: '50px' }}>
        Loading reports...
      </div>
    );
  }

  return (
    <Layout>
      <div style={styles.container}>
        {error && (
          <div style={styles.errorBanner}>
            <span>⚠️ {error}</span>
            <button onClick={() => setError('')} style={styles.errorClose}>×</button>
          </div>
        )}

        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>CHW Reports</h1>
            <p style={styles.pageSubtitle}>Live reports submitted by CHWs.</p>
          </div>
          <div
            style={{
              backgroundColor: unreadCount > 0 ? '#ef4444' : '#e5e7eb',
              color: unreadCount > 0 ? 'white' : '#888',
              padding: '6px 14px',
              borderRadius: '20px',
              fontSize: '13px',
              fontWeight: 'bold',
            }}
          >
            {unreadCount} New
          </div>
        </div>

        {reports.length === 0 ? (
          <div style={{ backgroundColor: 'white', padding: '40px', borderRadius: '12px', textAlign: 'center', color: '#888' }}>
            <p>No reports have been submitted yet.</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            {reports.map((report) => {
              const chwName = resolveChwName(report);
              return (
                <div
                  key={report.id}
                  style={{
                    backgroundColor: 'white',
                    padding: '20px',
                    borderRadius: '12px',
                    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
                    borderLeft: report.isRead ? '4px solid #10b981' : '4px solid #ef4444',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                    <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 'bold', color: '#1a1a2e' }}>
                      {report.title}
                    </h3>
                    <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                      {!report.isRead && (
                        <span style={{ backgroundColor: '#ef4444', color: 'white', padding: '4px 12px', borderRadius: '20px', fontSize: '12px', fontWeight: 'bold' }}>
                          New
                        </span>
                      )}
                      <span style={{ fontSize: '12px', color: '#888' }}>
                        {report._displayDate}
                      </span>
                    </div>
                  </div>

                  <p style={{ fontSize: '14px', color: '#555', margin: '0 0 12px 0', lineHeight: 1.6 }}>
                    {report.content}
                  </p>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '12px', borderTop: '1px solid #f0f0f0', paddingTop: '12px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <div style={{
                        width: '28px',
                        height: '28px',
                        borderRadius: '50%',
                        backgroundColor: '#2563eb',
                        color: 'white',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '12px',
                        fontWeight: 'bold',
                      }}>
                        {chwName.charAt(0).toUpperCase()}
                      </div>
                      <span style={{ fontSize: '13px', color: '#666' }}>
                        Submitted by{' '}
                        <b style={{ color: '#1a1a2e' }}>{chwName}</b>
                      </span>
                    </div>

                    {!report.isRead && (
                      <button
                        onClick={() => handleMarkAsRead(report.id)}
                        style={{
                          backgroundColor: '#1E3A8A',
                          color: 'white',
                          border: 'none',
                          padding: '6px 16px',
                          borderRadius: '8px',
                          cursor: 'pointer',
                          fontSize: '12px',
                          fontWeight: '500',
                        }}
                      >
                        Mark as Read
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </Layout>
  );
}

const styles = {
  container: { padding: '24px', backgroundColor: '#f9fafb', fontFamily: "'Segoe UI', Roboto, sans-serif" },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' },
  pageTitle: { fontSize: '26px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  pageSubtitle: { color: '#666', marginTop: '4px', marginBottom: 0 },
  errorBanner: {
    backgroundColor: '#fee2e2',
    color: '#991b1b',
    padding: '10px 14px',
    borderRadius: '8px',
    marginBottom: '16px',
    fontSize: '13px',
    border: '1px solid #fecaca',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  errorClose: {
    background: 'none',
    border: 'none',
    fontSize: '18px',
    cursor: 'pointer',
    color: '#991b1b',
  },
};