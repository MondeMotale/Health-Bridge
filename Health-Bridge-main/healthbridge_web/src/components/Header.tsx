import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged, signOut, User } from 'firebase/auth';
import { doc, onSnapshot } from 'firebase/firestore';
import { auth, db } from '../lib/firebase';

export default function Header() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<{ displayName: string; role: string }>({
    displayName: '',
    role: '',
  });
  const [loading, setLoading] = useState(true);

  // 1. Listen to Firebase Auth
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (u) => {
      setUser(u);
      if (!u) {
        setProfile({ displayName: '', role: '' });
        setLoading(false);
      }
    });
    return () => unsubscribe();
  }, []);

  // 2. Live-fetch the user's Firestore profile (users/{uid})
  useEffect(() => {
    if (!user) return;

    const unsubscribe = onSnapshot(
      doc(db, 'users', user.uid),
      (snap) => {
        if (snap.exists()) {
          const data = snap.data();
          const role = Array.isArray(data.role) ? data.role[0] : data.role || 'Administrator';
          setProfile({
            displayName:
              data.displayName ||
              user.displayName ||
              user.email?.split('@')[0] ||
              'User',
            role,
          });
        } else {
          // No Firestore doc yet — fall back to Auth data
          setProfile({
            displayName: user.displayName || user.email?.split('@')[0] || 'User',
            role: 'Administrator',
          });
        }
        setLoading(false);
      },
      (err) => {
        console.error('Header profile error:', err);
        setProfile({
          displayName: user.displayName || user.email?.split('@')[0] || 'User',
          role: 'Administrator',
        });
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [user]);

  // 3. Real logout
  const handleLogout = async () => {
    try {
      await signOut(auth);
      router.push('/login');
    } catch (err) {
      console.error('Logout failed:', err);
    }
  };

  // 4. Compute initials from display name
  const getInitials = (name: string) => {
    if (!name) return '?';
    const parts = name.trim().split(/\s+/);
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  };

  // 5. Friendly role label
  const roleLabel = (() => {
    if (!profile.role) return 'Administrator';
    const r = profile.role.toLowerCase();
    if (r === 'admin' || r === 'administrator') return 'Administrator';
    if (r === 'doctor') return 'Doctor';
    if (r === 'nurse') return 'Nurse';
    if (r === 'receptionist') return 'Receptionist';
    if (r === 'chw supervisor') return 'CHW Supervisor';
    if (r === 'chw') return 'CHW';
    return profile.role.charAt(0).toUpperCase() + profile.role.slice(1);
  })();

  const displayName = profile.displayName || (loading ? 'Loading...' : 'Admin');
  const initials = getInitials(profile.displayName);
  const firstName = displayName.split(' ')[0];

  return (
    <header style={styles.header}>
      {/* Left — page context */}
      <div>
        <h2 style={styles.title}>Dashboard</h2>
        <p style={styles.subtitle}>
          Welcome back, {firstName === 'Loading...' ? 'Admin' : firstName}
        </p>
      </div>

      {/* Right — user info + logout */}
      <div style={styles.rightSection}>
        <div style={styles.userInfo}>
          <div style={styles.userText}>
            <p style={styles.userName}>{displayName.toUpperCase()}</p>
            <p style={styles.userRole}>{roleLabel}</p>
          </div>
          <div style={styles.avatar}>
            <span style={styles.avatarText}>{initials}</span>
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