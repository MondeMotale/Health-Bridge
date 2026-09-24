import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged, createUserWithEmailAndPassword, sendPasswordResetEmail, signInWithEmailAndPassword } from 'firebase/auth'; // <--- ADDED THIS
import { auth, db } from '../lib/firebase';
import { collection, query, where, onSnapshot, getDocs } from 'firebase/firestore';
import { doc, setDoc, updateDoc } from 'firebase/firestore';
import Layout from '../components/Layout';

export default function HomeBasedCare() {
  const router = useRouter();
  const [showAddModal, setShowAddModal] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [chws, setChws] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedChw, setSelectedChw] = useState<any>(null); // For the pop-up

  // --- ADD CHW FORM STATE ---
  const [newChw, setNewChw] = useState({
    name: '', email: '', phone: '', address: '', area: ''
  });

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

  // 2. Fetch CHWs (Handles both Strings and Arrays)
  useEffect(() => {
    if (loading) return;
    const q = query(collection(db, 'users'));
    const unsubscribe = onSnapshot(q, async (snapshot) => {
      const allUsers = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      
      // Filter to keep only CHWs (Check for String OR Array)
      const chwData = allUsers.filter((user: any) => {
        const role = user.role;
        if (typeof role === 'string') return role === 'chw';
        if (Array.isArray(role)) return role.includes('chw');
        return false;
      });

      const chwsWithPatients = await Promise.all(chwData.map(async (chw) => {
        const patientsQuery = query(collection(db, 'patients'), where('assignedChwId', '==', (chw as any).uid || (chw as any).id));
        const patientsSnapshot = await getDocs(patientsQuery);
        return { ...chw, patientsCount: patientsSnapshot.size };
      }));
      setChws(chwsWithPatients);
    });
    return () => unsubscribe();
  }, [loading]);

  // 3. Filter CHWs
  const filteredCHWs = chws.filter(chw =>
    (chw.displayName || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
    (chw.address || '').toLowerCase().includes(searchTerm.toLowerCase())
  );

  // 4. Stats
  const totalPatients = chws.reduce((sum, chw) => sum + (chw.patientsCount || 0), 0);
  const activeNow = chws.filter(c => c.status === 'Active').length;

  // 5. CREATE CHW (AUTO UID) - WITH 3 SECOND DELAY FOR EMAIL
  const handleAddCHW = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Step 0: Save Admin credentials so we can log back in
    const adminEmail = auth.currentUser?.email || 'admin@gmail.com';
    const adminPassword = 'Admin@123'; // <--- REPLACE WITH YOUR ADMIN PASSWORD
    
    // Step 1: Create Auth account
    const tempPassword = 'HealthBridge@123';
    try {
      const userCredential = await createUserWithEmailAndPassword(auth, newChw.email, tempPassword);
      const uid = userCredential.user.uid;

      // Step 2: Save to Firestore with the NEW UID (CRITICAL: Add 'role' and 'status'!)
      await setDoc(doc(db, 'users', uid), {
        uid: uid,
        role: ["chw"], // <--- THIS GIVES THEM THE CHW ROLE
        displayName: newChw.name,
        email: newChw.email,
        phoneNumber: newChw.phone,
        address: newChw.address,
        status: 'Active', // <--- THIS MAKES THEM ACTIVE
      });

      // Step 3: RE-LOGIN AS ADMIN (So you don't lose your session!)
      if (adminEmail) {
        try {
          await signInWithEmailAndPassword(auth, adminEmail, adminPassword);
        } catch (loginError) {
          console.warn("Failed to re-login admin:", loginError);
        }
      }

      // Step 4: Wait 3 seconds before sending email
      setTimeout(async () => {
        try {
          await sendPasswordResetEmail(auth, newChw.email);
          alert(`CHW created successfully! Password reset email sent to ${newChw.email}`);
          setNewChw({ name: '', email: '', phone: '', address: '', area: '' });
          setShowAddModal(false);
        } catch (emailError) {
          alert('CHW created, but password reset email failed. Please resend manually.');
          setNewChw({ name: '', email: '', phone: '', address: '', area: '' });
          setShowAddModal(false);
        }
      }, 3000);
    } catch (error) {
      // FIXED: Cast error to any to access .message
      alert('Error creating CHW: ' + (error as any).message);
    }
  };

  // 6. Toggle CHW Status (Active/Inactive)
  const handleToggleStatus = async (chw: any) => {
    const newStatus = chw.status === 'Active' ? 'Inactive' : 'Active';
    try {
      await updateDoc(doc(db, 'users', chw.id), { status: newStatus });
    } catch (error) {
      alert('Error updating status: ' + (error as any).message);
    }
  };

  if (loading) {
    return <div style={{ display: 'flex', justifyContent: 'center', padding: '50px' }}>Loading CHWs...</div>;
  }

  return (
    <Layout>
      <div style={styles.container}>
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Home-Based Care</h1>
            <p style={styles.pageSubtitle}>Manage Community Health Workers</p>
          </div>
          <button onClick={() => setShowAddModal(true)} style={styles.addButton}>+ Add CHW</button>
        </div>

        <div style={styles.statsGrid}>
          <div style={styles.statCard}><p style={styles.statValue}>{chws.length}</p><p style={styles.statLabel}>Total CHWs</p></div>
          <div style={styles.statCard}><p style={styles.statValue}>{activeNow}</p><p style={styles.statLabel}>Active Now</p></div>
          <div style={styles.statCard}><p style={styles.statValue}>{chws.reduce((sum, c) => sum + (c.visitsToday || 0), 0)}</p><p style={styles.statLabel}>Visits Today</p></div>
          <div style={styles.statCard}><p style={styles.statValue}>{totalPatients}</p><p style={styles.statLabel}>Total Patients</p></div>
        </div>

        <div style={styles.searchContainer}>
          <input type="text" placeholder="🔍 Search CHW by name or area..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} style={styles.searchInput} />
        </div>

        <div style={styles.cardsGrid}>
          {filteredCHWs.length === 0 ? (
            <div style={{ backgroundColor: 'white', padding: '40px', borderRadius: '12px', textAlign: 'center', color: '#888' }}>No CHWs found.</div>
          ) : (
            filteredCHWs.map((chw) => (
              <div key={chw.id} style={styles.card}>
                <div style={styles.cardHeader}>
                  <div style={styles.avatar}><span style={styles.avatarText}>{(chw.displayName || '?')[0]}</span></div>
                  <div style={styles.cardHeaderInfo}>
                    <h3 style={styles.chwName}>{chw.displayName || 'CHW'}</h3>
                    <p style={styles.chwArea}>📍 {chw.address || 'N/A'}</p>
                  </div>
                  <span style={{
                    ...styles.statusBadge,
                    backgroundColor: chw.status === 'Active' ? '#d1fae5' : '#fee2e2',
                    color: chw.status === 'Active' ? '#065f46' : '#991b1b',
                  }}>
                    {chw.status || 'Active'}
                  </span>
                </div>
                <div style={styles.cardBody}>
                  <div style={styles.infoRow}><span>📞 {chw.phoneNumber || 'N/A'}</span><span>👥 {chw.patientsCount || 0} patients</span></div>
                </div>
                <div style={styles.cardFooter}>
                  <button onClick={() => setSelectedChw(chw)} style={styles.viewButton}>View Details</button>
                  <button onClick={() => handleToggleStatus(chw)} style={styles.messageButton}>
                    {chw.status === 'Active' ? 'Deactivate' : 'Activate'}
                  </button>
                </div>
              </div>
            ))
          )}
        </div>

        {/* --- CHW DETAILS POP-UP --- */}
        {selectedChw && (
          <div style={styles.modalOverlay} onClick={() => setSelectedChw(null)}>
            <div style={styles.detailsModal} onClick={(e) => e.stopPropagation()}>
              <div style={styles.detailsHeader}>
                <div style={styles.detailsAvatar}>
                  {(selectedChw.displayName || '?')[0]}
                </div>
                <div>
                  <h2 style={styles.detailsName}>{selectedChw.displayName || 'CHW'}</h2>
                  <p style={styles.detailsSub}>📍 {selectedChw.address || 'N/A'}</p>
                </div>
                <button onClick={() => setSelectedChw(null)} style={styles.detailsClose}>×</button>
              </div>
              
              <div style={styles.detailsBody}>
                <div style={styles.detailsRow}>
                  <span>📧 Email:</span>
                  <span>{selectedChw.email || 'N/A'}</span>
                </div>
                <div style={styles.detailsRow}>
                  <span>📞 Phone:</span>
                  <span>{selectedChw.phoneNumber || 'N/A'}</span>
                </div>
                <div style={styles.detailsRow}>
                  <span>👥 Assigned Patients:</span>
                  <span style={{ fontWeight: 'bold', color: '#2563eb' }}>{selectedChw.patientsCount || 0}</span>
                </div>
                <div style={styles.detailsRow}>
                  <span>📊 Status:</span>
                  <span style={{ 
                    padding: '4px 12px',
                    borderRadius: '20px',
                    fontSize: '12px',
                    backgroundColor: selectedChw.status === 'Active' ? '#d1fae5' : '#fee2e2',
                    color: selectedChw.status === 'Active' ? '#065f46' : '#991b1b'
                  }}>
                    {selectedChw.status || 'Active'}
                  </span>
                </div>
              </div>

              <div style={styles.detailsFooter}>
                <button onClick={() => setSelectedChw(null)} style={styles.detailsCloseBtn}>Close</button>
                <button onClick={() => handleToggleStatus(selectedChw)} style={styles.detailsMsgBtn}>
                  {selectedChw.status === 'Active' ? 'Deactivate' : 'Activate'}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Add CHW Modal */}
        {showAddModal && (
          <div style={styles.modalOverlay} onClick={() => setShowAddModal(false)}>
            <div style={styles.modal} onClick={(e) => e.stopPropagation()}>
              <h3 style={styles.modalTitle}>Add New CHW</h3>
              <form onSubmit={handleAddCHW}>
                <div style={styles.formGroup}><label style={styles.label}>Full Name</label><input type="text" value={newChw.name} onChange={(e) => setNewChw({...newChw, name: e.target.value})} style={styles.input} required /></div>
                <div style={styles.formGroup}><label style={styles.label}>Email</label><input type="email" value={newChw.email} onChange={(e) => setNewChw({...newChw, email: e.target.value})} style={styles.input} required /></div>
                <div style={styles.formGroup}><label style={styles.label}>Phone Number</label><input type="tel" value={newChw.phone} onChange={(e) => setNewChw({...newChw, phone: e.target.value})} style={styles.input} required /></div>
                <div style={styles.formGroup}><label style={styles.label}>Address</label><input type="text" value={newChw.address} onChange={(e) => setNewChw({...newChw, address: e.target.value})} style={styles.input} required /></div>
                <div style={styles.modalActions}>
                  <button type="button" onClick={() => setShowAddModal(false)} style={styles.cancelButton}>Cancel</button>
                  <button type="submit" style={styles.submitButton}>Create CHW</button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
}

const styles = {
  container: { padding: '24px', backgroundColor: '#f9fafb', fontFamily: "'Segoe UI', Roboto, sans-serif" },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap' as const, gap: '16px' },
  pageTitle: { fontSize: '26px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  pageSubtitle: { color: '#666', marginTop: '8px', marginBottom: 0 },
  addButton: { backgroundColor: '#2563eb', color: 'white', padding: '10px 20px', border: 'none', borderRadius: '10px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' as const },
  statsGrid: { display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '20px', marginBottom: '24px' },
  statCard: { backgroundColor: 'white', padding: '20px', borderRadius: '14px', textAlign: 'center' as const, boxShadow: '0 2px 6px rgba(0,0,0,0.1)' },
  statValue: { fontSize: '32px', fontWeight: 'bold' as const, margin: 0, color: '#2563eb' },
  statLabel: { fontSize: '13px', color: '#666', margin: '8px 0 0' },
  searchContainer: { marginBottom: '24px' },
  searchInput: { width: '100%', maxWidth: '400px', padding: '12px 16px', border: '1px solid #e5e7eb', borderRadius: '10px', fontSize: '14px', outline: 'none' },
  cardsGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(360px, 1fr))', gap: '20px' },
  card: { backgroundColor: 'white', borderRadius: '14px', padding: '20px', boxShadow: '0 2px 6px rgba(0,0,0,0.1)' },
  cardHeader: { display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '16px' },
  avatar: { width: '52px', height: '52px', backgroundColor: '#2563eb', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' },
  avatarText: { color: 'white', fontSize: '22px', fontWeight: 'bold' as const },
  cardHeaderInfo: { flex: 1 },
  chwName: { fontSize: '18px', fontWeight: '600' as const, margin: 0, color: '#1a1a2e' },
  chwArea: { fontSize: '12px', color: '#666', margin: '4px 0 0' },
  cardBody: { marginBottom: '16px' },
  infoRow: { display: 'flex', justifyContent: 'space-between', marginBottom: '10px', fontSize: '13px', color: '#666' },
  statusBadge: { padding: '3px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: '500' as const },
  cardFooter: { display: 'flex', gap: '12px', paddingTop: '16px', borderTop: '1px solid #e5e7eb' },
  viewButton: { flex: 1, backgroundColor: '#f3f4f6', color: '#374151', padding: '8px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '13px' },
  messageButton: { flex: 1, backgroundColor: '#2563eb', color: 'white', padding: '8px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '13px' },
  modalOverlay: { position: 'fixed' as const, top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 },
  modal: { backgroundColor: 'white', borderRadius: '16px', padding: '28px', width: '90%', maxWidth: '500px' },
  modalTitle: { fontSize: '22px', fontWeight: 'bold' as const, margin: '0 0 20px 0', color: '#1a1a2e' },
  formGroup: { marginBottom: '18px' },
  label: { display: 'block', fontSize: '14px', fontWeight: '500' as const, color: '#333', marginBottom: '6px' },
  input: { width: '100%', padding: '12px', border: '1px solid #e5e7eb', borderRadius: '8px', fontSize: '14px', outline: 'none' },
  modalActions: { display: 'flex', gap: '12px', marginTop: '24px' },
  cancelButton: { flex: 1, backgroundColor: '#f3f4f6', color: '#374151', padding: '12px', border: 'none', borderRadius: '8px', cursor: 'pointer' },
  submitButton: { flex: 1, backgroundColor: '#2563eb', color: 'white', padding: '12px', border: 'none', borderRadius: '8px', cursor: 'pointer' },
  detailsModal: {
    backgroundColor: 'white',
    borderRadius: '20px',
    padding: '24px',
    width: '90%',
    maxWidth: '450px',
    boxShadow: '0 10px 30px rgba(0,0,0,0.2)',
    position: 'relative' as const,
  },
  detailsHeader: {
    display: 'flex',
    alignItems: 'center' as const,
    gap: '16px',
    marginBottom: '20px',
    paddingRight: '30px',
  },
  detailsAvatar: {
    width: '60px',
    height: '60px',
    backgroundColor: '#2563eb',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: 'white',
    fontSize: '24px',
    fontWeight: 'bold' as const,
  },
  detailsName: { fontSize: '20px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  detailsSub: { fontSize: '14px', color: '#666', margin: '4px 0 0' },
  detailsClose: {
    position: 'absolute' as const,
    top: '16px',
    right: '16px',
    background: 'none',
    border: 'none',
    fontSize: '24px',
    cursor: 'pointer',
    color: '#888',
  },
  detailsBody: { display: 'flex', flexDirection: 'column' as const, gap: '12px', marginBottom: '20px' },
  detailsRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '14px' },
  detailsFooter: { display: 'flex', gap: '12px' },
  detailsCloseBtn: { flex: 1, backgroundColor: '#f3f4f6', color: '#374151', padding: '12px', border: 'none', borderRadius: '8px', cursor: 'pointer' },
  detailsMsgBtn: { flex: 1, backgroundColor: '#2563eb', color: 'white', padding: '12px', border: 'none', borderRadius: '8px', cursor: 'pointer' },
};