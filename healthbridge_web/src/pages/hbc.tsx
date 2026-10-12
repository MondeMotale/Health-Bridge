import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged, createUserWithEmailAndPassword, sendPasswordResetEmail, signInWithEmailAndPassword } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import {
  collection, query, where, onSnapshot, getDocs, doc, setDoc,
  updateDoc, deleteDoc, serverTimestamp,
} from 'firebase/firestore';
import Layout from '../components/Layout';

export default function HomeBasedCare() {
  const router = useRouter();
  const [showAddModal, setShowAddModal] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [chws, setChws] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [formError, setFormError] = useState('');
  const [selectedChw, setSelectedChw] = useState<any>(null);
  const [saving, setSaving] = useState(false);

  const [chwPatients, setChwPatients] = useState<any[]>([]);
  const [loadingPatients, setLoadingPatients] = useState(false);

  // Delete
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const [newChw, setNewChw] = useState({
    name: '', email: '', phone: '', address: '', area: '',
  });

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (!user) { router.push('/login'); return; }
      setLoading(false);
    });
    return () => unsubscribe();
  }, [router]);

  useEffect(() => {
    if (loading) return;
    const q = query(collection(db, 'users'));
    const unsubscribe = onSnapshot(q, async (snapshot) => {
      try {
        const allUsers = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
        const chwData = allUsers.filter((u: any) => {
          const role = u.role;
          if (typeof role === 'string') return role === 'chw';
          if (Array.isArray(role)) return role.includes('chw');
          return false;
        });

        const chwsWithPatients = await Promise.all(
          chwData.map(async (chw) => {
            try {
              const patientsQuery = query(
                collection(db, 'patients'),
                where('assignedChwId', '==', (chw as any).uid || (chw as any).id)
              );
              const snap2 = await getDocs(patientsQuery);
              return { ...chw, patientsCount: snap2.size };
            } catch {
              return { ...chw, patientsCount: 0 };
            }
          })
        );
        setChws(chwsWithPatients);

        setSelectedChw((prev: any) => {
          if (!prev) return prev;
          return chwsWithPatients.find((c) => c.id === prev.id) || prev;
        });
      } catch (e) {
        setError('Failed to load CHWs: ' + (e as any).message);
      }
    });
    return () => unsubscribe();
  }, [loading]);

  useEffect(() => {
    if (!selectedChw) { setChwPatients([]); return; }
    setLoadingPatients(true);
    const chwId = selectedChw.uid || selectedChw.id;
    const q = query(collection(db, 'patients'), where('assignedChwId', '==', chwId));
    const unsub = onSnapshot(q, (snap) => {
      setChwPatients(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
      setLoadingPatients(false);
    });
    return () => unsub();
  }, [selectedChw]);

  const filteredCHWs = chws.filter(
    (chw) =>
      (chw.displayName || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (chw.address || '').toLowerCase().includes(searchTerm.toLowerCase())
  );

  const totalPatients = chws.reduce((sum, chw) => sum + (chw.patientsCount || 0), 0);
  const activeNow = chws.filter((c) => c.status === 'Active').length;

  const handleAddCHW = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');
    if (!newChw.name.trim()) return setFormError('Please enter the CHW name.');
    if (!newChw.email.trim()) return setFormError('Please enter an email address.');
    if (!newChw.phone.trim()) return setFormError('Please enter a phone number.');

    const adminEmail = auth.currentUser?.email || '';
    const adminPassword = 'Admin@123';
    const tempPassword = 'HealthBridge@123';

    setSaving(true);
    try {
      const userCredential = await createUserWithEmailAndPassword(auth, newChw.email, tempPassword);
      const uid = userCredential.user.uid;

      await setDoc(doc(db, 'users', uid), {
        uid,
        role: ['chw'],
        displayName: newChw.name,
        email: newChw.email,
        phoneNumber: newChw.phone,
        address: newChw.address,
        status: 'Active',
      });

      if (adminEmail) {
        try { await signInWithEmailAndPassword(auth, adminEmail, adminPassword); }
        catch (loginErr) { console.warn('Failed to re-login admin:', loginErr); }
      }

      setTimeout(async () => {
        try {
          const origin =
            typeof window !== 'undefined'
              ? window.location.origin
              : 'https://health-bridge-git-main-mondemotale.vercel.app';
          await sendPasswordResetEmail(auth, newChw.email, {
            url: `${origin}/reset-password`,
            handleCodeInApp: false,
          });
          alert(`CHW created. Password reset email sent to ${newChw.email}`);
        } catch {
          alert('CHW created, but password reset email failed.');
        }
        setNewChw({ name: '', email: '', phone: '', address: '', area: '' });
        setShowAddModal(false);
      }, 3000);
    } catch (err: any) {
      setFormError(err.message || 'Failed to create CHW.');
    } finally {
      setSaving(false);
    }
  };

  const handleToggleStatus = async (chw: any) => {
    const newStatus = chw.status === 'Active' ? 'Inactive' : 'Active';
    try {
      await updateDoc(doc(db, 'users', chw.id), { status: newStatus });
    } catch (error) {
      setError('Failed to update status: ' + (error as any).message);
    }
  };

  const handleDeleteChw = async () => {
    if (!selectedChw) return;
    setDeleting(true);
    try {
      const chwId = selectedChw.uid || selectedChw.id;

      const q = query(collection(db, 'patients'), where('assignedChwId', '==', chwId));
      const snap = await getDocs(q);
      await Promise.all(
        snap.docs.map((d) =>
          updateDoc(doc(db, 'patients', d.id), {
            assignedChwId: null,
            assignedChwName: null,
            unassignedAt: serverTimestamp(),
            unassignedReason: `CHW deleted: ${selectedChw.displayName || selectedChw.name || chwId}`,
          })
        )
      );

      await deleteDoc(doc(db, 'users', selectedChw.id));

      setConfirmDelete(false);
      setSelectedChw(null);
    } catch (err) {
      alert('Failed to delete CHW: ' + (err as any).message);
    } finally {
      setDeleting(false);
    }
  };

  const getStatusStyle = (status: string) => {
    switch (status) {
      case 'Critical': return { backgroundColor: '#fee2e2', color: '#991b1b' };
      case 'Needs Follow-up': return { backgroundColor: '#fef3c7', color: '#92400e' };
      case 'Reviewed': return { backgroundColor: '#e0e7ff', color: '#3730a3' };
      default: return { backgroundColor: '#d1fae5', color: '#065f46' };
    }
  };

  if (loading) {
    return <div style={{ display: 'flex', justifyContent: 'center', padding: '50px' }}>Loading CHWs...</div>;
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
          <input type="text" placeholder="🔍 Search CHW by name or area..."
            value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)}
            style={styles.searchInput} />
        </div>

        <div style={styles.cardsGrid}>
          {filteredCHWs.length === 0 ? (
            <div style={{ backgroundColor: 'white', padding: '40px', borderRadius: '12px', textAlign: 'center', color: '#888' }}>
              No CHWs found.
            </div>
          ) : (
            filteredCHWs.map((chw) => (
              <div
                key={chw.id}
                style={styles.card}
                onClick={() => { setSelectedChw(chw); setConfirmDelete(false); }}
                onMouseEnter={(e) => {
                  (e.currentTarget as HTMLDivElement).style.boxShadow = '0 8px 20px rgba(0,0,0,0.15)';
                  (e.currentTarget as HTMLDivElement).style.transform = 'translateY(-2px)';
                }}
                onMouseLeave={(e) => {
                  (e.currentTarget as HTMLDivElement).style.boxShadow = '0 2px 6px rgba(0,0,0,0.1)';
                  (e.currentTarget as HTMLDivElement).style.transform = 'translateY(0)';
                }}
              >
                <div style={styles.cardHeader}>
                  <div style={styles.avatar}>
                    <span style={styles.avatarText}>{(chw.displayName || '?')[0]}</span>
                  </div>
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
                  <div style={styles.infoRow}>
                    <span>📞 {chw.phoneNumber || 'N/A'}</span>
                    <span>👥 {chw.patientsCount || 0} patients</span>
                  </div>
                </div>
                <div style={styles.cardFooter}>
                  <button
                    onClick={(e) => { e.stopPropagation(); setSelectedChw(chw); setConfirmDelete(false); }}
                    style={styles.viewButton}
                  >
                    View Details
                  </button>
                  <button
                    onClick={(e) => { e.stopPropagation(); handleToggleStatus(chw); }}
                    style={styles.messageButton}
                  >
                    {chw.status === 'Active' ? 'Deactivate' : 'Activate'}
                  </button>
                </div>
              </div>
            ))
          )}
        </div>

        {selectedChw && (
          <div style={styles.modalOverlay} onClick={() => { setSelectedChw(null); setConfirmDelete(false); }}>
            <div style={styles.detailsModal} onClick={(e) => e.stopPropagation()}>
              <div style={styles.detailsHeader}>
                <div style={styles.detailsAvatar}>{(selectedChw.displayName || '?')[0]}</div>
                <div style={{ flex: 1 }}>
                  <h2 style={styles.detailsName}>{selectedChw.displayName || 'CHW'}</h2>
                  <p style={styles.detailsSub}>📍 {selectedChw.address || 'N/A'}</p>
                </div>
                <button onClick={() => { setSelectedChw(null); setConfirmDelete(false); }} style={styles.detailsClose}>×</button>
              </div>

              <div style={styles.detailsBody}>
                <div style={styles.detailsRow}><span>📧 Email:</span><span>{selectedChw.email || 'N/A'}</span></div>
                <div style={styles.detailsRow}><span>📞 Phone:</span><span>{selectedChw.phoneNumber || 'N/A'}</span></div>
                <div style={styles.detailsRow}>
                  <span>👥 Assigned Patients:</span>
                  <span style={{ fontWeight: 'bold', color: '#2563eb' }}>
                    {loadingPatients ? '…' : chwPatients.length}
                  </span>
                </div>
                <div style={styles.detailsRow}>
                  <span>📊 Status:</span>
                  <span style={{
                    padding: '4px 12px',
                    borderRadius: '20px',
                    fontSize: '12px',
                    backgroundColor: selectedChw.status === 'Active' ? '#d1fae5' : '#fee2e2',
                    color: selectedChw.status === 'Active' ? '#065f46' : '#991b1b',
                  }}>
                    {selectedChw.status || 'Active'}
                  </span>
                </div>
              </div>

              <div style={styles.patientsSection}>
                <div style={styles.patientsHeader}>
                  <h3 style={styles.patientsTitle}>Assigned Patients</h3>
                  {!loadingPatients && chwPatients.length > 0 && (
                    <span style={styles.patientsCount}>{chwPatients.length}</span>
                  )}
                </div>

                {loadingPatients ? (
                  <div style={styles.patientsEmpty}>Loading patients…</div>
                ) : chwPatients.length === 0 ? (
                  <div style={styles.patientsEmpty}>
                    <p style={{ margin: 0, fontWeight: 600, color: '#666' }}>No patients assigned</p>
                    <p style={{ margin: '6px 0 0', fontSize: '12px', color: '#999' }}>
                      Assign a patient from the Patients page.
                    </p>
                  </div>
                ) : (
                  <div style={styles.patientList}>
                    {chwPatients.map((p) => (
                      <div key={p.id} style={styles.patientRow}>
                        <div style={styles.patientAvatar}>{(p.name || '?')[0]}</div>
                        <div style={styles.patientInfo}>
                          <p style={styles.patientRowName}>{p.name || 'Unknown'}</p>
                          <p style={styles.patientRowMeta}>
                            {p.age ? `${p.age} yrs · ` : ''}{p.condition || 'No condition'}
                          </p>
                        </div>
                        <span style={{ ...styles.patientRowStatus, ...getStatusStyle(p.status || 'Stable') }}>
                          {p.status || 'Stable'}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {confirmDelete ? (
                <div style={styles.confirmDeleteBox}>
                  <p style={styles.confirmDeleteText}>
                    Delete <b>{selectedChw.displayName || 'this CHW'}</b>?{' '}
                    Their {chwPatients.length} patient{chwPatients.length === 1 ? '' : 's'} will
                    become unassigned and you&apos;ll need to reassign them.
                  </p>
                  <div style={styles.confirmDeleteActions}>
                    <button style={styles.detailsCloseBtn} onClick={() => setConfirmDelete(false)} disabled={deleting}>
                      Cancel
                    </button>
                    <button style={styles.deleteConfirmBtn} onClick={handleDeleteChw} disabled={deleting}>
                      {deleting ? 'Deleting…' : 'Yes, delete CHW'}
                    </button>
                  </div>
                </div>
              ) : (
                <div style={styles.detailsFooter}>
                  <button style={styles.deleteButton} onClick={() => setConfirmDelete(true)}>
                    🗑 Delete CHW
                  </button>
                  <button
                    onClick={() => { setSelectedChw(null); router.push('/patients'); }}
                    style={styles.detailsMsgBtn}
                  >
                    Go to Patients →
                  </button>
                </div>
              )}
            </div>
          </div>
        )}

        {showAddModal && (
          <div style={styles.modalOverlay} onClick={() => !saving && setShowAddModal(false)}>
            <div style={styles.modal} onClick={(e) => e.stopPropagation()}>
              <h3 style={styles.modalTitle}>Add New CHW</h3>
              {formError && <div style={styles.errorBox}>{formError}</div>}
              <form onSubmit={handleAddCHW}>
                <div style={styles.formGroup}><label style={styles.label}>Full Name</label><input type="text" value={newChw.name} onChange={(e) => setNewChw({ ...newChw, name: e.target.value })} style={styles.input} required /></div>
                <div style={styles.formGroup}><label style={styles.label}>Email</label><input type="email" value={newChw.email} onChange={(e) => setNewChw({ ...newChw, email: e.target.value })} style={styles.input} required /></div>
                <div style={styles.formGroup}><label style={styles.label}>Phone Number</label><input type="tel" value={newChw.phone} onChange={(e) => setNewChw({ ...newChw, phone: e.target.value })} style={styles.input} required /></div>
                <div style={styles.formGroup}><label style={styles.label}>Address</label><input type="text" value={newChw.address} onChange={(e) => setNewChw({ ...newChw, address: e.target.value })} style={styles.input} required /></div>
                <div style={styles.modalActions}>
                  <button type="button" onClick={() => !saving && setShowAddModal(false)} style={styles.cancelButton} disabled={saving}>Cancel</button>
                  <button type="submit" style={styles.submitButton} disabled={saving}>{saving ? 'Creating...' : 'Create CHW'}</button>
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
  card: { backgroundColor: 'white', borderRadius: '14px', padding: '20px', boxShadow: '0 2px 6px rgba(0,0,0,0.1)', cursor: 'pointer', transition: 'box-shadow 0.2s ease, transform 0.2s ease' },
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
  modalOverlay: { position: 'fixed' as const, top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px' },
  modal: { backgroundColor: 'white', borderRadius: '16px', padding: '28px', width: '90%', maxWidth: '500px' },
  modalTitle: { fontSize: '22px', fontWeight: 'bold' as const, margin: '0 0 20px 0', color: '#1a1a2e' },
  formGroup: { marginBottom: '18px' },
  label: { display: 'block', fontSize: '14px', fontWeight: '500' as const, color: '#333', marginBottom: '6px' },
  input: { width: '100%', padding: '12px', border: '1px solid #e5e7eb', borderRadius: '8px', fontSize: '14px', outline: 'none' },
  modalActions: { display: 'flex', gap: '12px', marginTop: '24px' },
  cancelButton: { flex: 1, backgroundColor: '#f3f4f6', color: '#374151', padding: '12px', border: 'none', borderRadius: '8px', cursor: 'pointer' },
  submitButton: { flex: 1, backgroundColor: '#2563eb', color: 'white', padding: '12px', border: 'none', borderRadius: '8px', cursor: 'pointer' },
  errorBox: { backgroundColor: '#fee2e2', color: '#991b1b', padding: '10px 14px', borderRadius: '8px', marginBottom: '16px', fontSize: '13px', border: '1px solid #fecaca' },
  errorBanner: { backgroundColor: '#fee2e2', color: '#991b1b', padding: '10px 14px', borderRadius: '8px', marginBottom: '16px', fontSize: '13px', border: '1px solid #fecaca', display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  errorClose: { background: 'none', border: 'none', fontSize: '18px', cursor: 'pointer', color: '#991b1b' },

  detailsModal: { backgroundColor: 'white', borderRadius: '20px', padding: '24px', width: '90%', maxWidth: '520px', maxHeight: '90vh', overflowY: 'auto' as const, boxShadow: '0 10px 30px rgba(0,0,0,0.2)', position: 'relative' as const },
  detailsHeader: { display: 'flex', alignItems: 'center' as const, gap: '16px', marginBottom: '20px', paddingRight: '30px' },
  detailsAvatar: { width: '60px', height: '60px', backgroundColor: '#2563eb', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: '24px', fontWeight: 'bold' as const },
  detailsName: { fontSize: '20px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  detailsSub: { fontSize: '14px', color: '#666', margin: '4px 0 0' },
  detailsClose: { position: 'absolute' as const, top: '16px', right: '16px', background: 'none', border: 'none', fontSize: '24px', cursor: 'pointer', color: '#888' },
  detailsBody: { display: 'flex', flexDirection: 'column' as const, gap: '12px', marginBottom: '20px' },
  detailsRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '14px' },
  detailsFooter: { display: 'flex', gap: '10px', marginTop: '20px', justifyContent: 'space-between' },
  detailsCloseBtn: { backgroundColor: '#f3f4f6', color: '#374151', padding: '10px 20px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '13px' },
  detailsMsgBtn: { backgroundColor: '#2563eb', color: 'white', padding: '10px 18px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '13px' },

  deleteButton: { backgroundColor: '#fff', color: '#dc2626', padding: '10px 18px', border: '1px solid #fecaca', borderRadius: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: '600' as const },
  confirmDeleteBox: { marginTop: '20px', padding: '16px', backgroundColor: '#fef2f2', border: '1px solid #fecaca', borderRadius: '12px' },
  confirmDeleteText: { fontSize: '13px', color: '#7f1d1d', margin: '0 0 12px 0', lineHeight: 1.5 },
  confirmDeleteActions: { display: 'flex', gap: '10px', justifyContent: 'flex-end' },
  deleteConfirmBtn: { backgroundColor: '#dc2626', color: 'white', padding: '10px 20px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: '600' as const },

  patientsSection: { borderTop: '1px solid #e5e7eb', paddingTop: '16px', marginTop: '8px' },
  patientsHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' },
  patientsTitle: { fontSize: '15px', fontWeight: '600' as const, margin: 0, color: '#1a1a2e' },
  patientsCount: { backgroundColor: '#dbeafe', color: '#1e40af', padding: '2px 10px', borderRadius: '12px', fontSize: '12px', fontWeight: '600' as const },
  patientsEmpty: { padding: '20px', textAlign: 'center' as const, backgroundColor: '#f9fafb', borderRadius: '10px', fontSize: '13px', color: '#888' },
  patientList: { display: 'flex', flexDirection: 'column' as const, gap: '8px', maxHeight: '280px', overflowY: 'auto' as const, paddingRight: '4px' },
  patientRow: { display: 'flex', alignItems: 'center', gap: '12px', padding: '10px 12px', backgroundColor: '#f9fafb', borderRadius: '10px', border: '1px solid #f0f0f0' },
  patientAvatar: { width: '36px', height: '36px', backgroundColor: '#10b981', color: 'white', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '14px', fontWeight: 'bold' as const, flexShrink: 0 },
  patientInfo: { flex: 1, minWidth: 0 },
  patientRowName: { fontSize: '14px', fontWeight: '600' as const, margin: 0, color: '#1a1a2e', whiteSpace: 'nowrap' as const, overflow: 'hidden' as const, textOverflow: 'ellipsis' as const },
  patientRowMeta: { fontSize: '12px', color: '#666', margin: '2px 0 0', whiteSpace: 'nowrap' as const, overflow: 'hidden' as const, textOverflow: 'ellipsis' as const },
  patientRowStatus: { padding: '3px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: '600' as const, whiteSpace: 'nowrap' as const, flexShrink: 0 },
};