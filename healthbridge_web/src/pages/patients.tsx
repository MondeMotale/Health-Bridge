import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import {
  collection,
  query,
  onSnapshot,
  orderBy,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  serverTimestamp,
} from 'firebase/firestore';
import Layout from '../components/Layout';
import DiagnosisSelect from '../components/DiagnosisSelect';
import icd10Treatments from '../data/icd10Treatments.json';
import { resolveTreatment } from '../lib/departments';

export default function Patients() {
  const router = useRouter();
  const [searchTerm, setSearchTerm] = useState('');
  const [patients, setPatients] = useState<any[]>([]);
  const [referrals, setReferrals] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const [chws, setChws] = useState<any[]>([]);
  const [chwsLoading, setChwsLoading] = useState(true);

  const [currentUser, setCurrentUser] = useState<any>(null);
  const [currentUserProfile, setCurrentUserProfile] = useState<any>(null);

  const [selectedPatient, setSelectedPatient] = useState<any>(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState('');

  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [reassigning, setReassigning] = useState(false);

  const [newPatient, setNewPatient] = useState({
    name: '', idNumber: '', age: '', phone: '', email: '', address: '',
    condition: '', conditionCode: '', treatment: '', treatmentFirstLine: '',
    treatmentReferral: '', treatmentNotes: '', status: 'Stable', notes: '',
    assignedChwId: '', assignedChwName: '',
  });

  // 1. Auth guard
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (!user) { router.push('/login'); return; }
      setCurrentUser(user);
      setLoading(false);
    });
    return () => unsubscribe();
  }, [router]);

  // 2. Current user profile
  useEffect(() => {
    if (!currentUser) return;
    const unsub = onSnapshot(collection(db, 'users'), (snap) => {
      const all = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      const me = all.find((u: any) => u.id === currentUser.uid || u.uid === currentUser.uid);
      if (me) setCurrentUserProfile(me);
    });
    return () => unsub();
  }, [currentUser]);

  // 3. Patients
  useEffect(() => {
    if (loading) return;
    const q = query(collection(db, 'patients'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const data = snapshot.docs.map((d) => {
        const raw = d.data();
        let dateStr = 'N/A';
        if (raw.createdAt) {
          if (typeof raw.createdAt.toDate === 'function') {
            dateStr = raw.createdAt.toDate().toLocaleDateString();
          } else if (typeof raw.createdAt === 'string') {
            dateStr = new Date(raw.createdAt).toLocaleDateString();
          }
        }
        return { id: d.id, ...raw, _lastVisit: dateStr };
      });
      setPatients(data);
      setSelectedPatient((prev: any) =>
        prev ? data.find((p) => p.id === prev.id) || prev : prev
      );
    });
    return () => unsubscribe();
  }, [loading]);

  // 4. Referrals
  useEffect(() => {
    if (loading) return;
    const q = query(collection(db, 'referrals'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      setReferrals(snapshot.docs.map((d) => ({ id: d.id, ...d.data() })));
    });
    return () => unsubscribe();
  }, [loading]);

  // 5. CHWs
  useEffect(() => {
    if (loading) return;
    const q = query(collection(db, 'users'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const allUsers = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      const chwOnly = allUsers.filter((u: any) => {
        const role = u.role;
        const isChw =
          typeof role === 'string'
            ? role === 'chw'
            : Array.isArray(role)
            ? role.includes('chw')
            : false;
        return isChw && u.status === 'Active';
      });
      setChws(chwOnly);
      setChwsLoading(false);
    });
    return () => unsubscribe();
  }, [loading]);

  // -------------------------------------------------------------
  // Find any referral for a given patient
  // -------------------------------------------------------------
  const findReferralForPatient = (patient: any) => {
    if (!patient) return null;
    return referrals.find((r) => {
      if (r.patientId && r.patientId === patient.id) return true;
      if (r.idNumber && patient.idNumber && r.idNumber === patient.idNumber) return true;
      if (
        r.patientName &&
        patient.name &&
        String(r.patientName).toLowerCase().trim() ===
          String(patient.name).toLowerCase().trim()
      )
        return true;
      return false;
    });
  };

  // -------------------------------------------------------------
  // Merge patient + referral, then resolve treatment
  //
  // NOTE: the resolveTreatment() output has a field called
  // `referral` (a string = referral criteria text). We rename
  // the referral *document* reference to `referralDoc` to avoid
  // the two colliding.
  // -------------------------------------------------------------
  const getTreatmentForPatient = (patient: any) => {
    const referralDoc = findReferralForPatient(patient);

    const merged = {
      conditionCode: patient?.conditionCode || referralDoc?.conditionCode || '',
      condition: patient?.condition || referralDoc?.condition || '',
      treatment: patient?.treatment || referralDoc?.treatment || '',
      treatmentFirstLine:
        patient?.treatmentFirstLine || referralDoc?.treatmentFirstLine || '',
      treatmentReferral:
        patient?.treatmentReferral || referralDoc?.treatmentReferral || '',
      treatmentNotes: patient?.treatmentNotes || referralDoc?.treatmentNotes || '',
    };

    const resolved = resolveTreatment(merged);

    return {
      code: resolved.code,
      firstLine: resolved.firstLine,
      treatment: resolved.treatment,
      referral: resolved.referral,          // string (referral criteria)
      notes: resolved.notes,
      source: resolved.source,
      referralDoc,                          // object (the referral document)
    };
  };

  const filteredPatients = patients.filter(
    (p) =>
      (p.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (p.condition || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (p.idNumber || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (p.email || '').toLowerCase().includes(searchTerm.toLowerCase())
  );

  const closeModal = () => { setSelectedPatient(null); setConfirmDelete(false); };

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>
  ) => {
    const { name, value } = e.target;
    if (name === 'idNumber') {
      const digitsOnly = value.replace(/\D/g, '').slice(0, 13);
      setNewPatient((prev) => ({ ...prev, idNumber: digitsOnly }));
      return;
    }
    if (name === 'age') {
      const digitsOnly = value.replace(/\D/g, '');
      setNewPatient((prev) => ({ ...prev, age: digitsOnly }));
      return;
    }
    if (name === 'assignedChwId') {
      const chw = chws.find((c) => c.id === value);
      setNewPatient((prev) => ({
        ...prev,
        assignedChwId: value,
        assignedChwName: chw?.displayName || chw?.name || '',
      }));
      return;
    }
    setNewPatient((prev) => ({ ...prev, [name]: value }));
  };

  const resetForm = () => {
    setNewPatient({
      name: '', idNumber: '', age: '', phone: '', email: '', address: '',
      condition: '', conditionCode: '', treatment: '', treatmentFirstLine: '',
      treatmentReferral: '', treatmentNotes: '', status: 'Stable', notes: '',
      assignedChwId: '', assignedChwName: '',
    });
    setFormError('');
  };

  const handleAddPatient = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');
    if (!newPatient.name.trim()) return setFormError('Please enter the patient name.');
    if (!/^\d{13}$/.test(newPatient.idNumber))
      return setFormError('ID Number must be exactly 13 digits.');
    if (newPatient.age && (Number(newPatient.age) < 0 || Number(newPatient.age) > 130))
      return setFormError('Please enter a valid age.');
    if (!newPatient.phone.trim()) return setFormError('Please enter a phone number.');
    if (newPatient.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newPatient.email))
      return setFormError('Please enter a valid email address.');
    if (!newPatient.condition.trim())
      return setFormError('Please select a medical condition.');

    const isCurrentUserChw = (() => {
      const role = currentUserProfile?.role;
      if (!role) return false;
      if (typeof role === 'string') return role === 'chw';
      if (Array.isArray(role)) return role.includes('chw');
      return false;
    })();

    const finalChwId =
      newPatient.assignedChwId || (isCurrentUserChw ? currentUser?.uid : '') || '';
    const finalChwName =
      newPatient.assignedChwName ||
      (isCurrentUserChw
        ? currentUserProfile?.displayName || currentUser?.email?.split('@')[0] || ''
        : '');
    if (!finalChwId)
      return setFormError('Please assign a Community Health Worker to this patient.');

    setSaving(true);
    try {
      await addDoc(collection(db, 'patients'), {
        name: newPatient.name.trim(),
        idNumber: newPatient.idNumber,
        age: newPatient.age ? Number(newPatient.age) : null,
        phone: newPatient.phone.trim(),
        email: newPatient.email.trim() || null,
        address: newPatient.address.trim(),
        condition: newPatient.condition.trim(),
        conditionCode: newPatient.conditionCode || null,
        treatment: newPatient.treatment || null,
        treatmentFirstLine: newPatient.treatmentFirstLine || null,
        treatmentReferral: newPatient.treatmentReferral || null,
        treatmentNotes: newPatient.treatmentNotes || null,
        status: newPatient.status,
        notes: newPatient.notes.trim(),
        assignedChwId: finalChwId,
        assignedChwName: finalChwName,
        registeredByUid: currentUser?.uid || null,
        registeredByName:
          currentUserProfile?.displayName ||
          currentUser?.displayName ||
          currentUser?.email?.split('@')[0] ||
          'Unknown',
        createdAt: serverTimestamp(),
      });
      resetForm();
      setShowAddModal(false);
    } catch (err) {
      setFormError('Failed to save patient: ' + (err as any).message);
    } finally {
      setSaving(false);
    }
  };

  const handleDeletePatient = async () => {
    if (!selectedPatient) return;
    setDeleting(true);
    try {
      await deleteDoc(doc(db, 'patients', selectedPatient.id));
      setConfirmDelete(false);
      setSelectedPatient(null);
    } catch (err) {
      alert('Failed to delete patient: ' + (err as any).message);
    } finally {
      setDeleting(false);
    }
  };

  const handleReassignChw = async (newChwId: string) => {
    if (!selectedPatient) return;
    if (newChwId === selectedPatient.assignedChwId) return;
    setReassigning(true);
    try {
      const chw = chws.find((c) => c.id === newChwId);
      await updateDoc(doc(db, 'patients', selectedPatient.id), {
        assignedChwId: newChwId,
        assignedChwName: chw?.displayName || chw?.name || '',
        reassignedAt: serverTimestamp(),
        reassignedBy: auth.currentUser?.email || 'unknown',
      });
    } catch (err) {
      alert('Failed to reassign: ' + (err as any).message);
    } finally {
      setReassigning(false);
    }
  };

  const getChwLabel = (patient: any) => {
    if (patient.assignedChwName) return patient.assignedChwName;
    if (patient.assignedChwId) {
      const chw = chws.find((c) => c.id === patient.assignedChwId);
      if (chw) return chw.displayName || chw.name || chw.email || 'CHW';
    }
    if (patient.registeredByName) return patient.registeredByName;
    return 'Unassigned';
  };

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: '50px', color: '#666' }}>
        Loading patients...
      </div>
    );
  }

  return (
    <Layout>
      <div style={styles.container}>
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Patients</h1>
            <p style={styles.pageSubtitle}>Manage your patient records</p>
          </div>
          <button
            style={styles.addButton}
            onClick={() => { resetForm(); setShowAddModal(true); }}
          >
            + Add Patient
          </button>
        </div>

        <div style={styles.searchContainer}>
          <input
            type="text"
            placeholder="🔍 Search patients by name, ID, email or condition..."
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
            {filteredPatients.map((patient) => {
              const t = getTreatmentForPatient(patient);
              const hasProtocol = !!(t.firstLine || t.treatment);
              const wasReferred = !!t.referralDoc;

              return (
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
                    <p style={styles.detailRow}>🆔 ID: {patient.idNumber || 'N/A'}</p>
                    <p style={styles.detailRow}>📞 {patient.phone || 'N/A'}</p>
                    {patient.email && <p style={styles.detailRow}>✉️ {patient.email}</p>}
                    <p style={styles.detailRow}>🩺 {patient.condition || 'N/A'}</p>
                    <p style={styles.detailRow}>📍 {patient.address || 'N/A'}</p>
                    <p style={styles.detailRow}>👩‍⚕️ CHW: {getChwLabel(patient)}</p>
                    <p style={styles.detailRow}>📅 Added: {patient._lastVisit}</p>

                    <div style={styles.treatChipRow}>
                      {hasProtocol ? (
                        <span style={styles.treatChip}>
                          💊 {t.firstLine || 'Treatment on file'}
                          {wasReferred && <span style={styles.treatChipFrom}> · from referral</span>}
                        </span>
                      ) : (
                        <span style={{ ...styles.treatChip, ...styles.treatChipEmpty }}>
                          💊 No protocol — see details
                        </span>
                      )}
                    </div>
                  </div>
                  <div style={styles.cardFooter}>
                    <span style={{
                      ...styles.statusBadge,
                      ...(patient.status === 'Critical' ? styles.statusCritical
                        : patient.status === 'Needs Follow-up' ? styles.statusFollowUp
                        : patient.status === 'Reviewed' ? styles.statusReviewed
                        : styles.statusStable),
                    }}>
                      {patient.status || 'Stable'}
                    </span>
                    <button style={styles.viewButton} onClick={() => setSelectedPatient(patient)}>
                      View Details
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* ============ VIEW PATIENT MODAL ============ */}
      {selectedPatient && (() => {
        const t = getTreatmentForPatient(selectedPatient);
        const hasProtocol = !!(t.firstLine || t.treatment);
        const wasReferred = !!t.referralDoc;

        return (
          <div style={styles.modalOverlay} onClick={closeModal}>
            <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
              <div style={styles.modalHeader}>
                <h2 style={styles.modalTitle}>{selectedPatient.name}</h2>
                <button onClick={closeModal} style={styles.closeButton}>×</button>
              </div>

              <div style={styles.modalBody}>
                <div style={styles.modalRow}>
                  <span style={styles.modalLabel}>ID Number:</span>
                  <span style={styles.modalValue}>{selectedPatient.idNumber || 'N/A'}</span>
                </div>
                <div style={styles.modalRow}>
                  <span style={styles.modalLabel}>Age:</span>
                  <span style={styles.modalValue}>{selectedPatient.age || '?'} yrs</span>
                </div>
                <div style={styles.modalRow}>
                  <span style={styles.modalLabel}>Condition:</span>
                  <span style={styles.modalValue}>{selectedPatient.condition}</span>
                </div>
                <div style={styles.modalRow}>
                  <span style={styles.modalLabel}>Status:</span>
                  <span style={styles.modalStatusBadge}>{selectedPatient.status || 'Stable'}</span>
                </div>

                <div style={styles.modalRow}>
                  <span style={styles.modalLabel}>Assigned CHW:</span>
                  <select
                    value={selectedPatient.assignedChwId || ''}
                    onChange={(e) => handleReassignChw(e.target.value)}
                    disabled={reassigning}
                    style={styles.reassignSelect}
                  >
                    <option value="">— Unassigned —</option>
                    {chws.map((chw) => (
                      <option key={chw.id} value={chw.id}>
                        {chw.displayName || chw.name || 'Unnamed CHW'}
                      </option>
                    ))}
                  </select>
                </div>

                {/* ============ TREATMENT PLAN ============ */}
                <div style={styles.treatSection}>
                  <div style={styles.treatSectionHeader}>
                    <div style={styles.treatSectionHeaderLeft}>
                      <span style={styles.treatSectionIcon}>💊</span>
                      <span style={styles.treatSectionTitle}>Treatment Plan</span>
                    </div>
                    <div style={styles.treatChips}>
                      {t.code && <span style={styles.treatCodeChip}>{t.code}</span>}
                      {wasReferred && <span style={styles.treatReferredChip}>Referred</span>}
                    </div>
                  </div>

                  {!hasProtocol ? (
                    <div style={styles.treatEmpty}>
                      <p style={styles.treatEmptyTitle}>No preloaded protocol</p>
                      <p style={styles.treatEmptyText}>
                        No treatment is on record for this diagnosis. Consult the{' '}
                        <b>PHC STG / EML 2024</b> guidelines for the appropriate regimen.
                      </p>
                    </div>
                  ) : (
                    <>
                      {t.firstLine && (
                        <div style={{ ...styles.treatCard, borderLeftColor: '#10b981' }}>
                          <div style={styles.treatCardHead}>
                            <span style={{ ...styles.treatDot, backgroundColor: '#10b981' }} />
                            <span style={{ ...styles.treatCardLabel, color: '#047857' }}>
                              FIRST-LINE
                            </span>
                          </div>
                          <p style={styles.treatFirstLine}>{t.firstLine}</p>
                        </div>
                      )}
                      {t.treatment && (
                        <div style={{ ...styles.treatCard, borderLeftColor: '#0ea5e9' }}>
                          <div style={styles.treatCardHead}>
                            <span style={{ ...styles.treatDot, backgroundColor: '#0ea5e9' }} />
                            <span style={{ ...styles.treatCardLabel, color: '#0369a1' }}>
                              FULL REGIMEN
                            </span>
                          </div>
                          <p style={styles.treatText}>{t.treatment}</p>
                        </div>
                      )}
                      {t.referral && (
                        <div style={{ ...styles.treatCard, borderLeftColor: '#ef4444', backgroundColor: '#fffbfb' }}>
                          <div style={styles.treatCardHead}>
                            <span style={{ ...styles.treatDot, backgroundColor: '#ef4444' }} />
                            <span style={{ ...styles.treatCardLabel, color: '#b91c1c' }}>
                              REFER IF
                            </span>
                          </div>
                          <p style={{ ...styles.treatText, color: '#7f1d1d' }}>{t.referral}</p>
                        </div>
                      )}
                      {t.notes && (
                        <div style={{ ...styles.treatCard, borderLeftColor: '#a855f7' }}>
                          <div style={styles.treatCardHead}>
                            <span style={{ ...styles.treatDot, backgroundColor: '#a855f7' }} />
                            <span style={{ ...styles.treatCardLabel, color: '#6b21a8' }}>
                              CLINICIAN NOTES
                            </span>
                          </div>
                          <p style={styles.treatText}>{t.notes}</p>
                        </div>
                      )}
                    </>
                  )}
                </div>

                <div style={styles.modalRow}>
                  <span style={styles.modalLabel}>Phone:</span>
                  <span style={styles.modalValue}>{selectedPatient.phone}</span>
                </div>
                {selectedPatient.email && (
                  <div style={styles.modalRow}>
                    <span style={styles.modalLabel}>Email:</span>
                    <span style={styles.modalValue}>{selectedPatient.email}</span>
                  </div>
                )}
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

              {confirmDelete ? (
                <div style={styles.confirmDeleteBox}>
                  <p style={styles.confirmDeleteText}>
                    Delete <b>{selectedPatient.name}</b>? This cannot be undone.
                  </p>
                  <div style={styles.confirmDeleteActions}>
                    <button style={styles.modalSecondaryBtn} onClick={() => setConfirmDelete(false)} disabled={deleting}>
                      Cancel
                    </button>
                    <button style={styles.deleteConfirmBtn} onClick={handleDeletePatient} disabled={deleting}>
                      {deleting ? 'Deleting…' : 'Yes, delete'}
                    </button>
                  </div>
                </div>
              ) : (
                <div style={styles.modalFooter}>
                  <button style={styles.deleteButton} onClick={() => setConfirmDelete(true)}>
                    🗑 Delete Patient
                  </button>
                  <button onClick={closeModal} style={styles.modalCloseBtn}>Close</button>
                </div>
              )}
            </div>
          </div>
        );
      })()}

      {/* ============ ADD PATIENT MODAL ============ */}
      {showAddModal && (
        <div style={styles.modalOverlay} onClick={() => !saving && setShowAddModal(false)}>
          <div style={styles.addModalContent} onClick={(e) => e.stopPropagation()}>
            <div style={styles.modalHeader}>
              <h2 style={styles.modalTitle}>Add New Patient</h2>
              <button onClick={() => !saving && setShowAddModal(false)} style={styles.closeButton}>×</button>
            </div>

            {formError && <div style={styles.errorBox}>{formError}</div>}

            <form onSubmit={handleAddPatient}>
              <div style={styles.formGrid}>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Full Name *</label>
                  <input type="text" name="name" value={newPatient.name}
                    onChange={handleInputChange} placeholder="e.g. Thabo Mokoena"
                    style={styles.formInput} required />
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>ID Number * (13 digits)</label>
                  <input type="text" name="idNumber" value={newPatient.idNumber}
                    onChange={handleInputChange} placeholder="e.g. 9001015800083"
                    inputMode="numeric" pattern="\d{13}" maxLength={13}
                    style={styles.formInput} required />
                  <p style={styles.helperText}>
                    {newPatient.idNumber.length}/13 digits
                    {newPatient.idNumber.length === 13 && ' ✓'}
                  </p>
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Age</label>
                  <input type="text" name="age" value={newPatient.age}
                    onChange={handleInputChange} placeholder="e.g. 35"
                    inputMode="numeric" style={styles.formInput} />
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Phone Number *</label>
                  <input type="tel" name="phone" value={newPatient.phone}
                    onChange={handleInputChange} placeholder="e.g. 0821234567"
                    style={styles.formInput} required />
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Email Address</label>
                  <input type="email" name="email" value={newPatient.email}
                    onChange={handleInputChange} placeholder="e.g. thabo@gmail.com"
                    style={styles.formInput} />
                </div>
                <div style={{ ...styles.formGroup, gridColumn: '1 / -1' }}>
                  <label style={styles.formLabel}>Medical Condition / Diagnosis *</label>
                  <DiagnosisSelect
                    value={newPatient.condition}
                    onChange={(label, code) => {
                      const treatment = (icd10Treatments as Record<string, any>)[code];
                      setNewPatient((prev) => ({
                        ...prev,
                        condition: label,
                        conditionCode: code,
                        treatment: treatment?.treatment || '',
                        treatmentFirstLine: treatment?.firstLine || '',
                        treatmentReferral: treatment?.referral || '',
                      }));
                    }}
                  />
                </div>
                {newPatient.condition && newPatient.treatment && (
                  <div style={{ ...styles.formGroup, gridColumn: '1 / -1' }}>
                    <label style={styles.formLabel}>Treatment Plan (auto-filled)</label>
                    <div style={styles.treatmentBox}>
                      <p style={styles.treatmentFirstLine}>💊 {newPatient.treatmentFirstLine}</p>
                      <p style={styles.treatmentText}>{newPatient.treatment}</p>
                      {newPatient.treatmentReferral && (
                        <p style={styles.treatmentReferral}>🚨 Refer if: {newPatient.treatmentReferral}</p>
                      )}
                    </div>
                  </div>
                )}
                {newPatient.condition && (
                  <div style={{ ...styles.formGroup, gridColumn: '1 / -1' }}>
                    <label style={styles.formLabel}>Additional Treatment Notes</label>
                    <textarea name="treatmentNotes" value={newPatient.treatmentNotes}
                      onChange={handleInputChange} rows={3}
                      style={{ ...styles.formInput, resize: 'vertical' as const }} />
                  </div>
                )}
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Status</label>
                  <select name="status" value={newPatient.status}
                    onChange={handleInputChange} style={styles.formInput}>
                    <option value="Stable">Stable</option>
                    <option value="Needs Follow-up">Needs Follow-up</option>
                    <option value="Critical">Critical</option>
                  </select>
                </div>
                <div style={{ ...styles.formGroup, gridColumn: '1 / -1' }}>
                  <label style={styles.formLabel}>Assign Community Health Worker *</label>
                  <select name="assignedChwId" value={newPatient.assignedChwId}
                    onChange={handleInputChange} style={styles.formInput} required>
                    <option value="">
                      {chwsLoading ? 'Loading CHWs...'
                        : chws.length === 0 ? 'No active CHWs available'
                        : 'Select a CHW...'}
                    </option>
                    {chws.map((chw) => (
                      <option key={chw.id} value={chw.id}>
                        {chw.displayName || chw.name || 'Unnamed CHW'}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div style={styles.formGroup}>
                <label style={styles.formLabel}>Address</label>
                <input type="text" name="address" value={newPatient.address}
                  onChange={handleInputChange} style={styles.formInput} />
              </div>
              <div style={styles.formGroup}>
                <label style={styles.formLabel}>Notes</label>
                <textarea name="notes" value={newPatient.notes}
                  onChange={handleInputChange} rows={3}
                  style={{ ...styles.formInput, resize: 'vertical' as const }} />
              </div>

              <div style={styles.modalActions}>
                <button type="button" onClick={() => !saving && setShowAddModal(false)}
                  style={styles.cancelButton} disabled={saving}>Cancel</button>
                <button type="submit" style={styles.submitButton} disabled={saving}>
                  {saving ? 'Saving...' : 'Save Patient'}
                </button>
              </div>
            </form>
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
  statusReviewed: { backgroundColor: '#e0e7ff', color: '#3730a3' },
  viewButton: { backgroundColor: '#2563eb', color: 'white', padding: '6px 14px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '12px' },

  treatChipRow: { marginTop: '10px' },
  treatChip: { display: 'inline-block', padding: '4px 10px', borderRadius: '6px', fontSize: '11px', fontWeight: '600' as const, backgroundColor: '#f0fdf4', color: '#065f46', border: '1px solid #86efac', whiteSpace: 'nowrap' as const, overflow: 'hidden' as const, textOverflow: 'ellipsis' as const, maxWidth: '100%' },
  treatChipFrom: { color: '#0369a1', fontWeight: '500' as const },
  treatChipEmpty: { backgroundColor: '#fffbeb', color: '#92400e', border: '1px solid #fde68a' },

  modalOverlay: { position: 'fixed' as const, top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 },
  modalContent: { backgroundColor: 'white', padding: '24px', borderRadius: '16px', maxWidth: '540px', width: '90%', maxHeight: '90vh', overflowY: 'auto' as const, boxShadow: '0 10px 30px rgba(0,0,0,0.2)' },
  addModalContent: { backgroundColor: 'white', padding: '24px', borderRadius: '16px', maxWidth: '640px', width: '90%', maxHeight: '90vh', overflowY: 'auto' as const, boxShadow: '0 10px 30px rgba(0,0,0,0.2)' },
  modalHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' },
  modalTitle: { fontSize: '22px', fontWeight: 'bold' as const, margin: 0, color: '#1a1a2e' },
  closeButton: { background: 'none', border: 'none', fontSize: '28px', cursor: 'pointer', color: '#888' },
  modalBody: { display: 'flex', flexDirection: 'column' as const, gap: '12px' },
  modalRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '10px' },
  modalLabel: { color: '#6B7280', fontWeight: '500' as const, fontSize: '14px', flexShrink: 0 },
  modalValue: { color: '#1A1A2E', fontWeight: '500' as const, fontSize: '14px', textAlign: 'right' as const },
  modalStatusBadge: { padding: '4px 12px', borderRadius: '20px', fontSize: '12px', backgroundColor: '#d1fae5', color: '#065f46' },
  modalDivider: { height: '1px', backgroundColor: '#e5e7eb', margin: '8px 0' },
  modalFooter: { marginTop: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px' },
  modalCloseBtn: { backgroundColor: '#2563eb', color: 'white', padding: '10px 24px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '14px' },
  modalSecondaryBtn: { backgroundColor: '#f3f4f6', color: '#374151', padding: '10px 20px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' as const },
  reassignSelect: { padding: '8px 12px', border: '1px solid #e5e7eb', borderRadius: '8px', fontSize: '13px', outline: 'none', fontFamily: 'inherit', backgroundColor: 'white', maxWidth: '220px', cursor: 'pointer' },
  deleteButton: { backgroundColor: '#fff', color: '#dc2626', padding: '10px 18px', border: '1px solid #fecaca', borderRadius: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: '600' as const },
  confirmDeleteBox: { marginTop: '20px', padding: '16px', backgroundColor: '#fef2f2', border: '1px solid #fecaca', borderRadius: '12px' },
  confirmDeleteText: { fontSize: '13px', color: '#7f1d1d', margin: '0 0 12px 0', lineHeight: 1.5 },
  confirmDeleteActions: { display: 'flex', gap: '10px', justifyContent: 'flex-end' },
  deleteConfirmBtn: { backgroundColor: '#dc2626', color: 'white', padding: '10px 20px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: '600' as const },

  treatSection: { marginTop: '8px', paddingTop: '14px', borderTop: '1px solid #f0f0f0' },
  treatSectionHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' },
  treatSectionHeaderLeft: { display: 'flex', alignItems: 'center', gap: '8px' },
  treatSectionIcon: { fontSize: '16px' },
  treatSectionTitle: { fontSize: '14px', fontWeight: '700' as const, color: '#0f172a', letterSpacing: '-0.1px' },
  treatChips: { display: 'flex', alignItems: 'center', gap: '6px' },
  treatCodeChip: { backgroundColor: '#dbeafe', color: '#1e40af', padding: '3px 10px', borderRadius: '6px', fontSize: '11px', fontWeight: '700' as const, fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', letterSpacing: '0.3px' },
  treatReferredChip: { backgroundColor: '#e0e7ff', color: '#3730a3', padding: '3px 10px', borderRadius: '6px', fontSize: '11px', fontWeight: '700' as const },
  treatEmpty: { padding: '14px', backgroundColor: '#fffbeb', border: '1px solid #fde68a', borderRadius: '10px' },
  treatEmptyTitle: { margin: 0, fontSize: '13px', fontWeight: '700' as const, color: '#92400e' },
  treatEmptyText: { margin: '4px 0 0', fontSize: '12px', color: '#78350f', lineHeight: 1.5 },
  treatCard: { backgroundColor: '#fbfdfc', border: '1px solid #e2e8f0', borderLeft: '4px solid #10b981', borderRadius: '10px', padding: '12px 14px', marginBottom: '8px' },
  treatCardHead: { display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '6px' },
  treatDot: { width: '6px', height: '6px', borderRadius: '50%', display: 'inline-block' },
  treatCardLabel: { fontSize: '10px', fontWeight: '700' as const, letterSpacing: '1px', textTransform: 'uppercase' as const },
  treatFirstLine: { fontSize: '14px', fontWeight: '600' as const, color: '#0f172a', margin: 0, lineHeight: 1.4 },
  treatText: { fontSize: '12.5px', color: '#334155', margin: 0, lineHeight: 1.6 },

  formGrid: { display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '16px' },
  formGroup: { display: 'flex', flexDirection: 'column' as const, marginBottom: '16px' },
  formLabel: { fontSize: '13px', fontWeight: '500' as const, color: '#333', marginBottom: '6px' },
  formInput: { padding: '10px 12px', border: '1px solid #e5e7eb', borderRadius: '8px', fontSize: '14px', outline: 'none', fontFamily: 'inherit', backgroundColor: 'white' },
  helperText: { fontSize: '11px', color: '#888', margin: '4px 0 0' },
  errorBox: { backgroundColor: '#fee2e2', color: '#991b1b', padding: '10px 14px', borderRadius: '8px', marginBottom: '16px', fontSize: '13px', border: '1px solid #fecaca' },
  modalActions: { display: 'flex', gap: '12px', marginTop: '12px', justifyContent: 'flex-end' },
  cancelButton: { backgroundColor: '#f3f4f6', color: '#374151', padding: '10px 20px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' as const },
  submitButton: { backgroundColor: '#2563eb', color: 'white', padding: '10px 24px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' as const },
  treatmentBox: { backgroundColor: '#f0fdf4', border: '1px solid #86efac', borderRadius: '10px', padding: '14px', marginTop: '6px' },
  treatmentFirstLine: { fontSize: '13px', fontWeight: '600' as const, color: '#065f46', margin: '0 0 6px 0' },
  treatmentText: { fontSize: '13px', color: '#1a1a2e', margin: '4px 0', lineHeight: 1.5 },
  treatmentReferral: { fontSize: '12px', color: '#991b1b', margin: '8px 0 0 0', fontStyle: 'italic' },
};