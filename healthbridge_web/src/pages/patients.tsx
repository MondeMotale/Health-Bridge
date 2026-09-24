import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import { collection, query, onSnapshot, orderBy } from 'firebase/firestore';
import Layout from '../components/Layout';

export default function Patients() {
  const router = useRouter();
  const [searchTerm, setSearchTerm] = useState('');
  const [patients, setPatients] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  
  // State for the pop-up modal
  const [selectedPatient, setSelectedPatient] = useState<any>(null);

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

  // 2. Fetch REAL patients from Firestore
  useEffect(() => {
    if (loading) return;

    const q = query(collection(db, 'patients'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
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
          _lastVisit: dateStr
        };
      });
      setPatients(data);
    });

    return () => unsubscribe();
  }, [loading]);

  // 3. Filter patients
  const filteredPatients = patients.filter(patient =>
    (patient.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
    (patient.condition || '').toLowerCase().includes(searchTerm.toLowerCase())
  );

  // 4. Function to close the modal
  const closeModal = () => {
    setSelectedPatient(null);
  };

  if (loading) {
    return <div style={{ display: 'flex', justifyContent: 'center', padding: '50px', color: '#666' }}>Loading patients...</div>;
  }

  return (
    <Layout>
      <div style={styles.container}>
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Patients</h1>
            <p style={styles.pageSubtitle}>Manage your patient records</p>
          </div>
          <button style={styles.addButton}>+ Add Patient</button>
        </div>

        <div style={styles.searchContainer}>
          <input
            type="text"
            placeholder="🔍 Search patients by name or condition..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={styles.searchInput}
          />
        </div>

        {filteredPatients.length === 0 ? (
          <div style={{ backgroundColor: 'white', padding: '40px', borderRadius: '12px', textAlign: 'center', color: '#888' }}>
            <p>No patients found matching your search.</p>
          </div>
        ) : (
          <div style={styles.cardsGrid}>
            {filteredPatients.map((patient) => (
              <div key={patient.id} style={styles.card}>
                <div style={styles.cardHeader}>
                  <div style={styles.avatar}>
                    <span style={styles.avatarText}>{(patient.name || '?')[0]}</span>
                  </div>
                  <div>
                    <h3 style={styles.patientName}>{patient.name || 'Unknown'}</h3>
                    <p style={styles.patientDetail}>{patient.age || '?'} years</p>
                  </div>
                </div>
                <div style={styles.cardBody}>
                  <p style={styles.detailRow}>📞 {patient.phone || 'N/A'}</p>
                  <p style={styles.detailRow}>🩺 {patient.condition || 'N/A'}</p>
                  <p style={styles.detailRow}>📍 {patient.address || 'N/A'}</p>
                  <p style={styles.detailRow}>📅 Added: {patient._lastVisit}</p>
                </div>
                <div style={styles.cardFooter}>
                  <span style={{ 
                    ...styles.statusBadge, 
                    ...(patient.status === 'Critical' ? styles.statusCritical : 
                        patient.status === 'Needs Follow-up' ? styles.statusFollowUp : 
                        styles.statusStable)
                  }}>
                    {patient.status || 'Stable'}
                  </span>
                  {/* --- UPDATED: Clicking this opens the modal --- */}
                  <button 
                    style={styles.viewButton} 
                    onClick={() => setSelectedPatient(patient)}
                  >
                    View Details
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* --- MODAL / POP-UP --- */}
      {selectedPatient && (
        <div style={styles.modalOverlay} onClick={closeModal}>
          <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <div style={styles.modalHeader}>
              <h2 style={styles.modalTitle}>{selectedPatient.name}</h2>
              <button onClick={closeModal} style={styles.closeButton}>×</button>
            </div>
            
            <div style={styles.modalBody}>
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Age:</span>
                <span style={styles.modalValue}>{selectedPatient.age} yrs</span>
              </div>
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Condition:</span>
                <span style={styles.modalValue}>{selectedPatient.condition}</span>
              </div>
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Status:</span>
                <span style={{
                  ...styles.modalStatusBadge,
                  backgroundColor: selectedPatient.status === 'Critical' ? '#fee2e2' : 
                                  selectedPatient.status === 'Needs Follow-up' ? '#fef3c7' : '#d1fae5',
                  color: selectedPatient.status === 'Critical' ? '#991b1b' : 
                         selectedPatient.status === 'Needs Follow-up' ? '#92400e' : '#065f46',
                }}>
                  {selectedPatient.status || 'Stable'}
                </span>
              </div>
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Phone:</span>
                <span style={styles.modalValue}>{selectedPatient.phone}</span>
              </div>
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Address:</span>
                <span style={styles.modalValue}>{selectedPatient.address}</span>
              </div>
              {selectedPatient.notes && (
                <>
                  <div style={styles.modalDivider}></div>
                  <div style={styles.modalRow}>
                    <span style={styles.modalLabel}>Notes:</span>
                    <span style={styles.modalValue}>{selectedPatient.notes}</span>
                  </div>
                </>
              )}
              <div style={styles.modalRow}>
                <span style={styles.modalLabel}>Registered:</span>
                <span style={styles.modalValue}>{selectedPatient._lastVisit}</span>
              </div>
            </div>

            <div style={styles.modalFooter}>
              <button onClick={closeModal} style={styles.modalCloseBtn}>Close</button>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
}

const styles = {
  container: { padding: '24px', backgroundColor: '#f9fafb', fontFamily: "'Segoe UI', Roboto, sans-serif" },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap' as const, gap: '16px' },
  pageTitle: { fontSize: '26px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  pageSubtitle: { color: '#666', marginTop: '8px', marginBottom: 0 },
  addButton: { backgroundColor: '#2563eb', color: 'white', padding: '10px 20px', border: 'none', borderRadius: '10px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' as const },
  searchContainer: { marginBottom: '24px' },
  searchInput: { width: '100%', maxWidth: '400px', padding: '12px 16px', border: '1px solid #e5e7eb', borderRadius: '10px', fontSize: '14px', outline: 'none' },
  cardsGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(350px, 1fr))', gap: '20px' },
  card: { backgroundColor: 'white', borderRadius: '14px', padding: '20px', boxShadow: '0 2px 6px rgba(0,0,0,0.1)' },
  cardHeader: { display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '16px' },
  avatar: { width: '52px', height: '52px', backgroundColor: '#2563eb', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' },
  avatarText: { color: 'white', fontSize: '22px', fontWeight: 'bold' as const },
  patientName: { fontSize: '18px', fontWeight: '600' as const, margin: 0, color: '#1a1a2e' },
  patientDetail: { fontSize: '12px', color: '#666', margin: '4px 0 0' },
  cardBody: { marginBottom: '16px' },
  detailRow: { margin: '6px 0', fontSize: '13px', color: '#555' },
  cardFooter: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingTop: '16px', borderTop: '1px solid #e5e7eb' },
  statusBadge: { padding: '4px 12px', borderRadius: '20px', fontSize: '12px', fontWeight: '500' as const },
  statusStable: { backgroundColor: '#d1fae5', color: '#065f46' },
  statusFollowUp: { backgroundColor: '#fef3c7', color: '#92400e' },
  statusCritical: { backgroundColor: '#fee2e2', color: '#991b1b' },
  viewButton: { backgroundColor: '#2563eb', color: 'white', padding: '6px 14px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '12px' },

  // --- MODAL / POP-UP STYLES ---
  modalOverlay: {
    position: 'fixed' as const,
    top: 0, left: 0, right: 0, bottom: 0,
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
    maxHeight: '90vh',
    overflowY: 'auto' as const,
    boxShadow: '0 10px 30px rgba(0,0,0,0.2)',
  },
  modalHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '20px',
  },
  modalTitle: { fontSize: '22px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  closeButton: { background: 'none', border: 'none', fontSize: '28px', cursor: 'pointer', color: '#888' },
  modalBody: { display: 'flex', flexDirection: 'column' as const, gap: '12px' },
  modalRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  modalLabel: { color: '#6B7280', fontWeight: '500' as const, fontSize: '14px' },
  modalValue: { color: '#1A1A2E', fontWeight: '500' as const, fontSize: '14px' },
  modalStatusBadge: { padding: '4px 12px', borderRadius: '20px', fontSize: '12px', fontWeight: '500' as const },
  modalDivider: { height: '1px', backgroundColor: '#e5e7eb', margin: '8px 0' },
  modalFooter: { marginTop: '24px', display: 'flex', justifyContent: 'flex-end' },
  modalCloseBtn: { backgroundColor: '#2563eb', color: 'white', padding: '10px 24px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '14px' },
};