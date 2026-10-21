import Layout from '../components/Layout';

export default function Appointments() {
  const appointments = [
    { id: 1, patient: 'Sarah Johnson', time: '09:00 AM', type: 'Checkup', doctor: 'Dr. Smith', status: 'Scheduled', room: '204' },
    { id: 2, patient: 'Michael Chen', time: '10:30 AM', type: 'Follow-up', doctor: 'Dr. Smith', status: 'In Progress', room: '205' },
    { id: 3, patient: 'Emma Williams', time: '11:30 AM', type: 'Consultation', doctor: 'Dr. Johnson', status: 'Scheduled', room: '206' },
    { id: 4, patient: 'James Brown', time: '02:00 PM', type: 'Emergency', doctor: 'Dr. Smith', status: 'Scheduled', room: '202' },
    { id: 5, patient: 'Lisa Garcia', time: '03:30 PM', type: 'Checkup', doctor: 'Dr. Johnson', status: 'Completed', room: '203' },
  ];

  return (
    <Layout>
      <div style={styles.container}>
        {/* Header */}
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Appointments</h1>
            <p style={styles.pageSubtitle}>Manage today's schedule</p>
          </div>
          <button
            style={styles.addButton}
            onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#1e40af'}
            onMouseLeave={(e) => e.currentTarget.style.backgroundColor = '#2563eb'}
          >
            + New Appointment
          </button>
        </div>

        {/* Summary Card */}
        <div style={styles.summaryCard}>
          <div>
            <h3 style={styles.summaryTitle}>Today's Schedule</h3>
            <p style={styles.summaryDate}>May 20, 2026</p>
          </div>
          <div style={styles.summaryCount}>
            <p style={styles.summaryNumber}>{appointments.length}</p>
            <p style={styles.summaryLabel}>Total Appointments</p>
          </div>
        </div>

        {/* Appointment List */}
        <div style={styles.list}>
          {appointments.map((apt) => (
            <div
              key={apt.id}
              style={styles.appointmentCard}
              onMouseEnter={(e) => e.currentTarget.style.boxShadow = '0 6px 12px rgba(0,0,0,0.15)'}
              onMouseLeave={(e) => e.currentTarget.style.boxShadow = '0 2px 6px rgba(0,0,0,0.1)'}
            >
              <div style={styles.appointmentHeader}>
                <div style={styles.statusDot(apt.status)}></div>
                <h3 style={styles.appointmentPatient}>{apt.patient}</h3>
                <span style={{
                  ...styles.statusBadge,
                  ...(apt.status === 'In Progress' ? styles.statusProgress :
                     apt.status === 'Completed' ? styles.statusCompleted : styles.statusScheduled)
                }}>
                  {apt.status}
                </span>
              </div>

              <div style={styles.appointmentDetails}>
                <span style={styles.detailBadge}>🕐 {apt.time}</span>
                <span style={styles.detailBadge}>📍 Room {apt.room}</span>
                <span style={styles.detailBadge}>👨‍⚕️ {apt.doctor}</span>
              </div>

              <div style={styles.appointmentFooter}>
                <span style={styles.appointmentType}>Type: {apt.type}</span>
                <button
                  style={styles.viewButton}
                  onMouseEnter={(e) => e.currentTarget.style.color = '#1e40af'}
                  onMouseLeave={(e) => e.currentTarget.style.color = '#2563eb'}
                >
                  View Details →
                </button>
              </div>
            </div>
          ))}
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
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '24px',
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
    marginBottom: 0,
  },
  addButton: {
    backgroundColor: '#2563eb',
    color: 'white',
    padding: '10px 20px',
    border: 'none',
    borderRadius: '6px',
    cursor: 'pointer',
    fontSize: '14px',
    transition: 'background-color 0.2s ease-in-out',
  },
  summaryCard: {
    backgroundColor: 'white',
    borderRadius: '10px',
    padding: '20px',
    marginBottom: '24px',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    transition: 'box-shadow 0.2s ease-in-out',
  },
  summaryTitle: {
    fontSize: '16px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#333',
  },
  summaryDate: {
    fontSize: '14px',
    color: '#666',
    margin: '4px 0 0',
  },
  summaryCount: {
    textAlign: 'right' as const,
  },
  summaryNumber: {
    fontSize: '28px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#2563eb',
  },
  summaryLabel: {
    fontSize: '12px',
    color: '#666',
    margin: 0,
  },
  list: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '16px',
  },
  appointmentCard: {
    backgroundColor: 'white',
    borderRadius: '10px',
    padding: '20px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    transition: 'box-shadow 0.2s ease-in-out',
  },
  appointmentHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    marginBottom: '12px',
  },
  statusDot: (status: string) => ({
    width: '8px',
    height: '8px',
    borderRadius: '50%',
    backgroundColor: status === 'In Progress' ? '#f59e0b' : status === 'Completed' ? '#10b981' : '#2563eb',
  }),
  appointmentPatient: {
    fontSize: '18px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  statusBadge: {
    padding: '2px 10px',
    borderRadius: '20px',
    fontSize: '12px',
  },
  statusScheduled: {
    backgroundColor: '#dbeafe',
    color: '#1e40af',
  },
  statusProgress: {
    backgroundColor: '#fed7aa',
    color: '#92400e',
  },
  statusCompleted: {
    backgroundColor: '#d1fae5',
    color: '#065f46',
  },
  appointmentDetails: {
    display: 'flex',
    gap: '16px',
    marginBottom: '12px',
    flexWrap: 'wrap' as const,
  },
  detailBadge: {
    fontSize: '13px',
    color: '#666',
  },
  appointmentFooter: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: '12px',
    borderTop: '1px solid #e0e0e0',
  },
  appointmentType: {
    fontSize: '13px',
    color: '#666',
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