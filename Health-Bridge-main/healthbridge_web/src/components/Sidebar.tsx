import { useRouter } from 'next/router';

export default function Sidebar() {
  const router = useRouter();
  
  const menuItems = [
    { name: 'Dashboard', path: '/dashboard', icon: '📊' },
    { name: 'Referrals', path: '/referrals', icon: '📋' },
    { name: 'Patients', path: '/patients', icon: '👥' },
    { name: 'Home-Based Care', path: '/hbc', icon: '🏠' },
    { name: 'Reports', path: '/reports', icon: '📄' },
    { name: 'Analytics', path: '/analytics', icon: '📈' },
    { name: 'Settings', path: '/settings', icon: '⚙️' },
  ];

  return (
    <div style={styles.sidebar}>
      <div style={styles.logoSection}>
        <div style={styles.logo}>
          <span style={styles.logoText}>HB</span>
        </div>
        <h2 style={styles.brand}>HealthBridge</h2>
      </div>
      
      <nav style={styles.nav}>
        {menuItems.map((item) => {
          const isActive = router.pathname === item.path;
          return (
            <button
              key={item.name}
              onClick={() => router.push(item.path)}
              style={{
                ...styles.navItem,
                ...(isActive ? styles.navItemActive : {}),
              }}
            >
              <span style={styles.navIcon}>{item.icon}</span>
              <span style={styles.navText}>{item.name}</span>
              
            </button>
          );
        })}
      </nav>

      <div style={styles.footer}>
        <p style={styles.version}>HealthBridge v1.0</p>
        <p style={styles.status}>
          <span style={styles.statusDot}></span>
          Online
        </p>
      </div>
    </div>
  );
}

const styles = {
  sidebar: {
    width: '260px',
    backgroundColor: '#1a1a2e',
    color: 'white',
    display: 'flex',
    flexDirection: 'column' as const,
  },
  logoSection: {
    padding: '24px',
    textAlign: 'center' as const,
    borderBottom: '1px solid rgba(255,255,255,0.1)',
  },
  logo: {
    width: '50px',
    height: '50px',
    backgroundColor: '#2563eb',
    borderRadius: '12px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    margin: '0 auto 12px',
  },
  logoText: {
    fontSize: '20px',
    fontWeight: 'bold' as const,
  },
  brand: {
    fontSize: '18px',
    margin: 0,
  },
  nav: {
    flex: 1,
    padding: '16px',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '4px',
  },
  navItem: {
    width: '100%',
    padding: '12px 16px',
    backgroundColor: 'transparent',
    border: 'none',
    borderRadius: '10px',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    transition: 'all 0.2s',
    position: 'relative' as const,
  },
  navItemActive: {
    backgroundColor: '#2563eb',
  },
  navIcon: {
    fontSize: '20px',
  },
  navText: {
    color: 'white',
    fontSize: '14px',
    fontWeight: '500' as const,
  },
  badge: {
    position: 'absolute' as const,
    right: '16px',
    backgroundColor: '#ef4444',
    color: 'white',
    fontSize: '10px',
    padding: '2px 6px',
    borderRadius: '10px',
  },
  footer: {
    padding: '20px',
    borderTop: '1px solid rgba(255,255,255,0.1)',
    textAlign: 'center' as const,
  },
  version: {
    fontSize: '11px',
    color: '#888',
    margin: '0 0 8px 0',
  },
  status: {
    fontSize: '11px',
    color: '#10b981',
    margin: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '6px',
  },
  statusDot: {
    width: '8px',
    height: '8px',
    backgroundColor: '#10b981',
    borderRadius: '50%',
    display: 'inline-block',
  },
};