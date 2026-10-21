import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import { doc, setDoc, onSnapshot } from 'firebase/firestore';
import Layout from '../components/Layout';
import { DB_PATHS } from '../lib/dbPaths';

// ---------- Row types ----------
interface ProfileData {
  displayName?: string;
  email?: string;
  phoneNumber?: string;
  role?: string;
  clinicName?: string;
  clinicAddress?: string;
  timezone?: string;
  dateFormat?: string;
  language?: string;
  notifications?: boolean;
  emailAlerts?: boolean;
  smsAlerts?: boolean;
  appointmentReminders?: boolean;
  weeklyReport?: boolean;
  twoFactorAuth?: boolean;
}

interface FormData {
  fullName: string;
  email: string;
  phone: string;
  role: string;
  clinicName: string;
  clinicAddress: string;
  timezone: string;
  dateFormat: string;
  language: string;
  notifications: boolean;
  emailAlerts: boolean;
  smsAlerts: boolean;
  appointmentReminders: boolean;
  weeklyReport: boolean;
  twoFactorAuth: boolean;
}

export default function Settings() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [userId, setUserId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('profile');
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');
  const [saving, setSaving] = useState(false);

  const [formData, setFormData] = useState<FormData>({
    fullName: '',
    email: '',
    phone: '',
    role: 'Administrator',
    clinicName: 'Health-Bridge Medical Center',
    clinicAddress: '123 Medical Street, Johannesburg, 2000',
    timezone: 'Africa/Johannesburg',
    dateFormat: 'DD/MM/YYYY',
    language: 'English',
    notifications: true,
    emailAlerts: true,
    smsAlerts: false,
    appointmentReminders: true,
    weeklyReport: true,
    twoFactorAuth: false,
  });

  const [passwordData, setPasswordData] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });

  // 1. Auth guard + grab uid
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (!user) {
        router.push('/login');
        return;
      }
      setUserId(user.uid);
      setFormData((prev) => ({
        ...prev,
        email: prev.email || user.email || '',
      }));
      setLoading(false);
    });
    return () => unsubscribe();
  }, [router]);

  // 2. Live-load profile from Firestore
  useEffect(() => {
    if (!userId || loading) return;

    const unsub = onSnapshot(
      doc(db, DB_PATHS.users, userId),
      (snap) => {
        if (!snap.exists()) return;
        const data = snap.data() as ProfileData;

        setFormData((prev) => ({
          ...prev,
          fullName: data.displayName || prev.fullName,
          email: data.email || prev.email,
          phone: data.phoneNumber || prev.phone,
          role: data.role || prev.role,
          clinicName: data.clinicName || prev.clinicName,
          clinicAddress: data.clinicAddress || prev.clinicAddress,
          timezone: data.timezone || prev.timezone,
          dateFormat: data.dateFormat || prev.dateFormat,
          language: data.language || prev.language,
          notifications: data.notifications ?? prev.notifications,
          emailAlerts: data.emailAlerts ?? prev.emailAlerts,
          smsAlerts: data.smsAlerts ?? prev.smsAlerts,
          appointmentReminders:
            data.appointmentReminders ?? prev.appointmentReminders,
          weeklyReport: data.weeklyReport ?? prev.weeklyReport,
          twoFactorAuth: data.twoFactorAuth ?? prev.twoFactorAuth,
        }));
      },
      (err) => setError('Failed to load profile: ' + err.message)
    );

    return () => unsub();
  }, [userId, loading]);

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>
  ) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleToggleChange = async (
    e: React.ChangeEvent<HTMLInputElement>
  ) => {
    const { name, checked } = e.target;
    setFormData((prev) => ({ ...prev, [name]: checked }));

    if (!userId) return;
    try {
      await setDoc(
        doc(db, DB_PATHS.users, userId),
        { [name]: checked },
        { merge: true }
      );
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError('Failed to save preference: ' + message);
    }
  };

  const handlePasswordChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setPasswordData({ ...passwordData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!userId) return;

    setSaving(true);
    setError('');
    setInfo('');

    try {
      await setDoc(
        doc(db, DB_PATHS.users, userId),
        {
          displayName: formData.fullName,
          email: formData.email,
          phoneNumber: formData.phone,
          // role is intentionally NOT saved — it is read-only
          clinicName: formData.clinicName,
          clinicAddress: formData.clinicAddress,
          timezone: formData.timezone,
          dateFormat: formData.dateFormat,
          language: formData.language,
          notifications: formData.notifications,
          emailAlerts: formData.emailAlerts,
          smsAlerts: formData.smsAlerts,
          appointmentReminders: formData.appointmentReminders,
          weeklyReport: formData.weeklyReport,
          twoFactorAuth: formData.twoFactorAuth,
          updatedAt: new Date().toISOString(),
        },
        { merge: true }
      );
      setInfo('Settings saved successfully.');
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError('Failed to save settings: ' + message);
    } finally {
      setSaving(false);
    }
  };

  const handlePasswordSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (passwordData.newPassword !== passwordData.confirmPassword) {
      setError('New passwords do not match.');
      return;
    }
    setInfo('Password change requires re-authentication — coming soon.');
    setPasswordData({
      currentPassword: '',
      newPassword: '',
      confirmPassword: '',
    });
  };

  const tabs = [
    { id: 'profile', label: 'Profile', icon: '👤' },
    { id: 'notifications', label: 'Notifications', icon: '🔔' },
    { id: 'preferences', label: 'Preferences', icon: '⚙️' },
    { id: 'security', label: 'Security', icon: '🔒' },
  ];

  if (loading) {
    return (
      <div
        style={{
          display: 'flex',
          justifyContent: 'center',
          padding: '50px',
        }}
      >
        Loading settings...
      </div>
    );
  }

  return (
    <Layout>
      <div style={styles.container}>
        {error && (
          <div style={styles.errorBanner}>
            <span>⚠️ {error}</span>
            <button
              onClick={() => setError('')}
              style={styles.bannerClose}
            >
              ×
            </button>
          </div>
        )}
        {info && (
          <div style={styles.infoBanner}>
            <span>✓ {info}</span>
            <button
              onClick={() => setInfo('')}
              style={styles.bannerClose}
            >
              ×
            </button>
          </div>
        )}

        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Settings</h1>
            <p style={styles.pageSubtitle}>
              Manage your account preferences
            </p>
          </div>
        </div>

        <div style={styles.card}>
          <div style={styles.tabsContainer}>
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                style={{
                  ...styles.tab,
                  ...(activeTab === tab.id ? styles.tabActive : {}),
                }}
              >
                <span style={styles.tabIcon}>{tab.icon}</span>
                {tab.label}
              </button>
            ))}
          </div>

          <div style={styles.tabContent}>
            {activeTab === 'profile' && (
              <form onSubmit={handleSubmit}>
                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>
                    Personal Information
                  </h3>
                  <div style={styles.formGrid}>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>Full Name</label>
                      <input
                        type="text"
                        name="fullName"
                        value={formData.fullName}
                        onChange={handleInputChange}
                        maxLength={100}
                        style={styles.input}
                        required
                      />
                    </div>

                    <div style={styles.formGroup}>
                      <label style={styles.label}>Email Address</label>
                      <input
                        type="email"
                        name="email"
                        value={formData.email}
                        onChange={handleInputChange}
                        maxLength={254}
                        style={styles.input}
                        required
                      />
                    </div>

                    <div style={styles.formGroup}>
                      <label style={styles.label}>Phone Number</label>
                      <input
                        type="tel"
                        name="phone"
                        value={formData.phone}
                        onChange={handleInputChange}
                        maxLength={15}
                        style={styles.input}
                      />
                    </div>

                    {/* Role — read-only */}
                    <div style={styles.formGroup}>
                      <label style={styles.label}>Role</label>
                      <div style={styles.readonlyField}>
                        <span style={styles.readonlyIcon}>🔒</span>
                        <span style={styles.readonlyText}>
                          {formData.role || 'Administrator'}
                        </span>
                      </div>
                      <p style={styles.helperText}>
                        Role is assigned by the system administrator and
                        cannot be changed here.
                      </p>
                    </div>
                  </div>
                </div>

                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>
                    Clinic Information
                  </h3>
                  <div style={styles.formGroup}>
                    <label style={styles.label}>Clinic Name</label>
                    <input
                      type="text"
                      name="clinicName"
                      value={formData.clinicName}
                      onChange={handleInputChange}
                      maxLength={150}
                      style={styles.input}
                    />
                  </div>
                  <div style={styles.formGroup}>
                    <label style={styles.label}>Clinic Address</label>
                    <input
                      type="text"
                      name="clinicAddress"
                      value={formData.clinicAddress}
                      onChange={handleInputChange}
                      maxLength={250}
                      style={styles.input}
                    />
                  </div>
                </div>

                <div style={styles.formActions}>
                  <button
                    type="submit"
                    style={styles.saveButton}
                    disabled={saving}
                  >
                    {saving ? 'Saving…' : 'Save Changes'}
                  </button>
                </div>
              </form>
            )}

            {activeTab === 'notifications' && (
              <div>
                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>
                    Notification Preferences
                  </h3>
                  <div style={styles.toggleGroup}>
                    {[
                      {
                        name: 'notifications',
                        label: 'Push Notifications',
                        desc: 'Receive notifications in browser',
                      },
                      {
                        name: 'emailAlerts',
                        label: 'Email Alerts',
                        desc: 'Receive email notifications for appointments',
                      },
                      {
                        name: 'smsAlerts',
                        label: 'SMS Alerts',
                        desc: 'Receive text message reminders',
                      },
                      {
                        name: 'appointmentReminders',
                        label: 'Appointment Reminders',
                        desc: 'Get reminders for upcoming appointments',
                      },
                      {
                        name: 'weeklyReport',
                        label: 'Weekly Report',
                        desc: 'Receive weekly performance summary',
                      },
                    ].map((t) => (
                      <div key={t.name} style={styles.toggleItem}>
                        <div>
                          <p style={styles.toggleLabel}>{t.label}</p>
                          <p style={styles.toggleDescription}>
                            {t.desc}
                          </p>
                        </div>
                        <label className="hb-switch">
                          <input
                            type="checkbox"
                            name={t.name}
                            checked={
                              formData[t.name as keyof FormData] as boolean
                            }
                            onChange={handleToggleChange}
                          />
                          <span className="hb-slider"></span>
                        </label>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'preferences' && (
              <form onSubmit={handleSubmit}>
                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>
                    Display Preferences
                  </h3>
                  <div style={styles.formGrid}>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>Timezone</label>
                      <select
                        name="timezone"
                        value={formData.timezone}
                        onChange={handleInputChange}
                        style={styles.select}
                      >
                        <option>Africa/Johannesburg</option>
                        <option>Africa/Cairo</option>
                        <option>Africa/Lagos</option>
                        <option>Europe/London</option>
                        <option>America/New_York</option>
                      </select>
                    </div>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>Date Format</label>
                      <select
                        name="dateFormat"
                        value={formData.dateFormat}
                        onChange={handleInputChange}
                        style={styles.select}
                      >
                        <option>DD/MM/YYYY</option>
                        <option>MM/DD/YYYY</option>
                        <option>YYYY-MM-DD</option>
                      </select>
                    </div>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>Language</label>
                      <select
                        name="language"
                        value={formData.language}
                        onChange={handleInputChange}
                        style={styles.select}
                      >
                        <option>English</option>
                        <option>Afrikaans</option>
                        <option>isiZulu</option>
                        <option>isiXhosa</option>
                        <option>Sesotho</option>
                      </select>
                    </div>
                  </div>
                </div>
                <div style={styles.formActions}>
                  <button
                    type="submit"
                    style={styles.saveButton}
                    disabled={saving}
                  >
                    {saving ? 'Saving…' : 'Save Changes'}
                  </button>
                </div>
              </form>
            )}

            {activeTab === 'security' && (
              <div>
                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>
                    Security Settings
                  </h3>
                  <div style={styles.toggleItem}>
                    <div>
                      <p style={styles.toggleLabel}>
                        Two-Factor Authentication
                      </p>
                      <p style={styles.toggleDescription}>
                        Add an extra layer of security to your account
                      </p>
                    </div>
                    <label className="hb-switch">
                      <input
                        type="checkbox"
                        name="twoFactorAuth"
                        checked={formData.twoFactorAuth}
                        onChange={handleToggleChange}
                      />
                      <span className="hb-slider"></span>
                    </label>
                  </div>
                </div>

                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>Change Password</h3>
                  <form onSubmit={handlePasswordSubmit}>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>
                        Current Password
                      </label>
                      <input
                        type="password"
                        name="currentPassword"
                        value={passwordData.currentPassword}
                        onChange={handlePasswordChange}
                        maxLength={128}
                        style={styles.input}
                      />
                    </div>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>New Password</label>
                      <input
                        type="password"
                        name="newPassword"
                        value={passwordData.newPassword}
                        onChange={handlePasswordChange}
                        maxLength={128}
                        style={styles.input}
                      />
                    </div>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>
                        Confirm New Password
                      </label>
                      <input
                        type="password"
                        name="confirmPassword"
                        value={passwordData.confirmPassword}
                        onChange={handlePasswordChange}
                        maxLength={128}
                        style={styles.input}
                      />
                    </div>
                    <div style={styles.formActions}>
                      <button
                        type="submit"
                        style={styles.saveButton}
                      >
                        Change Password
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            )}
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
    minHeight: '100vh',
  },
  header: { marginBottom: '28px' },
  pageTitle: {
    fontSize: '26px',
    fontWeight: 'bold' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  pageSubtitle: {
    color: '#666',
    marginTop: '8px',
    marginBottom: 0,
    fontSize: '14px',
  },
  card: {
    backgroundColor: 'white',
    borderRadius: '14px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    overflow: 'hidden',
  },
  tabsContainer: {
    display: 'flex',
    borderBottom: '1px solid #e5e7eb',
    backgroundColor: 'white',
    padding: '0 24px',
    gap: '8px',
  },
  tab: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    padding: '16px 20px',
    backgroundColor: 'transparent',
    border: 'none',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: '500' as const,
    color: '#666',
    transition: 'all 0.2s',
    borderRadius: '8px 8px 0 0',
  },
  tabActive: {
    color: '#2563eb',
    borderBottom: '2px solid #2563eb',
    marginBottom: '-1px',
  },
  tabIcon: { fontSize: '16px' },
  tabContent: { padding: '32px' },
  formSection: { marginBottom: '32px' },
  sectionTitle: {
    fontSize: '18px',
    fontWeight: '600' as const,
    margin: '0 0 20px 0',
    color: '#1a1a2e',
  },
  formGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(2, 1fr)',
    gap: '20px',
  },
  formGroup: { marginBottom: '20px' },
  label: {
    display: 'block',
    fontSize: '14px',
    fontWeight: '500' as const,
    color: '#333',
    marginBottom: '8px',
  },
  input: {
    width: '100%',
    padding: '10px 12px',
    border: '1px solid #e5e7eb',
    borderRadius: '8px',
    fontSize: '14px',
    outline: 'none',
    transition: 'all 0.2s',
    backgroundColor: 'white',
  },
  select: {
    width: '100%',
    padding: '10px 12px',
    border: '1px solid #e5e7eb',
    borderRadius: '8px',
    fontSize: '14px',
    backgroundColor: 'white',
    cursor: 'pointer',
    outline: 'none',
  },
  formActions: {
    display: 'flex',
    justifyContent: 'flex-end',
    paddingTop: '16px',
    borderTop: '1px solid #e5e7eb',
  },
  saveButton: {
    backgroundColor: '#2563eb',
    color: 'white',
    padding: '10px 24px',
    border: 'none',
    borderRadius: '8px',
    fontSize: '14px',
    fontWeight: '500' as const,
    cursor: 'pointer',
    transition: 'backgroundColor 0.2s',
  },
  toggleGroup: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '16px',
  },
  toggleItem: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '16px 0',
    borderBottom: '1px solid #f0f0f0',
  },
  toggleLabel: {
    fontSize: '15px',
    fontWeight: '500' as const,
    margin: 0,
    color: '#333',
  },
  toggleDescription: {
    fontSize: '13px',
    color: '#666',
    margin: '4px 0 0',
  },
  readonlyField: {
    width: '100%',
    padding: '10px 12px',
    border: '1px solid #e5e7eb',
    borderRadius: '8px',
    fontSize: '14px',
    backgroundColor: '#f9fafb',
    color: '#4b5563',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    cursor: 'not-allowed',
  },
  readonlyIcon: {
    fontSize: '13px',
    opacity: 0.6,
  },
  readonlyText: {
    fontWeight: '500' as const,
    color: '#374151',
  },
  helperText: {
    fontSize: '11px',
    color: '#9ca3af',
    margin: '4px 0 0',
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
  infoBanner: {
    backgroundColor: '#d1fae5',
    color: '#065f46',
    padding: '10px 14px',
    borderRadius: '8px',
    marginBottom: '16px',
    fontSize: '13px',
    border: '1px solid #86efac',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  bannerClose: {
    background: 'none',
    border: 'none',
    fontSize: '18px',
    cursor: 'pointer',
    lineHeight: 1,
  },
};