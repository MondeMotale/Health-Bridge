import { useEffect, useState, useMemo } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  Timestamp,
} from 'firebase/firestore';
import Layout from '../components/Layout';
import {
  BarChart,
  Bar,
  PieChart,
  Pie,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
} from 'recharts';
import Papa from 'papaparse';
import { DB_PATHS } from '../lib/dbPaths';

type DateRange = '7d' | '30d' | '90d' | 'month' | 'all';

// ---------- Row types ----------
interface PatientRow {
  id: string;
  name?: string;
  status?: string;
  visits?: number;
  createdAt?: Timestamp | string;
  _createdDate: string;
  _createdMs: number;
}

interface AppointmentRow {
  id: string;
  patient?: string;
  patientName?: string;
  status?: string;
  dateTime?: Timestamp | string;
  _ms: number;
}

interface ReferralRow {
  id: string;
  status?: string;
}

interface ChwRow {
  id: string;
  role?: string | string[];
  status?: string;
}

interface AlertRow {
  id: string;
  createdAt?: Timestamp | string;
  respondedAt?: Timestamp | string;
  _createdMs: number;
  _respondedMs: number;
}

const CHART_COLOURS = {
  navy: '#1E3A8A',
  blue: '#2563eb',
  green: '#10b981',
  amber: '#f59e0b',
  red: '#ef4444',
  purple: '#8b5cf6',
  sky: '#0ea5e9',
  gray: '#9ca3af',
};

const STATUS_COLOURS: Record<string, string> = {
  Stable: CHART_COLOURS.green,
  'Needs Follow-up': CHART_COLOURS.amber,
  Critical: CHART_COLOURS.red,
};

const OUTCOME_COLOURS: Record<string, string> = {
  Completed: CHART_COLOURS.green,
  Missed: CHART_COLOURS.red,
  Cancelled: CHART_COLOURS.gray,
  Scheduled: CHART_COLOURS.navy,
  EnRoute: CHART_COLOURS.sky,
  InProgress: CHART_COLOURS.amber,
};

/** Milliseconds in a day — a constant, not an impure call. */
const DAY_MS = 24 * 60 * 60 * 1000;

