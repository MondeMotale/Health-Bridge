import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import { collection, query, onSnapshot, orderBy, doc, updateDoc } from 'firebase/firestore';
import Layout from '../components/Layout';

export default function Reports() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  // 1. Protect this page
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

  // 2. Fetch LIVE reports from Firestore
  useEffect(() => {
    if (loading) return;

    const q = query(collection(db, 'reports'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const data = snapshot.docs.map((doc) => {
        const raw = doc.data();
        
        // Safely handle date formatting
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
          title: raw.title || 'Untitled Report',
          content: raw.content || 'No content',
          chwName: raw.chwName || 'CHW',
          isRead: raw.isRead || false,
          _displayDate: displayDate,
        };
      });
      setReports(data);
    });

    return () => unsubscribe();
  }, [loading]);

  const handleMarkAsRead = async (id: string) => {
    try {
      await updateDoc(doc(db, 'reports', id), { isRead: true });
    } catch (e) {
      console.error("Mark as read error:", e);
    }
  };

  if (loading) {
    return <div style={{ display: 'flex', justifyContent: 'center', padding: '50px' }}>Loading reports...</div>;
  }

  return (
    <Layout>
      <div style={styles.container}>
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>CHW Reports</h1>
            <p style={styles.pageSubtitle}>Live reports submitted by CHWs.</p>
          </div>
          <div style={{ 
            backgroundColor: reports.filter(r => !r.isRead).length > 0 ? '#ef4444' : '#e5e7eb', 
            color: reports.filter(r => !r.isRead).length > 0 ? 'white' : '#888',
            padding: '6px 14px', 
            borderRadius: '20px', 
            fontSize: '13px', 
            fontWeight: 'bold'
          }}>
            {reports.filter(r => !r.isRead).length} New
          </div>
        </div>

        {reports.length === 0 ? (
          <div style={{ backgroundColor: 'white', padding: '40px', borderRadius: '12px', textAlign: 'center', color: '#888' }}>
            <p>No reports have been submitted yet.</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            {reports.map((report) => (
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
                  <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 'bold', color: '#1a1a2e' }}>{report.title}</h3>
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
                <p style={{ fontSize: '14px', color: '#555', margin: '0 0 12px 0', lineHeight: 1.6 }}>{report.content}</p>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '12px', borderTop: '1px solid #f0f0f0', paddingTop: '12px' }}>
                  <span style={{ fontSize: '12px', color: '#888' }}>Submitted by: <b>{report.chwName}</b></span>
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
            ))}
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
};