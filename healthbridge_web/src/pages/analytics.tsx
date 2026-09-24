import Layout from '../components/Layout';

export default function Analytics() {
  const stats = [
    { label: 'Total Patients', value: '67', change: '+12%', trend: 'up' },
    { label: 'Appointments', value: '45', change: '+8%', trend: 'up' },
    { label: 'Revenue', value: 'R12, 450', change: '+15%', trend: 'up' },
    { label: 'Cancellations', value: '23', change: '-5%', trend: 'down' },
  ];

  const topPatients = [
    { name: 'Maion Masilela', visits: 12, lastVisit: '2026-03-15' },
    { name: 'Danny Wilemse', visits: 9, lastVisit: '2026-05-14' },
    { name: 'Glen Nonyane', visits: 8, lastVisit: '2026-03-22' },
  ];

  return (
    <Layout>
      <div style={styles.container}>
        <h1 style={styles.pageTitle}>Analytics</h1>
        <p style={styles.pageSubtitle}>View your practice statistics</p>

        {/* Stats Grid */}
        <div style={styles.statsGrid}>
          {stats.map((stat, index) => (
            <div
              key={index}
              style={styles.statCard}
              onMouseEnter={(e) => e.currentTarget.style.boxShadow = '0 6px 12px rgba(0,0,0,0.15)'}
              onMouseLeave={(e) => e.currentTarget.style.boxShadow = '0 2px 6px rgba(0,0,0,0.1)'}
            >
              <div style={styles.statHeader}>
                <div style={styles.statIcon}>{stat.trend === 'up' ? '📈' : '📉'}</div>
                <span style={{
                  ...styles.statChange,
                  ...(stat.trend === 'up' ? styles.statChangeUp : styles.statChangeDown)
                }}>
                  {stat.change}
                </span>
              </div>
              <p style={styles.statValue}>{stat.value}</p>
              <p style={styles.statLabel}>{stat.label}</p>
            </div>
          ))}
        </div>

        {/* Patient Table */}
        <div style={styles.tableContainer}>
          <h3 style={styles.tableTitle}>Most Active Patients</h3>
          <p style={styles.tableSubtitle}>Based on visit frequency</p>
          
          <div style={styles.patientList}>
            {topPatients.map((patient, index) => (
              <div
                key={index}
                style={styles.patientRow}
                onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#f9fafb'}
                onMouseLeave={(e) => e.currentTarget.style.backgroundColor = 'white'}
              >
                <div style={styles.patientRank}>
                  <span style={styles.rankNumber}>{index + 1}</span>
                </div>
                <div style={styles.patientInfo}>
                  <p style={styles.patientName}>{patient.name}</p>
                  <p style={styles.patientMeta}>Last visit: {patient.lastVisit}</p>
                </div>
                <div style={styles.patientVisits}>
                  <p style={styles.visitsNumber}>{patient.visits}</p>
                  <p style={styles.visitsLabel}>visits</p>
                </div>
                <button
                  style={styles.viewButton}
                  onMouseEnter={(e) => e.currentTarget.style.color = '#1e40af'}
                  onMouseLeave={(e) => e.currentTarget.style.color = '#2563eb'}
                >
                  View →
                </button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Layout>
  );
}

const styles = {
  container: {
    padding: '24px',
    backgroundColor: '#f9fafb',
    fontFamily: "'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
  },
  pageTitle: {
    fontSize: '28px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  pageSubtitle: {
    color: '#666',
    marginTop: '8px',
    marginBottom: '24px',
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
    gap: '20px',
    marginBottom: '32px',
  },
  statCard: {
    backgroundColor: 'white',
    padding: '20px',
    borderRadius: '10px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    transition: 'box-shadow 0.2s ease-in-out',
  },
  statHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '12px',
  },
  statIcon: {
    fontSize: '24px',
  },
  statChange: {
    fontSize: '12px',
    fontWeight: '500' as const,
  },
  statChangeUp: {
    color: '#10b981',
  },
  statChangeDown: {
    color: '#ef4444',
  },
  statValue: {
    fontSize: '28px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  statLabel: {
    fontSize: '14px',
    color: '#666',
    margin: '4px 0 0',
  },
  tableContainer: {
    backgroundColor: 'white',
    borderRadius: '10px',
    padding: '20px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
  },
  tableTitle: {
    fontSize: '18px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  tableSubtitle: {
    fontSize: '14px',
    color: '#666',
    margin: '4px 0 16px',
  },
  patientList: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '12px',
  },
  patientRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '15px',
    padding: '12px',
    borderBottom: '1px solid #e0e0e0',
    transition: 'background-color 0.2s ease-in-out',
  },
  patientRank: {
    width: '30px',
  },
  rankNumber: {
    fontSize: '18px',
    fontWeight: 'bold' as const,
    color: '#666',
  },
  patientInfo: {
    flex: 1,
  },
  patientName: {
    fontSize: '16px',
    fontWeight: '500' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  patientMeta: {
    fontSize: '12px',
    color: '#666',
    margin: '4px 0 0',
  },
  patientVisits: {
    textAlign: 'right' as const,
  },
  visitsNumber: {
    fontSize: '20px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#2563eb',
  },
  visitsLabel: {
    fontSize: '11px',
    color: '#666',
    margin: 0,
  },
  viewButton: {
    backgroundColor: 'transparent',
    color: '#2563eb',
    border: 'none',
    cursor: 'pointer',
    fontSize: '13px',
    transition: 'color 0.2s ease-in-out',
  },
};
