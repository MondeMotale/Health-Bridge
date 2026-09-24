import { useRouter } from 'next/router';

export default function Header() {
  const router = useRouter();

  const handleLogout = () => {
    localStorage.removeItem('isLoggedIn');
    router.push('/');
  };

  return (
    <header style={styles.header}>
      <div>
        <h2 style={styles.title}>Dashboard</h2>
        <p style={styles.subtitle}>Welcome back, Admin</p>
      </div>
      
      <div style={styles.rightSection}>
        <div style={styles.userInfo}>
          <div style={styles.userText}>
            <p style={styles.userName}>ADMIN</p>
            <p style={styles.userRole}>Administrator</p>
          </div>
          <div style={styles.avatar}>
            <span style={styles.avatarText}>MM</span>
          </div>
        </div>
        
        <button onClick={handleLogout} style={styles.logoutButton}>
          Logout
        </button>
      </div>
    </header>
  );
}

const styles = {
  header: {
    backgroundColor: 'white',
    borderBottom: '1px solid #e0e0e0',
    padding: '16px 24px',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: {
    fontSize: '20px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  subtitle: {
    fontSize: '14px',
    color: '#666',
    margin: '4px 0 0',
  },
  rightSection: {
    display: 'flex',
    alignItems: 'center',
    gap: '20px',
  },
  userInfo: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
  },
  userText: {
    textAlign: 'right' as const,
  },
  userName: {
    fontSize: '14px',
    fontWeight: '500' as const,
    margin: 0,
    color: '#333',
  },
  userRole: {
    fontSize: '12px',
    color: '#888',
    margin: '2px 0 0',
  },
  avatar: {
    width: '40px',
    height: '40px',
    backgroundColor: '#2563eb',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: 'white',
    fontWeight: 'bold' as const,
    fontSize: '14px',
  },
  logoutButton: {
    padding: '8px 16px',
    backgroundColor: '#dc2626',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    cursor: 'pointer',
    fontSize: '14px',
  },
};