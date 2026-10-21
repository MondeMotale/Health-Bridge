import { useEffect, useState, useMemo, useCallback } from 'react';
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
  Timestamp,
} from 'firebase/firestore';
import Layout from '../components/Layout';
import { DB_PATHS } from '../lib/dbPaths';

type DateRange = 'all' | '7d' | '30d' | 'month';
type StatusFilter = 'all' | 'new' | 'read';
type SortOrder = 'newest' | 'oldest';

interface ReportRow {
  id: string;
  title: string;
  content: string;
  chwName: string;
  chwId: string;
  chwEmail: string;
  isRead: boolean;
  _displayDate: string;
  _rawDate: Date | null;
}

interface UserRow {
  id: string;
  uid?: string;
  displayName?: string;
  name?: string;
  email?: string;
}

export default function Reports() {
  const router = useRouter();
  const [reports, setReports] = useState<ReportRow[]>([]);
  const [users, setUsers] = useState<UserRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [reportsLoading, setReportsLoading] = useState(true);
  const [error, setError] = useState('');

  const [search, setSearch] = useState('');
  const [dateRange, setDateRange] = useState<DateRange>('all');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [submitterFilter, setSubmitterFilter] = useState<string>('all');
  const [sortOrder, setSortOrder] = useState<SortOrder>('newest');

  // ---- Auth guard ----
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

  // ---- Live reports ----
  useEffect(() => {
    if (loading) return;
    const q = query(
      collection(db, DB_PATHS.reports),
      orderBy('createdAt', 'desc')
    );
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const data: ReportRow[] = snapshot.docs.map((d) => {
          const raw = d.data() as Record<string, unknown>;
          let displayDate = 'Just now';
          let rawDate: Date | null = null;
          const createdAtRaw = raw.createdAt as
            | Timestamp
            | string
            | undefined
            | null;

          if (createdAtRaw) {
            try {
              if (typeof createdAtRaw === 'string') {
                const parsed = new Date(createdAtRaw);
                if (!isNaN(parsed.getTime())) {
                  rawDate = parsed;
                  displayDate = parsed.toLocaleDateString();
                }
              } else if (
                typeof createdAtRaw === 'object' &&
                typeof (createdAtRaw as Timestamp).toDate === 'function'
              ) {
                const parsed = (createdAtRaw as Timestamp).toDate();
                rawDate = parsed;
                displayDate = parsed.toLocaleDateString();
              }
            } catch {
              displayDate = 'Unknown';
            }
          }

          return {
            id: d.id,
            title: (raw.title as string) || 'Untitled Report',
            content: (raw.content as string) || 'No content',
            chwName: (raw.chwName as string) || '',
            chwId:
              (raw.chwId as string) ||
              (raw.userId as string) ||
              (raw.submittedBy as string) ||
              '',
            chwEmail:
              (raw.chwEmail as string) || (raw.email as string) || '',
            isRead: Boolean(raw.isRead),
            _displayDate: displayDate,
            _rawDate: rawDate,
          };
        });
        setReports(data);
        setReportsLoading(false);
        setError((current) =>
          current.startsWith('Failed to load reports:') ? '' : current
        );
      },
      (err) => {
        setReportsLoading(false);
        setError('Failed to load reports: ' + err.message);
      }
    );
    return () => unsubscribe();
  }, [loading]);

  // ---- Live users ----
  useEffect(() => {
    if (loading) return;
    const q = query(collection(db, DB_PATHS.users));
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        setUsers(
          snapshot.docs.map((d) => {
            const raw = d.data() as Record<string, unknown>;
            return {
              id: d.id,
              uid: raw.uid as string | undefined,
              displayName: raw.displayName as string | undefined,
              name: raw.name as string | undefined,
              email: raw.email as string | undefined,
            };
          })
        );
      },
      (err) => setError('Failed to load users: ' + err.message)
    );
    return () => unsubscribe();
  }, [loading]);

  // ---- Resolve CHW name (memoized so it can be a dependency) ----
  const resolveChwName = useCallback(
    (report: ReportRow): string => {
      const rawName = (report.chwName || '').trim();
      const placeholders = ['chw', 'unknown', 'unnamed', 'user', '-', ''];
      if (rawName && !placeholders.includes(rawName.toLowerCase())) {
        return rawName;
      }

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

      if (report.chwEmail) {
        const user = users.find(
          (u) =>
            (u.email || '').toLowerCase() ===
            report.chwEmail.toLowerCase()
        );
        if (user) {
          return user.displayName || user.name || user.email || 'CHW';
        }
      }

      if (report.title) {
        const titleLower = report.title.toLowerCase();
        const matchedUser = users.find((u) => {
          const name = (u.displayName || u.name || '')
            .toLowerCase()
            .trim();
          if (!name) return false;
          const firstName = name.split(' ')[0];
          return titleLower.includes(firstName) && firstName.length > 2;
        });
        if (matchedUser) {
          return matchedUser.displayName || matchedUser.name || 'CHW';
        }
      }

      return 'Unknown CHW';
    },
    [users]
  );

  const handleMarkAsRead = async (id: string) => {
    try {
      await updateDoc(doc(db, DB_PATHS.reports, id), { isRead: true });
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      setError('Failed to mark as read: ' + message);
    }
  };

  // ---- Unique submitters ----
  const uniqueSubmitters = useMemo(() => {
    const names = new Set<string>();
    reports.forEach((r) => {
      const name = resolveChwName(r);
      if (name && name !== 'Unknown CHW') names.add(name);
    });
    return Array.from(names).sort();
  }, [reports, resolveChwName]);

  // ---- Apply filters ----
  const filteredReports = useMemo(() => {
    const now = new Date();

    const cutoff = (() => {
      if (dateRange === '7d')
        return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      if (dateRange === '30d')
        return new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      if (dateRange === 'month')
        return new Date(now.getFullYear(), now.getMonth(), 1);
      return null;
    })();

    const q = search.trim().toLowerCase();

    return reports
      .filter((r) => {
        if (q) {
          const chwName = resolveChwName(r).toLowerCase();
          const match =
            r.title.toLowerCase().includes(q) ||
            r.content.toLowerCase().includes(q) ||
            chwName.includes(q);
          if (!match) return false;
        }
        if (cutoff && r._rawDate instanceof Date) {
          if (r._rawDate < cutoff) return false;
        }
        if (statusFilter === 'new' && r.isRead) return false;
        if (statusFilter === 'read' && !r.isRead) return false;
        if (submitterFilter !== 'all') {
          if (resolveChwName(r) !== submitterFilter) return false;
        }
        return true;
      })
      .sort((a, b) => {
        const aT = a._rawDate instanceof Date ? a._rawDate.getTime() : 0;
        const bT = b._rawDate instanceof Date ? b._rawDate.getTime() : 0;
        return sortOrder === 'newest' ? bT - aT : aT - bT;
      });
  }, [
    reports,
    resolveChwName,
    search,
    dateRange,
    statusFilter,
    submitterFilter,
    sortOrder,
  ]);

  const resetFilters = () => {
    setSearch('');
    setDateRange('all');
    setStatusFilter('all');
    setSubmitterFilter('all');
    setSortOrder('newest');
  };

  const hasActiveFilters =
    search !== '' ||
    dateRange !== 'all' ||
    statusFilter !== 'all' ||
    submitterFilter !== 'all' ||
    sortOrder !== 'newest';

  const unreadCount = reports.filter((r) => !r.isRead).length;

  if (loading) {
    return (
      <div
        style={{
          display: 'flex',
          justifyContent: 'center',
          padding: '50px',
        }}
        role="status"
      >
        Checking your account…
      </div>
    );
  }

  return (
    <Layout>
      <div style={styles.container}>
        {error && (
          <div role="alert" style={styles.errorBanner}>
            <span>⚠️ {error}</span>
            <button
              onClick={() => setError('')}
              style={styles.errorClose}
              aria-label="Dismiss error"
            >
              ×
            </button>
          </div>
        )}

        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>CHW Reports</h1>
            <p style={styles.pageSubtitle}>
              Live reports submitted by CHWs.
            </p>
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

        {/* ---------- FILTER BAR ---------- */}
        <div style={styles.filterBar}>
          <div style={styles.filterGroup}>
            <label style={styles.filterLabel}>Search</label>
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by title, content, or CHW name..."
              maxLength={200}
              style={styles.textInput}
            />
          </div>

          <div style={styles.filterGroup}>
            <label style={styles.filterLabel}>Date</label>
            <select
              value={dateRange}
              onChange={(e) => setDateRange(e.target.value as DateRange)}
              style={styles.select}
            >
              <option value="all">All time</option>
              <option value="7d">Last 7 days</option>
              <option value="30d">Last 30 days</option>
              <option value="month">This month</option>
            </select>
          </div>

          <div style={styles.filterGroup}>
            <label style={styles.filterLabel}>Status</label>
            <select
              value={statusFilter}
              onChange={(e) =>
                setStatusFilter(e.target.value as StatusFilter)
              }
              style={styles.select}
            >
              <option value="all">All</option>
              <option value="new">New</option>
              <option value="read">Read</option>
            </select>
          </div>

          <div style={styles.filterGroup}>
            <label style={styles.filterLabel}>CHW</label>
            <select
              value={submitterFilter}
              onChange={(e) => setSubmitterFilter(e.target.value)}
              style={styles.select}
            >
              <option value="all">All CHWs</option>
              {uniqueSubmitters.map((name) => (
                <option key={name} value={name}>
                  {name}
                </option>
              ))}
            </select>
          </div>

          <div style={styles.filterGroup}>
            <label style={styles.filterLabel}>Sort</label>
            <select
              value={sortOrder}
              onChange={(e) =>
                setSortOrder(e.target.value as SortOrder)
              }
              style={styles.select}
            >
              <option value="newest">Newest first</option>
              <option value="oldest">Oldest first</option>
            </select>
          </div>

          {hasActiveFilters && (
            <button onClick={resetFilters} style={styles.resetButton}>
              Clear filters
            </button>
          )}
        </div>

        {/* ---------- RESULT COUNT ---------- */}
        <div style={styles.resultCount}>
          Showing <b>{filteredReports.length}</b> of{' '}
          <b>{reports.length}</b> reports
        </div>

        {/* ---------- LIST ---------- */}
        {reportsLoading ? (
          <div role="status" style={styles.emptyBox}>
            Loading reports…
          </div>
        ) : error.startsWith('Failed to load reports:') ? (
          <div style={styles.emptyBox} role="alert">
            Reports are unavailable. Refresh the page to try again.
          </div>
        ) : reports.length === 0 ? (
          <div style={styles.emptyBox}>
            <p>No reports have been submitted yet.</p>
          </div>
        ) : filteredReports.length === 0 ? (
          <div style={styles.emptyBox}>
            <p>No reports match your filters.</p>
            <button onClick={resetFilters} style={styles.emptyButton}>
              Clear filters
            </button>
          </div>
        ) : (
          <div
            role="list"
            aria-label="CHW reports"
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: '16px',
            }}
          >
            {filteredReports.map((report) => {
              const chwName = resolveChwName(report);
              return (
                <div
                  key={report.id}
                  role="listitem"
                  style={{
                    backgroundColor: 'white',
                    padding: '20px',
                    borderRadius: '12px',
                    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
                    borderLeft: report.isRead
                      ? '4px solid #10b981'
                      : '4px solid #ef4444',
                  }}
                >
                  <div
                  style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      marginBottom: '8px',
                    }}
                  >
                    <h3
                      style={{
                        margin: 0,
                        fontSize: '18px',
                        fontWeight: 'bold',
                        color: '#1a1a2e',
                      }}
                    >
                      {report.title}
                    </h3>
                    <div
                      style={{
                        display: 'flex',
                        gap: '10px',
                        alignItems: 'center',
                      }}
                    >
                      {!report.isRead && (
                        <span
                          style={{
                            backgroundColor: '#ef4444',
                            color: 'white',
                            padding: '4px 12px',
                            borderRadius: '20px',
                            fontSize: '12px',
                            fontWeight: 'bold',
                          }}
                        >
                          New
                        </span>
                      )}
                      <span style={{ fontSize: '12px', color: '#888' }}>
                        {report._displayDate}
                      </span>
                    </div>
                  </div>

                  <p
                    style={{
                      fontSize: '14px',
                      color: '#555',
                      margin: '0 0 12px 0',
                      lineHeight: 1.6,
                    }}
                  >
                    {report.content}
                  </p>

                  <div
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      marginTop: '12px',
                      borderTop: '1px solid #f0f0f0',
                      paddingTop: '12px',
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                      }}
                    >
                      <div
                        style={{
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
                        }}
                      >
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

const styles: Record<string, React.CSSProperties> = {
  container: {
    padding: '24px',
    backgroundColor: '#f9fafb',
    fontFamily: "'Segoe UI', Roboto, sans-serif",
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '20px',
  },
  pageTitle: {
    fontSize: '26px',
    fontWeight: 'bold',
    margin: 0,
    color: '#1a1a2e',
  },
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
  filterBar: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '12px',
    alignItems: 'flex-end',
    backgroundColor: 'white',
    padding: '16px',
    borderRadius: '12px',
    marginBottom: '16px',
    boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
  },
  filterGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
    minWidth: '140px',
    flex: '1 1 auto',
  },
  filterLabel: {
    fontSize: '11px',
    fontWeight: '600',
    color: '#6b7280',
    textTransform: 'uppercase',
    letterSpacing: '0.5px',
  },
  textInput: {
    padding: '8px 12px',
    borderRadius: '8px',
    border: '1px solid #d1d5db',
    fontSize: '14px',
    outline: 'none',
    minWidth: '220px',
  },
  select: {
    padding: '8px 12px',
    borderRadius: '8px',
    border: '1px solid #d1d5db',
    fontSize: '14px',
    backgroundColor: 'white',
    outline: 'none',
    cursor: 'pointer',
  },
  resetButton: {
    padding: '8px 16px',
    borderRadius: '8px',
    border: '1px solid #d1d5db',
    backgroundColor: 'white',
    color: '#374151',
    fontSize: '13px',
    fontWeight: '500',
    cursor: 'pointer',
  },
  resultCount: {
    fontSize: '13px',
    color: '#6b7280',
    marginBottom: '12px',
  },
  emptyBox: {
    backgroundColor: 'white',
    padding: '40px',
    borderRadius: '12px',
    textAlign: 'center',
    color: '#888',
  },
  emptyButton: {
    marginTop: '12px',
    padding: '8px 16px',
    borderRadius: '8px',
    border: '1px solid #d1d5db',
    backgroundColor: 'white',
    cursor: 'pointer',
  },
};