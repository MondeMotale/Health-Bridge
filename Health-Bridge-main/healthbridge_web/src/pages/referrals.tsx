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
  addDoc,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import Layout from '../components/Layout';
import { resolveDepartment, resolveTreatment } from '../lib/departments';
import { DB_PATHS } from '../lib/dbPaths';

// ---------- Row types ----------
interface ReferralRow {
  id: string;
  patientId?: string;
  patientName?: string;
  idNumber?: string;
  conditionCode?: string;
  condition?: string;
  treatment?: string;
  treatmentFirstLine?: string;
  treatmentReferral?: string;
  treatmentNotes?: string;
  status: string;
  urgency?: string;
  location?: string;
  department: string;
  referralDepartment: string;
  appointmentDate?: string;
  appointmentDoctor?: string;
  referredToHospital?: string;
  createdAt?: Timestamp | string;
  _displayDate: string;
}

interface PatientRow {
  id: string;
  name?: string;
  idNumber?: string;
  conditionCode?: string;
  condition?: string;
  treatment?: string;
  treatmentFirstLine?: string;
  treatmentReferral?: string;
  treatmentNotes?: string;
}

export default function Referrals() {
  const router = useRouter();
  const [referrals, setReferrals] = useState<ReferralRow[]>([]);
  const [patients, setPatients] = useState<PatientRow[]>([]);
  const [filter, setFilter] = useState('All');
  const [loading, setLoading] = useState(true);
  const [referralsLoading, setReferralsLoading] = useState(true);
  const [referralsError, setReferralsError] = useState('');

  const [actionReferral, setActionReferral] = useState<ReferralRow | null>(null);
  const [showApproveModal, setShowApproveModal] = useState(false);
  const [showReferModal, setShowReferModal] = useState(false);
  const [showTreatmentModal, setShowTreatmentModal] = useState(false);

  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState('');

  const [appt, setAppt] = useState({
    date: '',
    time: '',
    doctor: '',
    room: '',
    type: 'Consultation',
    notes: '',
  });

  const [hospital, setHospital] = useState({
    hospitalName: '',
    reason: '',
    urgency: 'High',
    contactPerson: '',
  });

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

  // 2. Referrals
  useEffect(() => {
    if (loading) return;
    const q = query(
      collection(db, DB_PATHS.referrals),
      orderBy('createdAt', 'desc')
    );
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const data: ReferralRow[] = snapshot.docs.map((d) => {
        const raw = d.data() as Record<string, unknown>;
        let displayDate = 'Just now';
        const cRaw = raw.createdAt as Timestamp | string | undefined | null;
        if (cRaw) {
          try {
            if (typeof cRaw === 'string') {
              displayDate = new Date(cRaw).toLocaleDateString();
            } else if (
              typeof cRaw === 'object' &&
              typeof (cRaw as Timestamp).toDate === 'function'
            ) {
              displayDate = (cRaw as Timestamp).toDate().toLocaleDateString();
            }
          } catch {
            displayDate = 'Unknown';
          }
        }
        const resolved = resolveDepartment(
          raw.conditionCode as string | undefined,
          raw.condition as string | undefined
        );
        return {
          id: d.id,
          patientId: raw.patientId as string | undefined,
          patientName: raw.patientName as string | undefined,
          idNumber: raw.idNumber as string | undefined,
          conditionCode: raw.conditionCode as string | undefined,
          condition: raw.condition as string | undefined,
          treatment: raw.treatment as string | undefined,
          treatmentFirstLine: raw.treatmentFirstLine as string | undefined,
          treatmentReferral: raw.treatmentReferral as string | undefined,
          treatmentNotes: raw.treatmentNotes as string | undefined,
          status: (raw.status as string) || 'Pending',
          urgency: raw.urgency as string | undefined,
          location: raw.location as string | undefined,
          department: resolved.primary,
          referralDepartment: resolved.referral,
          appointmentDate: raw.appointmentDate as string | undefined,
          appointmentDoctor: raw.appointmentDoctor as string | undefined,
          referredToHospital: raw.referredToHospital as string | undefined,
          createdAt: cRaw ?? undefined,
          _displayDate: displayDate,
        };
      });
      setReferrals(data);
      setReferralsLoading(false);
      setReferralsError('');
      setActionReferral((prev) =>
        prev ? data.find((r) => r.id === prev.id) || prev : prev
      );
    }, (error) => {
      console.error('Failed to load referrals:', error);
      setReferralsLoading(false);
      setReferralsError('Unable to load referrals. Check your connection and try again.');
    });
    return () => unsubscribe();
  }, [loading]);

  // 3. Patients
  useEffect(() => {
    if (loading) return;
    const q = query(
      collection(db, DB_PATHS.patients),
      orderBy('createdAt', 'desc')
    );
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const data: PatientRow[] = snapshot.docs.map((d) => {
        const raw = d.data() as Record<string, unknown>;
        return {
          id: d.id,
          name: raw.name as string | undefined,
          idNumber: raw.idNumber as string | undefined,
          conditionCode: raw.conditionCode as string | undefined,
          condition: raw.condition as string | undefined,
          treatment: raw.treatment as string | undefined,
          treatmentFirstLine: raw.treatmentFirstLine as string | undefined,
          treatmentReferral: raw.treatmentReferral as string | undefined,
          treatmentNotes: raw.treatmentNotes as string | undefined,
        };
      });
      setPatients(data);
    });
    return () => unsubscribe();
  }, [loading]);

  const handleApproveAndSchedule = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');
    if (!appt.date) return setFormError('Please choose a date.');
    if (!appt.time) return setFormError('Please choose a time.');
    if (!appt.doctor.trim()) return setFormError('Please enter a doctor.');

    setSaving(true);
    try {
      await addDoc(collection(db, DB_PATHS.appointments), {
        patientName: actionReferral?.patientName || 'Unknown',
        patientId: actionReferral?.patientId || null,
        referralId: actionReferral?.id || null,
        date: appt.date,
        time: appt.time,
        doctor: appt.doctor.trim(),
        room: appt.room.trim() || 'TBD',
        type: appt.type,
        department: actionReferral?.department || 'General Practice',
        status: 'Scheduled',
        notes: appt.notes.trim(),
        createdAt: serverTimestamp(),
      });
      if (actionReferral?.id) {
        await updateDoc(doc(db, DB_PATHS.referrals, actionReferral.id), {
          status: 'Approved',
          appointmentDate: `${appt.date} ${appt.time}`,
          appointmentDoctor: appt.doctor.trim(),
          actionedAt: serverTimestamp(),
          actionedBy: auth.currentUser?.email || 'unknown',
        });
      }
      setAppt({
        date: '',
        time: '',
        doctor: '',
        room: '',
        type: 'Consultation',
        notes: '',
      });
      setShowApproveModal(false);
      setActionReferral(null);
    } catch {
      setFormError('Failed to schedule. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleReferToHospital = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');
    if (!hospital.hospitalName.trim())
      return setFormError('Please enter the hospital name.');
    if (!hospital.reason.trim()) return setFormError('Please enter a reason.');

    setSaving(true);
    try {
      if (actionReferral?.id) {
        await updateDoc(doc(db, DB_PATHS.referrals, actionReferral.id), {
          status: 'Referred',
          referredToHospital: hospital.hospitalName.trim(),
          referralReason: hospital.reason.trim(),
          referralUrgency: hospital.urgency,
          contactPerson: hospital.contactPerson.trim() || null,
          referredAt: serverTimestamp(),
          actionedAt: serverTimestamp(),
          actionedBy: auth.currentUser?.email || 'unknown',
        });
      }
      setHospital({
        hospitalName: '',
        reason: '',
        urgency: 'High',
        contactPerson: '',
      });
      setShowReferModal(false);
      setActionReferral(null);
    } catch {
      setFormError('Failed to refer. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  // Treatment lookup with patient + referral merge
  const getLiveTreatment = (referral: ReferralRow) => {
    const patient = patients.find((p) => {
      if (referral?.patientId && p.id === referral.patientId) return true;
      if (referral?.idNumber && p.idNumber === referral.idNumber) return true;
      if (
        referral?.patientName &&
        p.name &&
        String(p.name).toLowerCase() ===
          String(referral.patientName).toLowerCase()
      )
        return true;
      return false;
    });

    const merged = {
      conditionCode: patient?.conditionCode || referral?.conditionCode || '',
      condition: patient?.condition || referral?.condition || '',
      treatment: patient?.treatment || referral?.treatment || '',
      treatmentFirstLine:
        patient?.treatmentFirstLine || referral?.treatmentFirstLine || '',
      treatmentReferral:
        patient?.treatmentReferral || referral?.treatmentReferral || '',
      treatmentNotes:
        patient?.treatmentNotes || referral?.treatmentNotes || '',
    };

    const t = resolveTreatment(merged);

    return {
      code: t.code,
      firstLine: t.firstLine,
      treatment: t.treatment,
      referral: t.referral,
      notes: t.notes,
      condition: merged.condition || '—',
      patientName: patient?.name || referral?.patientName || 'Unknown',
      resolvedSource: t.source,
    };
  };

  const getStatusStyle = (status: string) => {
    switch (status) {
      case 'Approved':
        return { backgroundColor: '#dbeafe', color: '#1e40af' };
      case 'Referred':
        return { backgroundColor: '#e0e7ff', color: '#3730a3' };
      default:
        return { backgroundColor: '#fee2e2', color: '#991b1b' };
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'Approved':
        return '✅';
      case 'Referred':
        return '🏥';
      default:
        return '⏳';
    }
  };

  const urgencyStyle = (u?: string) => {
    const s = (u || 'Medium').toLowerCase();
    if (s === 'critical')
      return { bg: '#fef2f2', text: '#b91c1c', dot: '#ef4444' };
    if (s === 'high') return { bg: '#fffbeb', text: '#b45309', dot: '#f59e0b' };
    return { bg: '#f0fdf4', text: '#047857', dot: '#10b981' };
  };

  const isActioned = (status: string) =>
    status === 'Approved' || status === 'Referred';

  const filteredReferrals =
    filter === 'All'
      ? referrals
      : referrals.filter((r) => r.status === filter);

  const stats = {
    total: referrals.length,
    pending: referrals.filter((r) => r.status === 'Pending').length,
    approved: referrals.filter((r) => r.status === 'Approved').length,
    referred: referrals.filter((r) => r.status === 'Referred').length,
  };

  if (loading) {
    return (
      <Layout>
        <p role="status" style={{ padding: '50px', textAlign: 'center', color: '#4b5563' }}>
          Checking your account…
        </p>
      </Layout>
    );
  }

  return (
    <Layout>
      <div style={styles.container}>
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Referrals</h1>
          </div>
        </div>

        <div style={styles.statsGrid}>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{stats.total}</p>
            <p style={styles.statLabel}>Total</p>
          </div>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{stats.pending}</p>
            <p style={styles.statLabel}>Pending</p>
          </div>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{stats.approved}</p>
            <p style={styles.statLabel}>Approved</p>
          </div>
          <div style={styles.statCard}>
            <p style={styles.statValue}>{stats.referred}</p>
            <p style={styles.statLabel}>Referred</p>
          </div>
        </div>

        <div style={styles.filterBar} role="group" aria-label="Filter referrals by status">
          {['All', 'Pending', 'Approved', 'Referred'].map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              aria-pressed={filter === f}
              style={{
                ...styles.filterBtn,
                ...(filter === f ? styles.filterActive : {}),
              }}
            >
              {f}
            </button>
          ))}
        </div>

        <div style={styles.tableContainer}>
          {referralsError && (
            <div role="alert" style={styles.errorMessage}>
              <span>{referralsError}</span>
              <button
                type="button"
                onClick={() => router.reload()}
                style={styles.retryButton}
              >
                Refresh referrals
              </button>
            </div>
          )}
          <table style={styles.table} aria-busy={referralsLoading}>
            <caption style={styles.visuallyHidden}>Referrals and their current status</caption>
            <thead>
              <tr>
                <th scope="col" style={styles.th}>Patient</th>
                <th scope="col" style={styles.th}>Condition</th>
                <th scope="col" style={styles.th}>Department</th>
                <th scope="col" style={styles.th}>Location / Destination</th>
                <th scope="col" style={styles.th}>Urgency</th>
                <th scope="col" style={styles.th}>Status</th>
                <th scope="col" style={styles.th}>Date</th>
                <th scope="col" style={styles.th}>Action</th>
              </tr>
            </thead>
            <tbody>
              {referralsLoading ? (
                <tr>
                  <td colSpan={8} role="status" style={styles.emptyState}>
                    Loading referrals…
                  </td>
                </tr>
              ) : referralsError ? (
                <tr>
                  <td colSpan={8} style={styles.emptyState}>
                    Referral records are unavailable.
                  </td>
                </tr>
              ) : filteredReferrals.length === 0 ? (
                <tr>
                  <td colSpan={8} style={styles.emptyState}>
                    {referrals.length === 0
                      ? 'No referrals yet.'
                      : `No ${filter.toLowerCase()} referrals found.`}
                  </td>
                </tr>
              ) : (
                filteredReferrals.map((r) => (
                  <tr key={r.id} style={styles.tr}>
                    <td style={styles.td}>
                      <b>{r.patientName || 'Unknown'}</b>
                    </td>
                    <td style={styles.td}>{r.condition || 'N/A'}</td>
                    <td style={styles.td}>
                      <span style={styles.deptBadge}>{r.department}</span>
                    </td>
                    <td style={styles.td}>
                      {r.status === 'Approved' && r.appointmentDate
                        ? `📅 ${r.appointmentDate} · ${r.appointmentDoctor || ''}`
                        : r.status === 'Referred' && r.referredToHospital
                          ? `🏥 ${r.referredToHospital}`
                          : r.location || 'N/A'}
                    </td>
                    <td style={styles.td}>
                      <span
                        style={{
                          ...styles.urgencyBadge,
                          backgroundColor:
                            r.urgency === 'Critical'
                              ? '#fee2e2'
                              : r.urgency === 'High'
                                ? '#fef3c7'
                                : '#d1fae5',
                          color:
                            r.urgency === 'Critical'
                              ? '#991b1b'
                              : r.urgency === 'High'
                                ? '#92400e'
                                : '#065f46',
                        }}
                      >
                        {r.urgency || 'Medium'}
                      </span>
                    </td>
                    <td style={styles.td}>
                      <span
                        style={{
                          ...styles.statusBadge,
                          ...getStatusStyle(r.status),
                        }}
                      >
                        {getStatusIcon(r.status)} {r.status}
                      </span>
                    </td>
                    <td style={styles.td}>{r._displayDate}</td>
                    <td style={styles.td}>
                      {isActioned(r.status) ? (
                        <span style={styles.doneBadge}>Actioned</span>
                      ) : (
                        <button
                          style={styles.actionBtn}
                          onClick={() => setActionReferral(r)}
                        >
                          Take Action
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ============ TAKE ACTION MODAL ============ */}
      {actionReferral &&
        !showApproveModal &&
        !showReferModal &&
        !showTreatmentModal &&
        (() => {
          const urg = urgencyStyle(actionReferral.urgency);
          const diag =
            actionReferral.conditionCode ||
            getLiveTreatment(actionReferral).code ||
            '—';

          return (
            <div
              style={styles.modalOverlay}
              onClick={() => setActionReferral(null)}
            >
              <div
                style={styles.actionModal}
                onClick={(e) => e.stopPropagation()}
              >
                <div style={styles.modalHead}>
                  <div style={styles.modalHeadLeft}>
                    <div style={styles.modalHeadIcon}>
                      <svg
                        width="20"
                        height="20"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="#0f766e"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <path d="M9 2h6a2 2 0 0 1 2 2v2h2a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2V4a2 2 0 0 1 2-2z" />
                        <path d="M9 12l2 2 4-4" />
                      </svg>
                    </div>
                    <div>
                      <p style={styles.modalEyebrow}>REFERRAL REVIEW</p>
                      <h2 style={styles.modalPatient}>
                        {actionReferral.patientName}
                      </h2>
                      <p style={styles.modalCondition}>
                        {actionReferral.condition || 'No condition on record'}
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={() => setActionReferral(null)}
                    style={styles.modalClose}
                    aria-label="Close"
                  >
                    <svg
                      width="18"
                      height="18"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                    >
                      <line x1="18" y1="6" x2="6" y2="18" />
                      <line x1="6" y1="6" x2="18" y2="18" />
                    </svg>
                  </button>
                </div>

                <div style={styles.metaRow}>
                  <div style={styles.metaChip}>
                    <span style={styles.metaLabel}>Department</span>
                    <span style={styles.metaValue}>
                      {actionReferral.department}
                    </span>
                  </div>
                  <div
                    style={{
                      ...styles.metaChip,
                      backgroundColor: urg.bg,
                      borderColor: urg.bg,
                    }}
                  >
                    <span style={{ ...styles.metaLabel, color: urg.text }}>
                      Urgency
                    </span>
                    <span
                      style={{
                        ...styles.metaValue,
                        color: urg.text,
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '6px',
                      }}
                    >
                      <span
                        style={{
                          width: '6px',
                          height: '6px',
                          borderRadius: '50%',
                          backgroundColor: urg.dot,
                          display: 'inline-block',
                        }}
                      />
                      {actionReferral.urgency || 'Medium'}
                    </span>
                  </div>
                  <div style={styles.metaChip}>
                    <span style={styles.metaLabel}>Diagnosis</span>
                    <span
                      style={{
                        ...styles.metaValue,
                        fontFamily:
                          'ui-monospace, SFMono-Regular, Menlo, monospace',
                        fontSize: '12px',
                      }}
                    >
                      {diag}
                    </span>
                  </div>
                </div>

                <div style={styles.promptRow}>
                  <div style={styles.promptLine} />
                  <p style={styles.promptText}>
                    Select the clinical pathway. This decision is final.
                  </p>
                  <div style={styles.promptLine} />
                </div>

                <button
                  style={{ ...styles.pathway, ...styles.pathwayPrimary }}
                  onClick={() => setShowApproveModal(true)}
                >
                  <div
                    style={{
                      ...styles.pathwayIcon,
                      backgroundColor: '#d1fae5',
                    }}
                  >
                    <svg
                      width="20"
                      height="20"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="#047857"
                      strokeWidth="2.2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    >
                      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                      <line x1="16" y1="2" x2="16" y2="6" />
                      <line x1="8" y1="2" x2="8" y2="6" />
                      <line x1="3" y1="10" x2="21" y2="10" />
                      <path d="M9 16l2 2 4-4" />
                    </svg>
                  </div>
                  <div style={styles.pathwayText}>
                    <p style={styles.pathwayTitle}>
                      Approve &amp; Schedule Appointment
                    </p>
                    <p style={styles.pathwayDesc}>
                      Book a date, time and clinician for this patient in{' '}
                      {actionReferral.department}.
                    </p>
                  </div>
                  <svg
                    width="18"
                    height="18"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="#64748b"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    style={{ flexShrink: 0 }}
                  >
                    <polyline points="9 18 15 12 9 6" />
                  </svg>
                </button>

                <button
                  style={{ ...styles.pathway, ...styles.pathwaySecondary }}
                  onClick={() => setShowReferModal(true)}
                >
                  <div
                    style={{
                      ...styles.pathwayIcon,
                      backgroundColor: '#dbeafe',
                    }}
                  >
                    <svg
                      width="20"
                      height="20"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="#1d4ed8"
                      strokeWidth="2.2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    >
                      <path d="M3 21h18" />
                      <path d="M5 21V7l7-4 7 4v14" />
                      <path d="M9 21v-6h6v6" />
                    </svg>
                  </div>
                  <div style={styles.pathwayText}>
                    <p style={styles.pathwayTitle}>
                      Refer to Another Hospital
                    </p>
                    <p style={styles.pathwayDesc}>
                      Escalate to{' '}
                      {actionReferral.referralDepartment ||
                        'a specialist facility'}
                      .
                    </p>
                  </div>
                  <svg
                    width="18"
                    height="18"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="#64748b"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    style={{ flexShrink: 0 }}
                  >
                    <polyline points="9 18 15 12 9 6" />
                  </svg>
                </button>

                <button
                  style={styles.treatLink}
                  onClick={() => setShowTreatmentModal(true)}
                >
                  <svg
                    width="15"
                    height="15"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="#0f766e"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <circle cx="12" cy="12" r="10" />
                    <line x1="12" y1="16" x2="12" y2="12" />
                    <line x1="12" y1="8" x2="12.01" y2="8" />
                  </svg>
                  View clinical treatment plan
                </button>

                <div style={styles.modalFoot}>
                  <button
                    style={styles.cancelBtn}
                    onClick={() => setActionReferral(null)}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          );
        })()}

      {/* ============ TREATMENT PLAN MODAL ============ */}
      {showTreatmentModal &&
        actionReferral &&
        (() => {
          const t = getLiveTreatment(actionReferral);
          const hasTreatment = !!(t.treatment || t.firstLine);

          return (
            <div
              style={styles.modalOverlay}
              onClick={() => setShowTreatmentModal(false)}
            >
              <div
                style={styles.treatmentModal}
                onClick={(e) => e.stopPropagation()}
              >
                <div style={styles.modalHead}>
                  <div style={styles.modalHeadLeft}>
                    <div style={styles.modalHeadIcon}>
                      <svg
                        width="20"
                        height="20"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="#0f766e"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <path d="M11 2h2a2 2 0 0 1 2 2v2h2a2 2 0 0 1 2 2v2a2 2 0 0 1-2 2h-2v2a2 2 0 0 1-2 2h-2a2 2 0 0 1-2-2v-2H7a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2V4a2 2 0 0 1 2-2z" />
                      </svg>
                    </div>
                    <div>
                      <p style={styles.modalEyebrow}>CLINICAL REFERENCE</p>
                      <h2 style={styles.modalPatient}>Treatment Plan</h2>
                    </div>
                  </div>
                  <button
                    onClick={() => setShowTreatmentModal(false)}
                    style={styles.modalClose}
                    aria-label="Close"
                  >
                    <svg
                      width="18"
                      height="18"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                    >
                      <line x1="18" y1="6" x2="6" y2="18" />
                      <line x1="6" y1="6" x2="18" y2="18" />
                    </svg>
                  </button>
                </div>

                <div style={styles.patientBlock}>
                  <div style={styles.patientRow}>
                    <span style={styles.patientLabel}>Patient</span>
                    <span style={styles.patientValue}>{t.patientName}</span>
                  </div>
                  <div style={styles.patientRow}>
                    <span style={styles.patientLabel}>Diagnosis</span>
                    <span style={styles.patientValue}>{t.condition}</span>
                  </div>
                  <div style={styles.patientRow}>
                    <span style={styles.patientLabel}>ICD-10</span>
                    <span style={styles.icdChip}>{t.code || 'Not set'}</span>
                  </div>
                </div>

                {!hasTreatment ? (
                  <div style={styles.emptyBlock}>
                    <div style={styles.emptyIcon}>
                      <svg
                        width="22"
                        height="22"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="#b45309"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <path d="M12 9v4M12 17h.01M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                      </svg>
                    </div>
                    <div>
                      <p style={styles.emptyTitle}>No preloaded protocol</p>
                      <p style={styles.emptyText}>
                        This diagnosis has no preloaded treatment. Consult the{' '}
                        <b>PHC STG / EML 2024</b> guidelines for the appropriate
                        regimen.
                      </p>
                    </div>
                  </div>
                ) : (
                  <div style={styles.treatBody}>
                    {t.firstLine && (
                      <div
                        style={{
                          ...styles.treatCard,
                          borderLeftColor: '#10b981',
                        }}
                      >
                        <div style={styles.treatCardHead}>
                          <span
                            style={{
                              ...styles.treatDot,
                              backgroundColor: '#10b981',
                            }}
                          />
                          <span
                            style={{
                              ...styles.treatCardLabel,
                              color: '#047857',
                            }}
                          >
                            FIRST-LINE
                          </span>
                        </div>
                        <p style={styles.treatFirstLine}>{t.firstLine}</p>
                      </div>
                    )}
                    {t.treatment && (
                      <div
                        style={{
                          ...styles.treatCard,
                          borderLeftColor: '#0ea5e9',
                        }}
                      >
                        <div style={styles.treatCardHead}>
                          <span
                            style={{
                              ...styles.treatDot,
                              backgroundColor: '#0ea5e9',
                            }}
                          />
                          <span
                            style={{
                              ...styles.treatCardLabel,
                              color: '#0369a1',
                            }}
                          >
                            FULL REGIMEN
                          </span>
                        </div>
                        <p style={styles.treatText}>{t.treatment}</p>
                      </div>
                    )}
                    {t.referral && (
                      <div
                        style={{
                          ...styles.treatCard,
                          borderLeftColor: '#ef4444',
                          backgroundColor: '#fffbfb',
                        }}
                      >
                        <div style={styles.treatCardHead}>
                          <span
                            style={{
                              ...styles.treatDot,
                              backgroundColor: '#ef4444',
                            }}
                          />
                          <span
                            style={{
                              ...styles.treatCardLabel,
                              color: '#b91c1c',
                            }}
                          >
                            REFER IF
                          </span>
                        </div>
                        <p style={{ ...styles.treatText, color: '#7f1d1d' }}>
                          {t.referral}
                        </p>
                      </div>
                    )}
                    {t.notes && (
                      <div
                        style={{
                          ...styles.treatCard,
                          borderLeftColor: '#a855f7',
                        }}
                      >
                        <div style={styles.treatCardHead}>
                          <span
                            style={{
                              ...styles.treatDot,
                              backgroundColor: '#a855f7',
                            }}
                          />
                          <span
                            style={{
                              ...styles.treatCardLabel,
                              color: '#6b21a8',
                            }}
                          >
                            CLINICIAN NOTES
                          </span>
                        </div>
                        <p style={styles.treatText}>{t.notes}</p>
                      </div>
                    )}
                  </div>
                )}

                <div style={styles.modalFoot}>
                  <button
                    style={styles.cancelBtn}
                    onClick={() => setShowTreatmentModal(false)}
                  >
                    Close
                  </button>
                  {!isActioned(actionReferral.status) && (
                    <button
                      style={styles.primaryBtn}
                      onClick={() => {
                        setShowTreatmentModal(false);
                        setShowApproveModal(true);
                      }}
                    >
                      Proceed to Approve →
                    </button>
                  )}
                </div>
              </div>
            </div>
          );
        })()}

      {/* ============ APPROVE & SCHEDULE ============ */}
      {showApproveModal && actionReferral && (
        <div
          style={styles.modalOverlay}
          onClick={() => !saving && setShowApproveModal(false)}
        >
          <div
            style={styles.modalContent}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={styles.modalHeader}>
              <h2 style={styles.modalTitle}>Schedule Appointment</h2>
              <button
                onClick={() => !saving && setShowApproveModal(false)}
                style={styles.closeButton}
              >
                ×
              </button>
            </div>
            <p style={styles.modalHint}>
              Booking for <b>{actionReferral.patientName}</b> in{' '}
              <b>{actionReferral.department}</b>
            </p>
            {formError && <div style={styles.errorBox}>{formError}</div>}
            <form onSubmit={handleApproveAndSchedule}>
              <div style={styles.formGrid}>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Date *</label>
                  <input
                    type="date"
                    value={appt.date}
                    onChange={(e) => setAppt({ ...appt, date: e.target.value })}
                    style={styles.formInput}
                    required
                  />
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Time *</label>
                  <input
                    type="time"
                    value={appt.time}
                    onChange={(e) => setAppt({ ...appt, time: e.target.value })}
                    style={styles.formInput}
                    required
                  />
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Doctor *</label>
                  <input
                    type="text"
                    value={appt.doctor}
                    onChange={(e) =>
                      setAppt({ ...appt, doctor: e.target.value })
                    }
                    placeholder="e.g. Dr. Smith"
                    maxLength={100}
                    style={styles.formInput}
                    required
                  />
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Room</label>
                  <input
                    type="text"
                    value={appt.room}
                    onChange={(e) => setAppt({ ...appt, room: e.target.value })}
                    placeholder="e.g. 204"
                    maxLength={20}
                    style={styles.formInput}
                  />
                </div>
              </div>
              <div style={styles.formGroup}>
                <label style={styles.formLabel}>Type</label>
                <select
                  value={appt.type}
                  onChange={(e) => setAppt({ ...appt, type: e.target.value })}
                  style={styles.formInput}
                >
                  <option value="Consultation">Consultation</option>
                  <option value="Checkup">Checkup</option>
                  <option value="Follow-up">Follow-up</option>
                  <option value="Emergency">Emergency</option>
                </select>
              </div>
              <div style={styles.formGroup}>
                <label style={styles.formLabel}>Notes</label>
                <textarea
                  value={appt.notes}
                  onChange={(e) => setAppt({ ...appt, notes: e.target.value })}
                  rows={3}
                  maxLength={1000}
                  style={{ ...styles.formInput, resize: 'vertical' as const }}
                />
              </div>
              <div style={styles.modalActions}>
                <button
                  type="button"
                  onClick={() => !saving && setShowApproveModal(false)}
                  style={styles.cancelButton}
                  disabled={saving}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  style={styles.primaryBtn}
                  disabled={saving}
                >
                  {saving ? 'Scheduling...' : 'Confirm Appointment'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ============ REFER TO HOSPITAL ============ */}
      {showReferModal && actionReferral && (
        <div
          style={styles.modalOverlay}
          onClick={() => !saving && setShowReferModal(false)}
        >
          <div
            style={styles.modalContent}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={styles.modalHeader}>
              <h2 style={styles.modalTitle}>Refer to Another Hospital</h2>
              <button
                onClick={() => !saving && setShowReferModal(false)}
                style={styles.closeButton}
              >
                ×
              </button>
            </div>
            <p style={styles.modalHint}>
              Referring <b>{actionReferral.patientName}</b> to a{' '}
              <b>
                {actionReferral.referralDepartment || 'specialist'}
              </b>{' '}
              facility
            </p>
            {formError && <div style={styles.errorBox}>{formError}</div>}
            <form onSubmit={handleReferToHospital}>
              <div style={styles.formGroup}>
                <label style={styles.formLabel}>Hospital Name *</label>
                <input
                  type="text"
                  value={hospital.hospitalName}
                  onChange={(e) =>
                    setHospital({ ...hospital, hospitalName: e.target.value })
                  }
                  placeholder="e.g. Chris Hani Baragwanath"
                  maxLength={150}
                  style={styles.formInput}
                  required
                />
              </div>
              <div style={styles.formGroup}>
                <label style={styles.formLabel}>Reason *</label>
                <textarea
                  value={hospital.reason}
                  onChange={(e) =>
                    setHospital({ ...hospital, reason: e.target.value })
                  }
                  rows={3}
                  maxLength={1000}
                  style={{ ...styles.formInput, resize: 'vertical' as const }}
                  required
                />
              </div>
              <div style={styles.formGrid}>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Urgency</label>
                  <select
                    value={hospital.urgency}
                    onChange={(e) =>
                      setHospital({ ...hospital, urgency: e.target.value })
                    }
                    style={styles.formInput}
                  >
                    <option value="Medium">Medium</option>
                    <option value="High">High</option>
                    <option value="Critical">Critical</option>
                  </select>
                </div>
                <div style={styles.formGroup}>
                  <label style={styles.formLabel}>Contact Person</label>
                  <input
                    type="text"
                    value={hospital.contactPerson}
                    onChange={(e) =>
                      setHospital({
                        ...hospital,
                        contactPerson: e.target.value,
                      })
                    }
                    placeholder="e.g. Dr. Nkosi"
                    maxLength={100}
                    style={styles.formInput}
                  />
                </div>
              </div>
              <div style={styles.modalActions}>
                <button
                  type="button"
                  onClick={() => !saving && setShowReferModal(false)}
                  style={styles.cancelButton}
                  disabled={saving}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  style={styles.primaryBtn}
                  disabled={saving}
                >
                  {saving ? 'Referring...' : 'Confirm Referral'}
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
  filterBar: {
    display: 'flex',
    gap: '12px',
    marginBottom: '20px',
    flexWrap: 'wrap' as const,
  },
  filterBtn: {
    padding: '8px 16px',
    minHeight: '44px',
    borderRadius: '20px',
    border: 'none',
    cursor: 'pointer',
    backgroundColor: '#f3f4f6',
    color: '#4b5563',
    fontSize: '13px',
    fontWeight: '500' as const,
  },
  filterActive: { backgroundColor: '#2563eb', color: 'white' },
  emptyState: {
    padding: '40px',
    textAlign: 'center' as const,
    color: '#4b5563',
  },
  errorMessage: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    flexWrap: 'wrap' as const,
    gap: '12px',
    color: '#991b1b',
    backgroundColor: '#fee2e2',
    border: '1px solid #fecaca',
    borderRadius: '8px',
    padding: '12px 16px',
    margin: '0 0 16px',
  },
  retryButton: {
    backgroundColor: '#991b1b',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    minHeight: '44px',
    padding: '8px 14px',
    cursor: 'pointer',
    fontWeight: '600' as const,
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
  tableContainer: {
    backgroundColor: 'white',
    borderRadius: '14px',
    padding: '20px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    overflowX: 'auto' as const,
  },
  table: { width: '100%', borderCollapse: 'collapse' as const },
  th: {
    textAlign: 'left' as const,
    padding: '12px 16px',
    borderBottom: '1px solid #e5e7eb',
    color: '#666',
    fontSize: '13px',
    fontWeight: '500' as const,
  },
  tr: { borderBottom: '1px solid #f0f0f0' },
  td: { padding: '12px 16px', fontSize: '14px', color: '#333' },
  urgencyBadge: {
    padding: '4px 12px',
    borderRadius: '20px',
    fontSize: '12px',
    fontWeight: '500' as const,
    display: 'inline-block' as const,
  },
  deptBadge: {
    padding: '4px 12px',
    borderRadius: '8px',
    fontSize: '12px',
    fontWeight: '600' as const,
    backgroundColor: '#eef2ff',
    color: '#4338ca',
    display: 'inline-block' as const,
    whiteSpace: 'nowrap' as const,
  },
  statusBadge: {
    display: 'inline-flex',
    alignItems: 'center' as const,
    gap: '6px',
    padding: '6px 14px',
    borderRadius: '20px',
    fontSize: '12px',
    fontWeight: '600' as const,
    whiteSpace: 'nowrap' as const,
  },
  actionBtn: {
    backgroundColor: '#2563eb',
    color: 'white',
    padding: '10px 14px',
    minHeight: '44px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '12px',
    fontWeight: '500' as const,
  },
  doneBadge: {
    display: 'inline-block',
    padding: '6px 14px',
    borderRadius: '8px',
    fontSize: '12px',
    fontWeight: '500' as const,
    color: '#6b7280',
    backgroundColor: '#f3f4f6',
  },
  modalOverlay: {
    position: 'fixed' as const,
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(15,23,42,0.55)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000,
    padding: '20px',
  },
  modalContent: {
    backgroundColor: 'white',
    padding: '24px',
    borderRadius: '16px',
    maxWidth: '560px',
    width: '100%',
    maxHeight: '90vh',
    overflowY: 'auto' as const,
    boxShadow: '0 20px 40px rgba(0,0,0,0.25)',
  },
  modalHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '16px',
  },
  modalTitle: {
    fontSize: '20px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  closeButton: {
    background: 'none',
    border: 'none',
    fontSize: '28px',
    cursor: 'pointer',
    color: '#888',
  },
  modalHint: { fontSize: '14px', color: '#666', margin: '0 0 16px 0' },
  modalActions: {
    display: 'flex',
    gap: '12px',
    marginTop: '12px',
    justifyContent: 'flex-end',
  },
  actionModal: {
    backgroundColor: '#f8fafc',
    borderRadius: '18px',
    width: '100%',
    maxWidth: '580px',
    maxHeight: '92vh',
    overflowY: 'auto' as const,
    padding: '22px',
    boxShadow: '0 24px 48px rgba(15,23,42,0.22)',
    border: '1px solid #e2e8f0',
  },
  modalHead: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: '12px',
    marginBottom: '18px',
  },
  modalHeadLeft: {
    display: 'flex',
    alignItems: 'center',
    gap: '14px',
    minWidth: 0,
  },
  modalHeadIcon: {
    width: '46px',
    height: '46px',
    borderRadius: '12px',
    background: 'linear-gradient(135deg, #ccfbf1 0%, #99f6e4 100%)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    boxShadow: 'inset 0 0 0 1px #5eead4',
  },
  modalEyebrow: {
    fontSize: '10px',
    fontWeight: '700' as const,
    color: '#0f766e',
    letterSpacing: '1px',
    margin: 0,
  },
  modalPatient: {
    fontSize: '20px',
    fontWeight: '700' as const,
    color: '#0f172a',
    margin: '3px 0 0',
    letterSpacing: '-0.2px',
  },
  modalCondition: { fontSize: '13px', color: '#475569', margin: '3px 0 0' },
  modalClose: {
    background: 'white',
    border: '1px solid #e2e8f0',
    borderRadius: '8px',
    width: '32px',
    height: '32px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
    color: '#64748b',
    flexShrink: 0,
  },
  metaRow: {
    display: 'flex',
    gap: '10px',
    marginBottom: '18px',
    flexWrap: 'wrap' as const,
  },
  metaChip: {
    flex: '1 1 130px',
    backgroundColor: 'white',
    border: '1px solid #e2e8f0',
    borderRadius: '10px',
    padding: '10px 12px',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '3px',
    minWidth: 0,
  },
  metaLabel: {
    fontSize: '10px',
    fontWeight: '700' as const,
    color: '#94a3b8',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.7px',
  },
  metaValue: {
    fontSize: '13px',
    fontWeight: '600' as const,
    color: '#0f172a',
    whiteSpace: 'nowrap' as const,
    overflow: 'hidden' as const,
    textOverflow: 'ellipsis' as const,
  },
  promptRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    marginBottom: '14px',
  },
  promptLine: { flex: 1, height: '1px', backgroundColor: '#e2e8f0' },
  promptText: {
    fontSize: '11px',
    fontWeight: '600' as const,
    color: '#64748b',
    margin: 0,
    textTransform: 'uppercase' as const,
    letterSpacing: '0.6px',
    whiteSpace: 'nowrap' as const,
  },
  pathway: {
    display: 'flex',
    alignItems: 'center',
    gap: '14px',
    width: '100%',
    padding: '16px 18px',
    borderRadius: '14px',
    cursor: 'pointer',
    textAlign: 'left' as const,
    marginBottom: '12px',
    transition:
      'transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease',
    backgroundClip: 'padding-box' as const,
  },
  pathwayPrimary: {
    backgroundColor: 'white',
    border: '1.5px solid #a7f3d0',
    boxShadow: '0 2px 8px rgba(16,185,129,0.08)',
  },
  pathwaySecondary: {
    backgroundColor: 'white',
    border: '1.5px solid #bfdbfe',
    boxShadow: '0 2px 8px rgba(37,99,235,0.06)',
  },
  pathwayIcon: {
    width: '44px',
    height: '44px',
    borderRadius: '12px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  pathwayText: { flex: 1, minWidth: 0 },
  pathwayTitle: {
    fontSize: '14px',
    fontWeight: '700' as const,
    color: '#0f172a',
    margin: 0,
    letterSpacing: '-0.1px',
  },
  pathwayDesc: {
    fontSize: '12px',
    color: '#64748b',
    margin: '3px 0 0',
    lineHeight: 1.45,
  },
  treatLink: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '8px',
    background: 'none',
    border: 'none',
    color: '#0f766e',
    fontSize: '13px',
    fontWeight: '600' as const,
    padding: '10px 4px',
    cursor: 'pointer',
    marginTop: '2px',
  },
  modalFoot: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '12px',
    marginTop: '8px',
    paddingTop: '16px',
    borderTop: '1px solid #e2e8f0',
  },
  cancelBtn: {
    backgroundColor: 'white',
    color: '#475569',
    padding: '10px 20px',
    border: '1px solid #e2e8f0',
    borderRadius: '10px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: '600' as const,
  },
  primaryBtn: {
    backgroundColor: '#0f766e',
    color: 'white',
    padding: '10px 22px',
    border: 'none',
    borderRadius: '10px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: '600' as const,
  },
  cancelButton: {
    backgroundColor: '#f3f4f6',
    color: '#374151',
    padding: '10px 20px',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: '500' as const,
  },
  treatmentModal: {
    backgroundColor: '#f8fafc',
    borderRadius: '18px',
    width: '100%',
    maxWidth: '580px',
    maxHeight: '92vh',
    overflowY: 'auto' as const,
    padding: '22px',
    boxShadow: '0 24px 48px rgba(15,23,42,0.22)',
    border: '1px solid #e2e8f0',
  },
  patientBlock: {
    backgroundColor: 'white',
    border: '1px solid #e2e8f0',
    borderRadius: '12px',
    padding: '14px 16px',
    marginBottom: '16px',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '10px',
  },
  patientRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '12px',
  },
  patientLabel: {
    fontSize: '11px',
    fontWeight: '700' as const,
    color: '#94a3b8',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.6px',
    flexShrink: 0,
  },
  patientValue: {
    fontSize: '14px',
    fontWeight: '600' as const,
    color: '#0f172a',
    textAlign: 'right' as const,
    minWidth: 0,
    overflow: 'hidden' as const,
    textOverflow: 'ellipsis' as const,
  },
  icdChip: {
    backgroundColor: '#dbeafe',
    color: '#1e40af',
    padding: '3px 12px',
    borderRadius: '6px',
    fontSize: '12px',
    fontWeight: '700' as const,
    fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
    letterSpacing: '0.4px',
  },
  treatBody: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '10px',
    marginBottom: '16px',
  },
  treatCard: {
    backgroundColor: 'white',
    border: '1px solid #e2e8f0',
    borderLeft: '4px solid #10b981',
    borderRadius: '10px',
    padding: '14px 16px',
  },
  treatCardHead: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '8px',
  },
  treatDot: {
    width: '6px',
    height: '6px',
    borderRadius: '50%',
    display: 'inline-block',
  },
  treatCardLabel: {
    fontSize: '10px',
    fontWeight: '700' as const,
    letterSpacing: '1px',
    textTransform: 'uppercase' as const,
  },
  treatFirstLine: {
    fontSize: '15px',
    fontWeight: '600' as const,
    color: '#0f172a',
    margin: 0,
    lineHeight: 1.4,
  },
  treatText: {
    fontSize: '13px',
    color: '#334155',
    margin: 0,
    lineHeight: 1.6,
  },
  emptyBlock: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: '12px',
    backgroundColor: '#fffbeb',
    border: '1px solid #fde68a',
    borderRadius: '12px',
    padding: '16px',
    marginBottom: '16px',
  },
  emptyIcon: {
    width: '34px',
    height: '34px',
    borderRadius: '8px',
    backgroundColor: '#fef3c7',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  emptyTitle: {
    margin: 0,
    fontSize: '14px',
    fontWeight: '700' as const,
    color: '#92400e',
  },
  emptyText: {
    margin: '4px 0 0',
    fontSize: '13px',
    color: '#78350f',
    lineHeight: 1.5,
  },
  formGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(2, 1fr)',
    gap: '16px',
  },
  formGroup: {
    display: 'flex',
    flexDirection: 'column' as const,
    marginBottom: '16px',
  },
  formLabel: {
    fontSize: '13px',
    fontWeight: '500' as const,
    color: '#333',
    marginBottom: '6px',
  },
  formInput: {
    padding: '10px 12px',
    border: '1px solid #e5e7eb',
    borderRadius: '8px',
    fontSize: '14px',
    outline: 'none',
    fontFamily: 'inherit',
    backgroundColor: 'white',
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
};