import { useState, useEffect } from 'react';
import Papa from 'papaparse';
import { useRouter } from 'next/router';
import {
  onAuthStateChanged,
  sendPasswordResetEmail,
} from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import { createAuthUserWithoutSessionSwitch } from '../lib/createUser';
import { generateStrongTemporaryPassword } from '../lib/password';
import {
  collection,
  query,
  where,
  onSnapshot,
  Timestamp,
  getDocs,
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} from 'firebase/firestore';
import Layout from '../components/Layout';
import { DB_PATHS } from '../lib/dbPaths';

interface ChwRow {
  id: string;
  uid?: string;
  displayName?: string;
  name?: string;
  email?: string;
  phoneNumber?: string;
  address?: string;
  status?: string;
  role?: string | string[];
  patientsCount?: number;
  visitsToday?: number;
}

interface PatientRow {
  id: string;
  name?: string;
  age?: number;
  condition?: string;
  status?: string;
}

interface PatientInteractionRow {
  id: string;
  patientId?: string;
  patientName?: string;
  type?: string;
  summary?: string;
  details?: string;
  actorName?: string;
  relatedRecordId?: string;
  createdAt?: Timestamp | string;
  _createdMs: number;
}

export default function HomeBasedCare() {
  const router = useRouter();
  const [showAddModal, setShowAddModal] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [chws, setChws] = useState<ChwRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [chwsLoading, setChwsLoading] = useState(true);
  const [error, setError] = useState('');
  const [formError, setFormError] = useState('');
  const [selectedChw, setSelectedChw] = useState<ChwRow | null>(null);
  const [saving, setSaving] = useState(false);

  const [chwPatients, setChwPatients] = useState<PatientRow[]>([]);
  const [loadingPatients, setLoadingPatients] = useState(false);
  const [patientsError, setPatientsError] = useState('');
  const [interactions, setInteractions] = useState<PatientInteractionRow[]>([]);
  const [loadingInteractions, setLoadingInteractions] = useState(false);
  const [interactionsError, setInteractionsError] = useState('');

  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const [newChw, setNewChw] = useState({
    name: '',
    email: '',
    phone: '',
    address: '',
    area: '',
  });

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

  useEffect(() => {
    if (loading) return;
    const q = query(collection(db, DB_PATHS.users));
    const unsubscribe = onSnapshot(q, async (snapshot) => {
      try {
        const allUsers: ChwRow[] = snapshot.docs.map((d) => {
          const raw = d.data() as Record<string, unknown>;
          return {
            id: d.id,
            uid: raw.uid as string | undefined,
            displayName: raw.displayName as string | undefined,
            name: raw.name as string | undefined,
            email: raw.email as string | undefined,
            phoneNumber: raw.phoneNumber as string | undefined,
            address: raw.address as string | undefined,
            status: raw.status as string | undefined,
            role: raw.role as string | string[] | undefined,
            visitsToday: raw.visitsToday as number | undefined,
          };
        });

        const chwData = allUsers.filter((u) => {
          const role = u.role;
          if (typeof role === 'string') return role === 'chw';
          if (Array.isArray(role)) return role.includes('chw');
          return false;
        });

        const chwsWithPatients = await Promise.all(
          chwData.map(async (chw) => {
            try {
              const patientsQuery = query(
                collection(db, DB_PATHS.patients),
                where('assignedChwId', '==', chw.uid || chw.id)
              );
              const snap2 = await getDocs(patientsQuery);
              return { ...chw, patientsCount: snap2.size };
            } catch {
              return { ...chw, patientsCount: 0 };
            }
          })
        );
        setChws(chwsWithPatients);
        setChwsLoading(false);
        setError('');

        setSelectedChw((prev) => {
          if (!prev) return prev;
          return chwsWithPatients.find((c) => c.id === prev.id) || prev;
        });
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        setError('Failed to load CHWs: ' + message);
        setChwsLoading(false);
      }
    }, (e) => {
      const message = e instanceof Error ? e.message : String(e);
      setError('Failed to load CHWs: ' + message);
      setChwsLoading(false);
    });
    return () => unsubscribe();
  }, [loading]);

  // ---- Live patients for the selected CHW ----
  // setState is only called inside the onSnapshot callback, never
  // synchronously in the effect body. When no CHW is selected, the
  // effect early-returns without touching state.
  useEffect(() => {
    if (!selectedChw) return;

    const chwId = selectedChw.uid || selectedChw.id;
    const q = query(
      collection(db, DB_PATHS.patients),
      where('assignedChwId', '==', chwId)
    );

    const unsub = onSnapshot(q, (snap) => {
      setChwPatients(
        snap.docs.map((d) => {
          const raw = d.data() as Record<string, unknown>;
          return {
            id: d.id,
            name: raw.name as string | undefined,
            age: raw.age as number | undefined,
            condition: raw.condition as string | undefined,
            status: raw.status as string | undefined,
          };
        })
      );
      setLoadingPatients(false);
      setPatientsError('');
      setError('');
    }, (e) => {
      const message = e instanceof Error ? e.message : String(e);
      setPatientsError('Assigned patients could not be loaded.');
      setError('Failed to load assigned patients: ' + message);
      setLoadingPatients(false);
    });

    return () => unsub();
  }, [selectedChw]);

  useEffect(() => {
    if (!selectedChw) return;

    const chwId = selectedChw.uid || selectedChw.id;
    const unsubscribe = onSnapshot(
      query(
        collection(db, DB_PATHS.patientInteractions),
        where('chwIds', 'array-contains', chwId)
      ),
      (snapshot) => {
        const rows = snapshot.docs.map((d) => {
          const raw = d.data() as Record<string, unknown>;
          const date = raw.createdAt;
          const createdMs =
            date instanceof Timestamp
              ? date.toMillis()
              : typeof date === 'string'
                ? new Date(date).getTime()
                : 0;
          return {
            id: d.id,
            patientId: raw.patientId as string | undefined,
            patientName: raw.patientName as string | undefined,
            type: raw.type as string | undefined,
            summary: raw.summary as string | undefined,
            details: raw.details as string | undefined,
            actorName: raw.actorName as string | undefined,
            relatedRecordId: raw.relatedRecordId as string | undefined,
            createdAt: date as Timestamp | string | undefined,
            _createdMs: createdMs,
          };
        });
        rows.sort((a, b) => b._createdMs - a._createdMs);
        setInteractions(rows);
        setLoadingInteractions(false);
        setInteractionsError('');
      },
      (loadError) => {
        setInteractionsError(
          `Could not load patient interaction records: ${loadError.message}`
        );
        setLoadingInteractions(false);
      }
    );

    return () => unsubscribe();
  }, [selectedChw]);

  const filteredCHWs = chws.filter(
    (chw) =>
      (chw.displayName || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (chw.address || '').toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleExportChwCsv = () => {
    const rows = filteredCHWs.map((chw) => ({
      id: chw.id,
      uid: chw.uid ?? '',
      name: chw.displayName || chw.name || '',
      email: chw.email ?? '',
      phoneNumber: chw.phoneNumber ?? '',
      address: chw.address ?? '',
      status: chw.status ?? '',
      patientsCount: chw.patientsCount ?? 0,
      visitsToday: chw.visitsToday ?? 0,
    }));

    const csv = Papa.unparse(rows);
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `healthbridge-chws-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleExportInteractionsCsv = () => {
    const rows = interactions.map((interaction) => ({
      date: interaction._createdMs
        ? new Date(interaction._createdMs).toISOString()
        : '',
      patient: interaction.patientName ?? '',
      patientId: interaction.patientId ?? '',
      type: interaction.type ?? '',
      summary: interaction.summary ?? '',
      details: interaction.details ?? '',
      recordedBy: interaction.actorName ?? '',
      relatedRecordId: interaction.relatedRecordId ?? '',
    }));
    const csv = Papa.unparse(rows);
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `healthbridge-patient-interactions-${(selectedChw?.displayName || 'chw').toLowerCase().replace(/[^a-z0-9]+/g, '-')}-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const totalPatients = chws.reduce(
    (sum, chw) => sum + (chw.patientsCount || 0),
    0
  );
  const activeNow = chws.filter((c) => c.status === 'Active').length;

  const handleAddCHW = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');
    if (!newChw.name.trim()) return setFormError('Please enter the CHW name.');
    if (!newChw.email.trim())
      return setFormError('Please enter an email address.');
    if (!newChw.phone.trim())
      return setFormError('Please enter a phone number.');

    const tempPassword = generateStrongTemporaryPassword();

    setSaving(true);
    try {
      const uid = await createAuthUserWithoutSessionSwitch(
        newChw.email,
        tempPassword
      );

      await setDoc(doc(db, DB_PATHS.users, uid), {
        uid,
        role: ['chw'],
        displayName: newChw.name,
        email: newChw.email,
        phoneNumber: newChw.phone,
        address: newChw.address,
        status: 'Active',
      });

      await sendPasswordResetEmail(auth, newChw.email);
      alert(`CHW created. Password reset email sent to ${newChw.email}`);
      setNewChw({ name: '', email: '', phone: '', address: '', area: '' });
      setShowAddModal(false);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setFormError(message || 'Failed to create CHW.');
    } finally {
      setSaving(false);
    }
  };

  const handleToggleStatus = async (chw: ChwRow) => {
    const newStatus = chw.status === 'Active' ? 'Inactive' : 'Active';
    try {
      await updateDoc(doc(db, DB_PATHS.users, chw.id), { status: newStatus });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setError('Failed to update status: ' + message);
    }
  };

  const handleDeleteChw = async () => {
    if (!selectedChw) return;
    setDeleting(true);
    try {
      const chwId = selectedChw.uid || selectedChw.id;

      const q = query(
        collection(db, DB_PATHS.patients),
        where('assignedChwId', '==', chwId)
      );
      const snap = await getDocs(q);
      await Promise.all(
        snap.docs.map((d) =>
          updateDoc(doc(db, DB_PATHS.patients, d.id), {
            assignedChwId: null,
            assignedChwName: null,
            unassignedAt: serverTimestamp(),
            unassignedReason: `CHW deleted: ${
              selectedChw.displayName || selectedChw.name || chwId
            }`,
          })
        )
      );

      await deleteDoc(doc(db, DB_PATHS.users, selectedChw.id));

      setConfirmDelete(false);
      setSelectedChw(null);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      alert('Failed to delete CHW: ' + message);
    } finally {
      setDeleting(false);
    }
  };

  const getStatusStyle = (status: string) => {
    switch (status) {
      case 'Critical':
        return { backgroundColor: '#fee2e2', color: '#991b1b' };
      case 'Needs Follow-up':
        return { backgroundColor: '#fef3c7', color: '#92400e' };
      case 'Reviewed':
        return { backgroundColor: '#e0e7ff', color: '#3730a3' };
      default:
        return { backgroundColor: '#d1fae5', color: '#065f46' };
    }
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
        {error && (
          <div role="alert" style={styles.errorBanner}>
            <span>⚠️ {error}</span>
            <button onClick={() => setError('')} style={styles.errorClose} aria-label="Dismiss error">
              ×
            </button>
          </div>
        )}

        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Home-Based Care</h1>
            <p style={styles.pageSubtitle}>Manage Community Health Workers</p>
          </div>
          <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
            <button
              onClick={handleExportChwCsv}
              style={{
                ...styles.addButton,
                background: '#0f172a',
                padding: '10px 16px',
              }}
            >
              ⬇ Download CHW Info
            </button>
            <button
              onClick={() => setShowAddModal(true)}
              style={styles.addButton}
            >
              + Add CHW
            </button>
          </div>
        </div>

        <div style={styles.statsGrid}>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{chws.length}</p>
            <p style={styles.statLabel}>Total CHWs</p>
          </div>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{activeNow}</p>
            <p style={styles.statLabel}>Active Now</p>
          </div>
          <div style={styles.statCard}>
            <p style={styles.statValue}>
              {chws.reduce((sum, c) => sum + (c.visitsToday || 0), 0)}
            </p>
            <p style={styles.statLabel}>Visits Today</p>
          </div>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{totalPatients}</p>
            <p style={styles.statLabel}>Total Patients</p>
          </div>
        </div>

        <div style={styles.searchContainer}>
          <label htmlFor="chw-search" style={styles.visuallyHidden}>
            Search community health workers by name or area
          </label>
          <input
            id="chw-search"
            type="text"
            placeholder="🔍 Search CHW by name or area..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            maxLength={200}
            style={styles.searchInput}
          />
        </div>

        <div style={styles.cardsGrid}>
          {chwsLoading ? (
            <p role="status" style={styles.listMessage}>Loading community health workers…</p>
          ) : error.includes('Failed to load CHWs') ? (
            <p style={styles.listMessage}>Community health worker records are unavailable.</p>
          ) : filteredCHWs.length === 0 ? (
            <div
              style={{
                backgroundColor: 'white',
                padding: '40px',
                borderRadius: '12px',
                textAlign: 'center',
                color: '#4b5563',
              }}
            >
              {chws.length === 0
                ? 'No community health workers found.'
                : 'No community health workers match your search.'}
            </div>
          ) : (
            filteredCHWs.map((chw) => (
              <div
                key={chw.id}
                style={styles.card}
                onClick={() => {
                  setLoadingPatients(true);
                  setLoadingInteractions(true);
                  setInteractions([]);
                  setInteractionsError('');
                  setSelectedChw(chw);
                  setConfirmDelete(false);
                }}
                onMouseEnter={(e) => {
                  (e.currentTarget as HTMLDivElement).style.boxShadow =
                    '0 8px 20px rgba(0,0,0,0.15)';
                  (e.currentTarget as HTMLDivElement).style.transform =
                    'translateY(-2px)';
                }}
                onMouseLeave={(e) => {
                  (e.currentTarget as HTMLDivElement).style.boxShadow =
                    '0 2px 6px rgba(0,0,0,0.1)';
                  (e.currentTarget as HTMLDivElement).style.transform =
                    'translateY(0)';
                }}
              >
                <div style={styles.cardHeader}>
                  <div style={styles.avatar}>
                    <span style={styles.avatarText}>
                      {(chw.displayName || '?')[0]}
                    </span>
                  </div>
                  <div style={styles.cardHeaderInfo}>
                    <h3 style={styles.chwName}>
                      {chw.displayName || 'CHW'}
                    </h3>
                    <p style={styles.chwArea}>📍 {chw.address || 'N/A'}</p>
                  </div>
                  <span
                    style={{
                      ...styles.statusBadge,
                      backgroundColor:
                        chw.status === 'Active' ? '#d1fae5' : '#fee2e2',
                      color: chw.status === 'Active' ? '#065f46' : '#991b1b',
                    }}
                  >
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
                    onClick={(e) => {
                      e.stopPropagation();
                      setLoadingPatients(true);
                      setLoadingInteractions(true);
                      setInteractions([]);
                      setInteractionsError('');
                      setSelectedChw(chw);
                      setConfirmDelete(false);
                    }}
                    style={styles.viewButton}
                  >
                    View Details
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleToggleStatus(chw);
                    }}
                    style={styles.messageButton}
                  >
                    {chw.status === 'Active' ? 'Deactivate' : 'Activate'}
                  </button>
                </div>
              </div>
            ))
          )}
        </div>

        {/* CHW DETAILS MODAL */}
        {selectedChw && (
          <div
            style={styles.modalOverlay}
            onClick={() => {
              setSelectedChw(null);
              setConfirmDelete(false);
            }}
          >
            <div
              style={styles.detailsModal}
              onClick={(e) => e.stopPropagation()}
            >
              <div style={styles.detailsHeader}>
                <div style={styles.detailsAvatar}>
                  {(selectedChw.displayName || '?')[0]}
                </div>
                <div style={{ flex: 1 }}>
                  <h2 style={styles.detailsName}>
                    {selectedChw.displayName || 'CHW'}
                  </h2>
                  <p style={styles.detailsSub}>
                    📍 {selectedChw.address || 'N/A'}
                  </p>
                </div>
                <button
                  onClick={() => {
                    setSelectedChw(null);
                    setConfirmDelete(false);
                  }}
                  style={styles.detailsClose}
                >
                  ×
                </button>
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
                  <span style={{ fontWeight: 'bold', color: '#2563eb' }}>
                    {loadingPatients ? '…' : chwPatients.length}
                  </span>
                </div>
                <div style={styles.detailsRow}>
                  <span>📊 Status:</span>
                  <span
                    style={{
                      padding: '4px 12px',
                      borderRadius: '20px',
                      fontSize: '12px',
                      backgroundColor:
                        selectedChw.status === 'Active'
                          ? '#d1fae5'
                          : '#fee2e2',
                      color:
                        selectedChw.status === 'Active'
                          ? '#065f46'
                          : '#991b1b',
                    }}
                  >
                    {selectedChw.status || 'Active'}
                  </span>
                </div>
              </div>

              <div style={styles.patientsSection}>
                <div style={styles.patientsHeader}>
                  <h3 style={styles.patientsTitle}>Assigned Patients</h3>
                  {!loadingPatients && chwPatients.length > 0 && (
                    <span style={styles.patientsCount}>
                      {chwPatients.length}
                    </span>
                  )}
                </div>

                {loadingPatients ? (
                  <div role="status" style={styles.patientsEmpty}>Loading patients…</div>
                ) : patientsError ? (
                  <div role="alert" style={styles.patientsEmpty}>{patientsError}</div>
                ) : chwPatients.length === 0 ? (
                  <div style={styles.patientsEmpty}>
                    <p
                      style={{ margin: 0, fontWeight: 600, color: '#666' }}
                    >
                      No patients assigned
                    </p>
                    <p
                      style={{
                        margin: '6px 0 0',
                        fontSize: '12px',
                        color: '#999',
                      }}
                    >
                      Assign a patient from the Patients page.
                    </p>
                  </div>
                ) : (
                  <div style={styles.patientList}>
                    {chwPatients.map((p) => (
                      <div key={p.id} style={styles.patientRow}>
                        <div style={styles.patientAvatar}>
                          {(p.name || '?')[0]}
                        </div>
                        <div style={styles.patientInfo}>
                          <p style={styles.patientRowName}>
                            {p.name || 'Unknown'}
                          </p>
                          <p style={styles.patientRowMeta}>
                            {p.age ? `${p.age} yrs · ` : ''}
                            {p.condition || 'No condition'}
                          </p>
                        </div>
                        <span
                          style={{
                            ...styles.patientRowStatus,
                            ...getStatusStyle(p.status || 'Stable'),
                          }}
                        >
                          {p.status || 'Stable'}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <section
                aria-labelledby="interaction-history-title"
                style={styles.patientsSection}
              >
                <div style={styles.patientsHeader}>
                  <h3
                    id="interaction-history-title"
                    style={styles.patientsTitle}
                  >
                    Patient Interaction History
                  </h3>
                  <button
                    type="button"
                    onClick={handleExportInteractionsCsv}
                    disabled={interactions.length === 0}
                    style={{
                      ...styles.viewButton,
                      opacity: interactions.length === 0 ? 0.5 : 1,
                      cursor: interactions.length === 0 ? 'not-allowed' : 'pointer',
                    }}
                    aria-label="Download this CHW's patient interaction history as CSV"
                  >
                    Download CSV
                  </button>
                </div>
                <p
                  style={{
                    margin: '0 0 10px',
                    color: '#4b5563',
                    fontSize: '13px',
                  }}
                >
                  Patient visits, messages, calls, referrals, and emergency
                  responses.
                </p>
                {loadingInteractions ? (
                  <div role="status" style={styles.patientsEmpty}>
                    Loading interaction history…
                  </div>
                ) : interactionsError ? (
                  <div role="alert" style={styles.patientsEmpty}>
                    {interactionsError}
                  </div>
                ) : interactions.length === 0 ? (
                  <div style={styles.patientsEmpty}>
                    No interactions have been recorded for this CHW yet.
                  </div>
                ) : (
                  <ol
                    aria-label="Patient interaction records"
                    style={{
                      listStyle: 'none',
                      margin: 0,
                      padding: 0,
                      maxHeight: '260px',
                      overflowY: 'auto',
                    }}
                  >
                    {interactions.map((interaction) => (
                      <li
                        key={interaction.id}
                        style={{
                          padding: '10px 0',
                          borderBottom: '1px solid #e5e7eb',
                        }}
                      >
                        <div
                          style={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            gap: '10px',
                          }}
                        >
                          <strong style={{ color: '#1f2937' }}>
                            {interaction.patientName || 'Unknown patient'}
                          </strong>
                          <span style={{ color: '#4b5563', fontSize: '12px' }}>
                            {interaction._createdMs
                              ? new Date(interaction._createdMs).toLocaleString()
                              : 'Time unavailable'}
                          </span>
                        </div>
                        <div style={{ color: '#1f2937', marginTop: '4px' }}>
                          <b>{interaction.type || 'Interaction'}:</b>{' '}
                          {interaction.summary || 'Interaction recorded'}
                        </div>
                        {interaction.details && (
                          <p
                            style={{
                              margin: '4px 0 0',
                              color: '#374151',
                              whiteSpace: 'pre-wrap',
                            }}
                          >
                            {interaction.details}
                          </p>
                        )}
                      </li>
                    ))}
                  </ol>
                )}
              </section>

              {confirmDelete ? (
                <div style={styles.confirmDeleteBox}>
                  <p style={styles.confirmDeleteText}>
                    Delete <b>{selectedChw.displayName || 'this CHW'}</b>? Their{' '}
                    {chwPatients.length} patient
                    {chwPatients.length === 1 ? '' : 's'} will become
                    unassigned and you&apos;ll need to reassign them.
                  </p>
                  <div style={styles.confirmDeleteActions}>
                    <button
                      style={styles.detailsCloseBtn}
                      onClick={() => setConfirmDelete(false)}
                      disabled={deleting}
                    >
                      Cancel
                    </button>
                    <button
                      style={styles.deleteConfirmBtn}
                      onClick={handleDeleteChw}
                      disabled={deleting}
                    >
                      {deleting ? 'Deleting…' : 'Yes, delete CHW'}
                    </button>
                  </div>
                </div>
              ) : (
                <div style={styles.detailsFooter}>
                  <button
                    style={styles.deleteButton}
                    onClick={() => setConfirmDelete(true)}
                  >
                    🗑 Delete CHW
                  </button>
                  <button
                    onClick={() => {
                      setSelectedChw(null);
                      router.push('/patients');
                    }}
                    style={styles.detailsMsgBtn}
                  >
                    Go to Patients →
                  </button>
                </div>
              )}
            </div>
          </div>
        )}

        {/* ADD CHW MODAL */}
        {showAddModal && (
          <div
            style={styles.modalOverlay}
            onClick={() => !saving && setShowAddModal(false)}
          >
            <div
              style={styles.modal}
              onClick={(e) => e.stopPropagation()}
            >
              <h3 style={styles.modalTitle}>Add New CHW</h3>
              {formError && <div style={styles.errorBox}>{formError}</div>}
              <form onSubmit={handleAddCHW}>
                <div style={styles.formGroup}>
                  <label style={styles.label}>Full Name</label>
                  <input
                    type="text"
                    value={newChw.name}
                    onChange={(e) =>
                      setNewChw({ ...newChw, name: e.target.value })
                    }
                    maxLength={100}
                    style={styles.input}
                    required
                  />
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.label}>Email</label>
                  <input
                    type="email"
                    value={newChw.email}
                    onChange={(e) =>
                      setNewChw({ ...newChw, email: e.target.value })
                    }
                    maxLength={254}
                    style={styles.input}
                    required
                  />
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.label}>Phone Number</label>
                  <input
                    type="tel"
                    value={newChw.phone}
                    onChange={(e) =>
                      setNewChw({ ...newChw, phone: e.target.value })
                    }
                    maxLength={15}
                    style={styles.input}
                    required
                  />
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.label}>Address</label>
                  <input
                    type="text"
                    value={newChw.address}
                    onChange={(e) =>
                      setNewChw({ ...newChw, address: e.target.value })
                    }
                    maxLength={200}
                    style={styles.input}
                    required
                  />
                </div>
                <div style={styles.modalActions}>
                  <button
                    type="button"
                    onClick={() => !saving && setShowAddModal(false)}
                    style={styles.cancelButton}
                    disabled={saving}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    style={styles.submitButton}
                    disabled={saving}
                  >
                    {saving ? 'Creating...' : 'Create CHW'}
                  </button>
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
  container: {
    padding: '24px',
    backgroundColor: '#f9fafb',
    fontFamily: "'Segoe UI', Roboto, sans-serif",
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '24px',
    flexWrap: 'wrap' as const,
    gap: '16px',
  },
  pageTitle: {
    fontSize: '26px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  pageSubtitle: { color: '#666', marginTop: '8px', marginBottom: 0 },
  addButton: {
    backgroundColor: '#2563eb',
    color: 'white',
    padding: '10px 20px',
    border: 'none',
    borderRadius: '10px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: '500' as const,
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(4, 1fr)',
    gap: '20px',
    marginBottom: '24px',
  },
  statCard: {
    backgroundColor: 'white',
    padding: '20px',
    borderRadius: '14px',
    textAlign: 'center' as const,
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
  },
  statValue: {
    fontSize: '32px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#2563eb',
  },
  statLabel: { fontSize: '13px', color: '#666', margin: '8px 0 0' },
  searchContainer: { marginBottom: '24px' },
  searchInput: {
    width: '100%',
    maxWidth: '400px',
    padding: '12px 16px',
    border: '1px solid #e5e7eb',
    borderRadius: '10px',
    fontSize: '14px',
    outline: 'none',
  },
  visuallyHidden: {
    position: 'absolute' as const,
    width: '1px',
    height: '1px',
    padding: 0,
    margin: '-1px',
    overflow: 'hidden' as const,
    clip: 'rect(0, 0, 0, 0)',
    whiteSpace: 'nowrap' as const,
    border: 0,
  },
  listMessage: {
    gridColumn: '1 / -1',
    textAlign: 'center' as const,
    padding: '40px',
    color: '#4b5563',
  },
  cardsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(360px, 1fr))',
    gap: '20px',
  },
  card: {
    backgroundColor: 'white',
    borderRadius: '14px',
    padding: '20px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    cursor: 'pointer',
    transition: 'box-shadow 0.2s ease, transform 0.2s ease',
  },
  cardHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: '14px',
    marginBottom: '16px',
  },
  avatar: {
    width: '52px',
    height: '52px',
    backgroundColor: '#2563eb',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: 'white',
    fontSize: '22px',
    fontWeight: 'bold' as const,
  },
  cardHeaderInfo: { flex: 1 },
  chwName: {
    fontSize: '18px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  chwArea: { fontSize: '12px', color: '#666', margin: '4px 0 0' },
  cardBody: { marginBottom: '16px' },
  infoRow: {
    display: 'flex',
    justifyContent: 'space-between',
    marginBottom: '10px',
    fontSize: '13px',
    color: '#666',
  },
  statusBadge: {
    padding: '3px 10px',
    borderRadius: '20px',
    fontSize: '11px',
    fontWeight: '500' as const,
  },
  cardFooter: {
    display: 'flex',
    gap: '12px',
    paddingTop: '16px',
    borderTop: '1px solid #e5e7eb',
  },
  viewButton: {
    flex: 1,
    backgroundColor: '#f3f4f6',
    color: '#374151',
    padding: '8px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '13px',
  },
  messageButton: {
    flex: 1,
    backgroundColor: '#2563eb',
    color: 'white',
    padding: '8px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '13px',
  },
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
    padding: '20px',
  },
  modal: {
    backgroundColor: 'white',
    borderRadius: '16px',
    padding: '28px',
    width: '90%',
    maxWidth: '500px',
  },
  modalTitle: {
    fontSize: '22px',
    fontWeight: 'bold' as const,
    margin: '0 0 20px 0',
    color: '#1a1a2e',
  },
  formGroup: { marginBottom: '18px' },
  label: {
    display: 'block',
    fontSize: '14px',
    fontWeight: '500' as const,
    color: '#333',
    marginBottom: '6px',
  },
  input: {
    width: '100%',
    padding: '12px',
    border: '1px solid #e5e7eb',
    borderRadius: '8px',
    fontSize: '14px',
    outline: 'none',
  },
  modalActions: { display: 'flex', gap: '12px', marginTop: '24px' },
  cancelButton: {
    flex: 1,
    backgroundColor: '#f3f4f6',
    color: '#374151',
    padding: '12px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
  },
  submitButton: {
    flex: 1,
    backgroundColor: '#2563eb',
    color: 'white',
    padding: '12px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
  },
  errorBox: {
    backgroundColor: '#fee2e2',
    color: '#991b1b',
    padding: '10px 14px',
    borderRadius: '8px',
    marginBottom: '16px',
    fontSize: '13px',
    border: '1px solid #fecaca',
  },
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
  detailsModal: {
    backgroundColor: 'white',
    borderRadius: '20px',
    padding: '24px',
    width: '90%',
    maxWidth: '520px',
    maxHeight: '90vh',
    overflowY: 'auto' as const,
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
  detailsName: {
    fontSize: '20px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#1a1a2e',
  },
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
  detailsBody: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '12px',
    marginBottom: '20px',
  },
  detailsRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    fontSize: '14px',
  },
  detailsFooter: {
    display: 'flex',
    gap: '10px',
    marginTop: '20px',
    justifyContent: 'space-between',
  },
  detailsCloseBtn: {
    backgroundColor: '#f3f4f6',
    color: '#374151',
    padding: '10px 20px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '13px',
  },
  detailsMsgBtn: {
    backgroundColor: '#2563eb',
    color: 'white',
    padding: '10px 18px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '13px',
  },
  deleteButton: {
    backgroundColor: '#fff',
    color: '#dc2626',
    padding: '10px 18px',
    border: '1px solid #fecaca',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: '600' as const,
  },
  confirmDeleteBox: {
    marginTop: '20px',
    padding: '16px',
    backgroundColor: '#fef2f2',
    border: '1px solid #fecaca',
    borderRadius: '12px',
  },
  confirmDeleteText: {
    fontSize: '13px',
    color: '#7f1d1d',
    margin: '0 0 12px 0',
    lineHeight: 1.5,
  },
  confirmDeleteActions: {
    display: 'flex',
    gap: '10px',
    justifyContent: 'flex-end',
  },
  deleteConfirmBtn: {
    backgroundColor: '#dc2626',
    color: 'white',
    padding: '10px 20px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: '600' as const,
  },
  patientsSection: {
    borderTop: '1px solid #e5e7eb',
    paddingTop: '16px',
    marginTop: '8px',
  },
  patientsHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '12px',
  },
  patientsTitle: {
    fontSize: '15px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  patientsCount: {
    backgroundColor: '#dbeafe',
    color: '#1e40af',
    padding: '2px 10px',
    borderRadius: '12px',
    fontSize: '12px',
    fontWeight: '600' as const,
  },
  patientsEmpty: {
    padding: '20px',
    textAlign: 'center' as const,
    backgroundColor: '#f9fafb',
    borderRadius: '10px',
    fontSize: '13px',
    color: '#888',
  },
  patientList: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '8px',
    maxHeight: '280px',
    overflowY: 'auto' as const,
    paddingRight: '4px',
  },
  patientRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    padding: '10px 12px',
    backgroundColor: '#f9fafb',
    borderRadius: '10px',
    border: '1px solid #f0f0f0',
  },
  patientAvatar: {
    width: '36px',
    height: '36px',
    backgroundColor: '#10b981',
    color: 'white',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '14px',
    fontWeight: 'bold' as const,
    flexShrink: 0,
  },
  patientInfo: { flex: 1, minWidth: 0 },
  patientRowName: {
    fontSize: '14px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#1a1a2e',
    whiteSpace: 'nowrap' as const,
    overflow: 'hidden' as const,
    textOverflow: 'ellipsis' as const,
  },
  patientRowMeta: {
    fontSize: '12px',
    color: '#666',
    margin: '2px 0 0',
    whiteSpace: 'nowrap' as const,
    overflow: 'hidden' as const,
    textOverflow: 'ellipsis' as const,
  },
  patientRowStatus: {
    padding: '3px 10px',
    borderRadius: '20px',
    fontSize: '11px',
    fontWeight: '600' as const,
    whiteSpace: 'nowrap' as const,
    flexShrink: 0,
  },
};