export default function Analytics() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [dateRange, setDateRange] = useState<DateRange>('30d');

  const [patients, setPatients] = useState<PatientRow[]>([]);
  const [appointments, setAppointments] = useState<AppointmentRow[]>([]);
  const [referrals, setReferrals] = useState<ReferralRow[]>([]);
  const [chws, setChws] = useState<ChwRow[]>([]);
  const [alerts, setAlerts] = useState<AlertRow[]>([]);

  // -------------------------------------------------------------
  // "Now" — computed ONCE per render pass and passed down to every
  // downstream computation. Avoids calling Date.now() in multiple
  // places (which React's purity linter flags).
  //
  // Note: we deliberately call it inline (not in useState/useEffect)
  // so it reflects the current render. The value only matters when
  // the page re-renders, which happens when the user changes the
  // date filter or Firestore sends new data.
  // -------------------------------------------------------------
  // eslint-disable-next-line react-hooks/purity
  const nowMs = new Date().getTime();

  // ---------- Auth guard ----------
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (user) => {
      if (!user) {
        router.push('/login');
        return;
      }
      setLoading(false);
    });
    return () => unsub();
  }, [router]);

  // ---------- Real-time listeners ----------
  useEffect(() => {
    if (loading) return;

    const unsubPatients = onSnapshot(
      query(collection(db, DB_PATHS.patients), orderBy('createdAt', 'desc')),
      (snapshot) => {
        const data: PatientRow[] = snapshot.docs.map((doc) => {
          const raw = doc.data() as Record<string, unknown>;
          const createdRaw = raw.createdAt as
            | Timestamp
            | string
            | undefined
            | null;
          let dateStr = 'N/A';
          let ms = 0;

          if (createdRaw) {
            if (
              typeof createdRaw === 'object' &&
              createdRaw !== null &&
              typeof (createdRaw as Timestamp).toDate === 'function'
            ) {
              const dt = (createdRaw as Timestamp).toDate();
              dateStr = dt.toLocaleDateString();
              ms = dt.getTime();
            } else if (typeof createdRaw === 'string') {
              const dt = new Date(createdRaw);
              dateStr = dt.toLocaleDateString();
              ms = dt.getTime();
            }
          }

          return {
            id: doc.id,
            name: (raw.name as string) ?? undefined,
            status: (raw.status as string) ?? undefined,
            visits: (raw.visits as number) ?? undefined,
            createdAt: createdRaw ?? undefined,
            _createdDate: dateStr,
            _createdMs: ms,
          };
        });
        setPatients(data);
      }
    );

    const unsubAppointments = onSnapshot(
      collection(db, DB_PATHS.appointments),
      (snapshot) => {
        const data: AppointmentRow[] = snapshot.docs.map((d) => {
          const raw = d.data() as Record<string, unknown>;
          const dtRaw = raw.dateTime as Timestamp | string | undefined | null;
          let ms = 0;
          if (dtRaw) {
            if (
              typeof dtRaw === 'object' &&
              typeof (dtRaw as Timestamp).toDate === 'function'
            ) {
              ms = (dtRaw as Timestamp).toDate().getTime();
            } else if (typeof dtRaw === 'string') {
              ms = new Date(dtRaw).getTime();
            }
          }
          return {
            id: d.id,
            patient: (raw.patient as string) ?? undefined,
            patientName: (raw.patientName as string) ?? undefined,
            status: (raw.status as string) ?? undefined,
            dateTime: dtRaw ?? undefined,
            _ms: ms,
          };
        });
        setAppointments(data);
      }
    );

    const unsubReferrals = onSnapshot(
      collection(db, DB_PATHS.referrals),
      (snapshot) => {
        const data: ReferralRow[] = snapshot.docs.map((d) => {
          const raw = d.data() as Record<string, unknown>;
          return {
            id: d.id,
            status: (raw.status as string) ?? undefined,
          };
        });
        setReferrals(data);
      }
    );

    const unsubChws = onSnapshot(
      collection(db, DB_PATHS.users),
      (snapshot) => {
        const all: ChwRow[] = snapshot.docs.map((d) => {
          const raw = d.data() as Record<string, unknown>;
          return {
            id: d.id,
            role: raw.role as string | string[] | undefined,
            status: (raw.status as string) ?? undefined,
          };
        });
        const chwOnly = all.filter((u) => {
          const role = u.role;
          return typeof role === 'string'
            ? role === 'chw'
            : Array.isArray(role)
              ? role.includes('chw')
              : false;
        });
        setChws(chwOnly);
      }
    );

    const unsubAlerts = onSnapshot(
      collection(db, DB_PATHS.emergencyAlerts),
      (snapshot) => {
        const data: AlertRow[] = snapshot.docs.map((d) => {
          const raw = d.data() as Record<string, unknown>;
          const cRaw = raw.createdAt as
            | Timestamp
            | string
            | undefined
            | null;
          const rRaw = raw.respondedAt as
            | Timestamp
            | string
            | undefined
            | null;
          let createdMs = 0;
          let respondedMs = 0;

          if (cRaw) {
            if (
              typeof cRaw === 'object' &&
              typeof (cRaw as Timestamp).toDate === 'function'
            ) {
              createdMs = (cRaw as Timestamp).toDate().getTime();
            } else if (typeof cRaw === 'string') {
              createdMs = new Date(cRaw).getTime();
            }
          }
          if (rRaw) {
            if (
              typeof rRaw === 'object' &&
              typeof (rRaw as Timestamp).toDate === 'function'
            ) {
              respondedMs = (rRaw as Timestamp).toDate().getTime();
            } else if (typeof rRaw === 'string') {
              respondedMs = new Date(rRaw).getTime();
            }
          }

          return {
            id: d.id,
            createdAt: cRaw ?? undefined,
            respondedAt: rRaw ?? undefined,
            _createdMs: createdMs,
            _respondedMs: respondedMs,
          };
        });
        setAlerts(data);
      }
    );

    return () => {
      unsubPatients();
      unsubAppointments();
      unsubReferrals();
      unsubChws();
      unsubAlerts();
    };
  }, [loading, router]);

  // ---------- DERIVED stats ----------
  const stats = useMemo(() => {
    const criticalCases = patients.filter(
      (p) => p.status === 'Critical'
    ).length;
    const followUps = patients.filter(
      (p) => p.status === 'Needs Follow-up'
    ).length;
    const activeCHWs = chws.filter((c) => c.status === 'Active').length;
    const completedReferrals = referrals.filter(
      (r) => r.status === 'Completed'
    ).length;
    const pendingReferrals = referrals.filter(
      (r) => r.status === 'Pending'
    ).length;

    return {
      totalPatients: patients.length,
      appointments: appointments.length,
      criticalCases,
      followUps,
      activeCHWs,
      totalReferrals: referrals.length,
      completedReferrals,
      pendingReferrals,
    };
  }, [patients, appointments, referrals, chws]);

  // ---------- DERIVED date cutoff ----------
  const cutoffMs = useMemo(() => {
    switch (dateRange) {
      case '7d':
        return nowMs - 7 * DAY_MS;
      case '30d':
        return nowMs - 30 * DAY_MS;
      case '90d':
        return nowMs - 90 * DAY_MS;
      case 'month': {
        const d = new Date(nowMs);
        return new Date(d.getFullYear(), d.getMonth(), 1).getTime();
      }
      case 'all':
      default:
        return 0;
    }
  }, [dateRange, nowMs]);

  // ---------- CHART 1 — Visits per week ----------
  const visitsPerWeek = useMemo(() => {
    const weeks: {
      label: string;
      start: number;
      end: number;
      visits: number;
    }[] = [];
    const now = new Date(nowMs);
    for (let i = 7; i >= 0; i--) {
      const end = new Date(now);
      end.setDate(end.getDate() - i * 7);
      end.setHours(23, 59, 59, 999);
      const start = new Date(end);
      start.setDate(start.getDate() - 6);
      start.setHours(0, 0, 0, 0);
      weeks.push({
        label: `${start.getMonth() + 1}/${start.getDate()}`,
        start: start.getTime(),
        end: end.getTime(),
        visits: 0,
      });
    }
    appointments.forEach((apt) => {
      if (apt._ms < cutoffMs) return;
      const week = weeks.find((w) => apt._ms >= w.start && apt._ms <= w.end);
      if (week) week.visits += 1;
    });
    return weeks;
  }, [appointments, cutoffMs, nowMs]);

  // ---------- CHART 2 — Patient status breakdown ----------
  const patientStatusBreakdown = useMemo(() => {
    const counts: Record<string, number> = {
      Stable: 0,
      'Needs Follow-up': 0,
      Critical: 0,
    };
    patients.forEach((p) => {
      const status = p.status || 'Stable';
      counts[status] = (counts[status] || 0) + 1;
    });
    return Object.entries(counts).map(([name, value]) => ({ name, value }));
  }, [patients]);

  // ---------- CHART 3 — SOS per month ----------
  const sosPerMonth = useMemo(() => {
    const months: {
      label: string;
      start: number;
      end: number;
      alerts: number;
    }[] = [];
    const now = new Date(nowMs);
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const start = d.getTime();
      const end = new Date(
        d.getFullYear(),
        d.getMonth() + 1,
        0,
        23,
        59,
        59,
        999
      ).getTime();
      const label = d.toLocaleString('default', { month: 'short' });
      months.push({ label, start, end, alerts: 0 });
    }
    alerts.forEach((a) => {
      const m = months.find(
        (mm) => a._createdMs >= mm.start && a._createdMs <= mm.end
      );
      if (m) m.alerts += 1;
    });
    return months;
  }, [alerts, nowMs]);

  // ---------- CHART 4 — Appointment outcomes ----------
  const appointmentOutcomes = useMemo(() => {
    const counts: Record<string, number> = {};
    appointments.forEach((a) => {
      if (a._ms < cutoffMs) return;
      const status = a.status || 'Scheduled';
      counts[status] = (counts[status] || 0) + 1;
    });
    return Object.entries(counts).map(([name, value]) => ({ name, value }));
  }, [appointments, cutoffMs]);

  // ---------- STAT — Avg SOS response ----------
  const averageSosResponse = useMemo(() => {
    const responded = alerts.filter(
      (a) => a._createdMs > 0 && a._respondedMs > 0
    );
    if (responded.length === 0) return null;
    const totalMs = responded.reduce(
      (sum, a) => sum + (a._respondedMs - a._createdMs),
      0
    );
    return Math.round(totalMs / responded.length / 60000);
  }, [alerts]);

  // ---------- Most active patients ----------
  const mostActivePatients = useMemo(() => {
    const counts: Record<
      string,
      { name: string; visits: number; lastVisit: string }
    > = {};
    appointments.forEach((apt) => {
      const key = apt.patient || apt.patientName || 'Unknown';
      if (!counts[key])
        counts[key] = { name: key, visits: 0, lastVisit: 'N/A' };
      counts[key].visits += 1;
    });
    if (Object.keys(counts).length === 0) {
      patients.forEach((p) => {
        if (p.visits) {
          counts[p.name || 'Unknown'] = {
            name: p.name || 'Unknown',
            visits: Number(p.visits),
            lastVisit: p._createdDate || 'N/A',
          };
        }
      });
    }
    return Object.values(counts)
      .sort((a, b) => b.visits - a.visits)
      .slice(0, 5);
  }, [appointments, patients]);

  // ---------- Recent registrations ----------
  const recentRegistrations = useMemo(() => {
    const sevenDaysAgo = nowMs - 7 * DAY_MS;
    return patients.filter((p) => p._createdMs >= sevenDaysAgo).length;
  }, [patients, nowMs]);

  const completionRate =
    stats.totalReferrals > 0
      ? Math.round((stats.completedReferrals / stats.totalReferrals) * 100)
      : 0;

  const criticalRate =
    stats.totalPatients > 0
      ? Math.round((stats.criticalCases / stats.totalPatients) * 100)
      : 0;

  // ---------- Export handlers ----------
  const handleExportCsv = () => {
    const rows: {
      section: string;
      label: string;
      value: number | string;
    }[] = [];
    visitsPerWeek.forEach((w) =>
      rows.push({
        section: 'Visits per week',
        label: w.label,
        value: w.visits,
      })
    );
    patientStatusBreakdown.forEach((p) =>
      rows.push({
        section: 'Patient status',
        label: p.name,
        value: p.value,
      })
    );
    sosPerMonth.forEach((m) =>
      rows.push({
        section: 'SOS per month',
        label: m.label,
        value: m.alerts,
      })
    );
    appointmentOutcomes.forEach((a) =>
      rows.push({
        section: 'Appointment outcomes',
        label: a.name,
        value: a.value,
      })
    );
    rows.push({
      section: 'Summary',
      label: 'Total patients',
      value: stats.totalPatients,
    });
    rows.push({
      section: 'Summary',
      label: 'Appointments',
      value: stats.appointments,
    });
    rows.push({
      section: 'Summary',
      label: 'Critical cases',
      value: stats.criticalCases,
    });
    rows.push({
      section: 'Summary',
      label: 'Active CHWs',
      value: stats.activeCHWs,
    });
    rows.push({
      section: 'Summary',
      label: 'Total referrals',
      value: stats.totalReferrals,
    });
    rows.push({
      section: 'Summary',
      label: 'Avg SOS response (min)',
      value: averageSosResponse ?? 'N/A',
    });

    const csv = Papa.unparse(rows);
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `health-bridge-analytics-${new Date(nowMs)
      .toISOString()
      .slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handlePrintPdf = () => {
    window.print();
  };

  const formatResponseTime = (minutes: number | null) => {
    if (minutes === null) return 'N/A';
    if (minutes < 60) return `${minutes} min`;
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return `${h}h ${m}m`;
  };

  if (loading) {
    return (
      <div
        style={{
          display: 'flex',
          justifyContent: 'center',
          padding: '50px',
          color: '#666',
        }}
      >
        Loading analytics...
      </div>
    );
  }

  const statCards = [
    {
      label: 'Total Patients',
      value: stats.totalPatients,
      sub: `${recentRegistrations} new this week`,
      icon: '👥',
      color: '#2563eb',
    },
    {
      label: 'Appointments',
      value: stats.appointments,
      sub: 'All time',
      icon: '📅',
      color: '#10b981',
    },
    {
      label: 'Critical Cases',
      value: stats.criticalCases,
      sub: `${criticalRate}% of total`,
      icon: '🚨',
      color: '#ef4444',
    },
    {
      label: 'Active CHWs',
      value: stats.activeCHWs,
      sub: `${chws.length} total`,
      icon: '🩺',
      color: '#8b5cf6',
    },
    {
      label: 'Total Referrals',
      value: stats.totalReferrals,
      sub: `${completionRate}% completed`,
      icon: '📤',
      color: '#f59e0b',
    },
    {
      label: 'Pending Referrals',
      value: stats.pendingReferrals,
      sub: 'Awaiting action',
      icon: '⏳',
      color: '#ef4444',
    },
    {
      label: 'Follow-ups',
      value: stats.followUps,
      sub: 'Needs attention',
      icon: '📋',
      color: '#0ea5e9',
    },
    {
      label: 'SOS Alerts',
      value: alerts.length,
      sub: 'All time',
      icon: '🚨',
      color: '#ef4444',
    },
  ];

  return (
    <Layout>
      <style jsx global>{`
        @media print {
          body {
            background: white;
          }
          .no-print {
            display: none !important;
          }
        }
      `}</style>

      <div style={styles.container}>
        {/* Header */}
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Analytics</h1>
            <p style={styles.pageSubtitle}>
              Live practice statistics — updates in real time
            </p>
          </div>
          <div style={styles.liveBadge} className="no-print">
            <span style={styles.liveDot}></span>
            LIVE
          </div>
        </div>

        {/* Filter + Export bar */}
        <div style={styles.filterBar} className="no-print">
          <div style={styles.filterGroup}>
            <label style={styles.filterLabel}>Date range</label>
            <select
              value={dateRange}
              onChange={(e) => setDateRange(e.target.value as DateRange)}
              style={styles.select}
            >
              <option value="7d">Last 7 days</option>
              <option value="30d">Last 30 days</option>
              <option value="90d">Last 90 days</option>
              <option value="month">This month</option>
              <option value="all">All time</option>
            </select>
          </div>
          <div style={{ flex: 1 }} />
          <button onClick={handleExportCsv} style={styles.exportButton}>
            📄 Export CSV
          </button>
          <button onClick={handlePrintPdf} style={styles.exportButton}>
            🖨️ Print / PDF
          </button>
        </div>

        {/* Stats Grid */}
        <div style={styles.statsGrid}>
          {statCards.map((stat, index) => (
            <div
              key={index}
              style={styles.statCard}
              onMouseEnter={(e) =>
                (e.currentTarget.style.boxShadow =
                  '0 6px 12px rgba(0,0,0,0.15)')
              }
              onMouseLeave={(e) =>
                (e.currentTarget.style.boxShadow =
                  '0 2px 6px rgba(0,0,0,0.1)')
              }
            >
              <div style={styles.statHeader}>
                <div
                  style={{
                    ...styles.statIconWrap,
                    backgroundColor: `${stat.color}15`,
                  }}
                >
                  <span style={styles.statIcon}>{stat.icon}</span>
                </div>
              </div>
              <p style={{ ...styles.statValue, color: stat.color }}>
                {stat.value}
              </p>
              <p style={styles.statLabel}>{stat.label}</p>
              <p style={styles.statSub}>{stat.sub}</p>
            </div>
          ))}
        </div>

        {/* Charts Row 1 */}
        <div style={styles.chartsRow}>
          <div style={styles.chartCard}>
            <h3 style={styles.chartTitle}>Visits per Week</h3>
            <p style={styles.chartSubtitle}>Last 8 weeks</p>
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={visitsPerWeek}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis
                  dataKey="label"
                  tick={{ fontSize: 11, fill: '#666' }}
                />
                <YAxis
                  tick={{ fontSize: 11, fill: '#666' }}
                  allowDecimals={false}
                />
                <Tooltip
                  contentStyle={{
                    borderRadius: 8,
                    border: '1px solid #e5e7eb',
                    fontSize: 12,
                  }}
                />
                <Bar
                  dataKey="visits"
                  fill={CHART_COLOURS.navy}
                  radius={[4, 4, 0, 0]}
                />
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div style={styles.chartCard}>
            <h3 style={styles.chartTitle}>
              Patient Status Breakdown
            </h3>
            <p style={styles.chartSubtitle}>All patients</p>
            <ResponsiveContainer width="100%" height={260}>
              <PieChart>
                <Pie
                  data={patientStatusBreakdown}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={90}
                  label={(entry: { name?: string; value?: number }) =>
                    `${entry.name}: ${entry.value}`
                  }
                >
                  {patientStatusBreakdown.map((entry, i) => (
                    <Cell
                      key={i}
                      fill={
                        STATUS_COLOURS[entry.name] || CHART_COLOURS.gray
                      }
                    />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    borderRadius: 8,
                    border: '1px solid #e5e7eb',
                    fontSize: 12,
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Charts Row 2 */}
        <div style={styles.chartsRow}>
          <div style={styles.chartCard}>
            <h3 style={styles.chartTitle}>SOS Alerts per Month</h3>
            <p style={styles.chartSubtitle}>
              Last 6 months · Avg response:{' '}
              <b>{formatResponseTime(averageSosResponse)}</b>
            </p>
            <ResponsiveContainer width="100%" height={260}>
              <LineChart data={sosPerMonth}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis
                  dataKey="label"
                  tick={{ fontSize: 11, fill: '#666' }}
                />
                <YAxis
                  tick={{ fontSize: 11, fill: '#666' }}
                  allowDecimals={false}
                />
                <Tooltip
                  contentStyle={{
                    borderRadius: 8,
                    border: '1px solid #e5e7eb',
                    fontSize: 12,
                  }}
                />
                <Line
                  type="monotone"
                  dataKey="alerts"
                  stroke={CHART_COLOURS.red}
                  strokeWidth={3}
                  dot={{ r: 5, fill: CHART_COLOURS.red }}
                  activeDot={{ r: 7 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>

          <div style={styles.chartCard}>
            <h3 style={styles.chartTitle}>Appointment Outcomes</h3>
            <p style={styles.chartSubtitle}>
              {dateRange === 'all' ? 'All time' : 'Filtered by date range'}
            </p>
            <ResponsiveContainer width="100%" height={260}>
              <PieChart>
                <Pie
                  data={appointmentOutcomes}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={90}
                  label={(entry: { name?: string; value?: number }) =>
                    `${entry.name}: ${entry.value}`
                  }
                >
                  {appointmentOutcomes.map((entry, i) => (
                    <Cell
                      key={i}
                      fill={
                        OUTCOME_COLOURS[entry.name] || CHART_COLOURS.gray
                      }
                    />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    borderRadius: 8,
                    border: '1px solid #e5e7eb',
                    fontSize: 12,
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Two-Column Layout */}
        <div style={styles.twoColumn}>
          <div style={styles.tableContainer}>
            <h3 style={styles.tableTitle}>Most Active Patients</h3>
            <p style={styles.tableSubtitle}>
              Based on appointment frequency (live)
            </p>
            <div style={styles.patientList}>
              {mostActivePatients.length === 0 ? (
                <p style={{ color: '#888', padding: '16px 0' }}>
                  No appointment data yet.
                </p>
              ) : (
                mostActivePatients.map((patient, index) => (
                  <div
                    key={index}
                    style={styles.patientRow}
                    onMouseEnter={(e) =>
                      (e.currentTarget.style.backgroundColor = '#f9fafb')
                    }
                    onMouseLeave={(e) =>
                      (e.currentTarget.style.backgroundColor =
                        'transparent')
                    }
                  >
                    <div style={styles.patientRank}>
                      <span
                        style={{
                          ...styles.rankNumber,
                          ...(index === 0 ? styles.rankGold : {}),
                          ...(index === 1 ? styles.rankSilver : {}),
                          ...(index === 2 ? styles.rankBronze : {}),
                        }}
                      >
                        {index + 1}
                      </span>
                    </div>
                    <div style={styles.patientInfo}>
                      <p style={styles.patientName}>{patient.name}</p>
                      <p style={styles.patientMeta}>
                        Last visit: {patient.lastVisit}
                      </p>
                    </div>
                    <div style={styles.patientVisits}>
                      <p style={styles.visitsNumber}>{patient.visits}</p>
                      <p style={styles.visitsLabel}>visits</p>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          <div style={styles.tableContainer}>
            <h3 style={styles.tableTitle}>
              Referral Status Breakdown
            </h3>
            <p style={styles.tableSubtitle}>
              Live snapshot of the referral pipeline
            </p>
            {[
              {
                label: 'Completed',
                value: stats.completedReferrals,
                total: stats.totalReferrals,
                color: '#10b981',
              },
              {
                label: 'Pending',
                value: stats.pendingReferrals,
                total: stats.totalReferrals,
                color: '#ef4444',
              },
              {
                label: 'Other / In Progress',
                value:
                  stats.totalReferrals -
                  stats.completedReferrals -
                  stats.pendingReferrals,
                total: stats.totalReferrals,
                color: '#f59e0b',
              },
            ].map((row, i) => {
              const pct =
                row.total > 0
                  ? Math.round((row.value / row.total) * 100)
                  : 0;
              return (
                <div key={i} style={styles.breakdownRow}>
                  <div style={styles.breakdownHeader}>
                    <span style={styles.breakdownLabel}>{row.label}</span>
                    <span style={styles.breakdownValue}>
                      {row.value}{' '}
                      <span style={styles.breakdownPct}>({pct}%)</span>
                    </span>
                  </div>
                  <div style={styles.progressBar}>
                    <div
                      style={{
                        ...styles.progressFill,
                        width: `${pct}%`,
                        backgroundColor: row.color,
                      }}
                    ></div>
                  </div>
                </div>
              );
            })}
            <div style={styles.miniStats}>
              <div style={styles.miniStat}>
                <p style={styles.miniStatValue}>
                  {stats.totalPatients}
                </p>
                <p style={styles.miniStatLabel}>Patients</p>
              </div>
              <div style={styles.miniStat}>
                <p style={styles.miniStatValue}>
                  {stats.appointments}
                </p>
                <p style={styles.miniStatLabel}>Appointments</p>
              </div>
              <div style={styles.miniStat}>
                <p style={styles.miniStatValue}>
                  {stats.totalReferrals}
                </p>
                <p style={styles.miniStatLabel}>Referrals</p>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Summary Bar */}
        <div style={styles.summaryBar}>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>{stats.totalPatients}</p>
            <p style={styles.summaryLabel}>Total Patients</p>
          </div>
          <div style={styles.summaryDivider}></div>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>{stats.criticalCases}</p>
            <p style={styles.summaryLabel}>Critical Cases</p>
          </div>
          <div style={styles.summaryDivider}></div>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>{stats.activeCHWs}</p>
            <p style={styles.summaryLabel}>Active CHWs</p>
          </div>
          <div style={styles.summaryDivider}></div>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>{completionRate}%</p>
            <p style={styles.summaryLabel}>Referral Completion</p>
          </div>
          <div style={styles.summaryDivider}></div>
          <div style={styles.summaryItem}>
            <p style={styles.summaryNumber}>
              {formatResponseTime(averageSosResponse)}
            </p>
            <p style={styles.summaryLabel}>Avg SOS Response</p>
          </div>
        </div>
      </div>
    </Layout>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    padding: '24px',
    backgroundColor: '#f9fafb',
    fontFamily: "'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
    minHeight: '100vh',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '24px',
    flexWrap: 'wrap',
    gap: '12px',
  },
  pageTitle: {
    fontSize: '28px',
    fontWeight: 'bold',
    margin: 0,
    color: '#1a1a2e',
  },
  pageSubtitle: {
    color: '#666',
    marginTop: '8px',
    marginBottom: 0,
    fontSize: '14px',
  },
  liveBadge: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    padding: '6px 14px',
    backgroundColor: '#d1fae5',
    color: '#065f46',
    borderRadius: '20px',
    fontSize: '12px',
    fontWeight: 'bold',
    letterSpacing: '0.5px',
  },
  liveDot: {
    width: '8px',
    height: '8px',
    borderRadius: '50%',
    backgroundColor: '#10b981',
    display: 'inline-block',
  },
  filterBar: {
    display: 'flex',
    alignItems: 'flex-end',
    gap: '12px',
    backgroundColor: 'white',
    padding: '16px',
    borderRadius: '12px',
    marginBottom: '20px',
    boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
    flexWrap: 'wrap',
  },
  filterGroup: { display: 'flex', flexDirection: 'column', gap: '4px' },
  filterLabel: {
    fontSize: '11px',
    fontWeight: 600,
    color: '#6b7280',
    textTransform: 'uppercase',
    letterSpacing: '0.5px',
  },
  select: {
    padding: '8px 12px',
    borderRadius: '8px',
    border: '1px solid #d1d5db',
    fontSize: '14px',
    backgroundColor: 'white',
    cursor: 'pointer',
    outline: 'none',
  },
  exportButton: {
    padding: '10px 16px',
    borderRadius: '8px',
    border: '1px solid #d1d5db',
    backgroundColor: 'white',
    color: '#1a1a2e',
    fontSize: '13px',
    fontWeight: 500,
    cursor: 'pointer',
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
    gap: '20px',
    marginBottom: '24px',
  },
  statCard: {
    backgroundColor: 'white',
    padding: '20px',
    borderRadius: '14px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    transition: 'box-shadow 0.2s ease-in-out',
  },
  statHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '14px',
  },
  statIconWrap: {
    width: '44px',
    height: '44px',
    borderRadius: '12px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  statIcon: { fontSize: '22px' },
  statValue: {
    fontSize: '32px',
    fontWeight: 'bold',
    margin: 0,
    lineHeight: 1.1,
  },
  statLabel: {
    fontSize: '14px',
    color: '#333',
    fontWeight: 500,
    margin: '6px 0 0',
  },
  statSub: { fontSize: '12px', color: '#888', margin: '4px 0 0' },
  chartsRow: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '24px',
    marginBottom: '24px',
  },
  chartCard: {
    backgroundColor: 'white',
    borderRadius: '14px',
    padding: '24px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
  },
  chartTitle: {
    fontSize: '18px',
    fontWeight: 600,
    margin: 0,
    color: '#1a1a2e',
  },
  chartSubtitle: { fontSize: '13px', color: '#888', margin: '4px 0 20px' },
  twoColumn: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '24px',
    marginBottom: '24px',
  },
  tableContainer: {
    backgroundColor: 'white',
    borderRadius: '14px',
    padding: '24px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
  },
  tableTitle: {
    fontSize: '18px',
    fontWeight: 600,
    margin: 0,
    color: '#1a1a2e',
  },
  tableSubtitle: { fontSize: '13px', color: '#888', margin: '4px 0 20px' },
  patientList: { display: 'flex', flexDirection: 'column', gap: '4px' },
  patientRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '15px',
    padding: '12px 8px',
    borderRadius: '8px',
    borderBottom: '1px solid #f0f0f0',
    transition: 'background-color 0.2s ease-in-out',
  },
  patientRank: { width: '34px' },
  rankNumber: {
    fontSize: '15px',
    fontWeight: 'bold',
    color: '#666',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: '28px',
    height: '28px',
    borderRadius: '50%',
    backgroundColor: '#f3f4f6',
  },
  rankGold: { backgroundColor: '#fef3c7', color: '#92400e' },
  rankSilver: { backgroundColor: '#e5e7eb', color: '#374151' },
  rankBronze: { backgroundColor: '#fed7aa', color: '#9a3412' },
  patientInfo: { flex: 1 },
  patientName: {
    fontSize: '15px',
    fontWeight: 500,
    margin: 0,
    color: '#1a1a2e',
  },
  patientMeta: { fontSize: '12px', color: '#888', margin: '3px 0 0' },
  patientVisits: { textAlign: 'right' },
  visitsNumber: {
    fontSize: '18px',
    fontWeight: 'bold',
    margin: 0,
    color: '#2563eb',
  },
  visitsLabel: {
    fontSize: '10px',
    color: '#888',
    margin: 0,
    textTransform: 'uppercase',
    letterSpacing: '0.5px',
  },
  breakdownRow: { marginBottom: '18px' },
  breakdownHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    marginBottom: '8px',
    fontSize: '14px',
  },
  breakdownLabel: { color: '#333', fontWeight: 500 },
  breakdownValue: { color: '#1a1a2e', fontWeight: 600 },
  breakdownPct: { color: '#888', fontWeight: 400, fontSize: '12px' },
  progressBar: {
    height: '8px',
    backgroundColor: '#f3f4f6',
    borderRadius: '4px',
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: '4px',
    transition: 'width 0.5s ease',
  },
  miniStats: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '12px',
    marginTop: '24px',
    paddingTop: '20px',
    borderTop: '1px solid #f0f0f0',
  },
  miniStat: {
    textAlign: 'center',
    padding: '12px 8px',
    backgroundColor: '#f9fafb',
    borderRadius: '10px',
  },
  miniStatValue: {
    fontSize: '20px',
    fontWeight: 'bold',
    margin: 0,
    color: '#2563eb',
  },
  miniStatLabel: { fontSize: '11px', color: '#666', margin: '4px 0 0' },
  summaryBar: {
    backgroundColor: 'white',
    borderRadius: '14px',
    padding: '24px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    display: 'flex',
    justifyContent: 'space-around',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: '16px',
  },
  summaryItem: { textAlign: 'center', minWidth: '100px' },
  summaryNumber: {
    fontSize: '24px',
    fontWeight: 'bold',
    margin: 0,
    color: '#2563eb',
  },
  summaryLabel: { fontSize: '12px', color: '#666', margin: '4px 0 0' },
  summaryDivider: {
    width: '1px',
    height: '40px',
    backgroundColor: '#e5e7eb',
  },
};