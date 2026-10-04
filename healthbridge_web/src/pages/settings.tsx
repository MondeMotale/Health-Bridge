import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from '../lib/firebase';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import Layout from '../components/Layout';

export default function Settings() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [userId, setUserId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('profile');
  
  // State for Admin Data
  const [formData, setFormData] = useState({
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

  // 1. Protect page & Get current user ID
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (!user) {
        router.push('/login');
        return;
      }
      setUserId(user.uid);
      setLoading(false);
    });
    return () => unsubscribe();
  }, [router]);

  // 2. Load Admin data from Firestore 'users' collection
  useEffect(() => {
    if (!userId || loading) return;

    const fetchProfile = async () => {
      try {
        const docRef = doc(db, 'users', userId);
        const docSnap = await getDoc(docRef);
        
        if (docSnap.exists()) {
          const data = docSnap.data();
          setFormData(prev => ({
            ...prev,
            fullName: data.displayName || '',
            email: data.email || '',
            phone: data.phoneNumber || '',
            role: data.role || 'Administrator',
            clinicName: data.clinicName || 'Health-Bridge Medical Center',
            clinicAddress: data.clinicAddress || '123 Medical Street, Johannesburg, 2000',
            timezone: data.timezone || 'Africa/Johannesburg',
            dateFormat: data.dateFormat || 'DD/MM/YYYY',
            language: data.language || 'English',
            notifications: data.notifications ?? true,
            emailAlerts: data.emailAlerts ?? true,
            smsAlerts: data.smsAlerts ?? false,
            appointmentReminders: data.appointmentReminders ?? true,
            weeklyReport: data.weeklyReport ?? true,
            twoFactorAuth: data.twoFactorAuth ?? false,
          }));
        }
      } catch (error) {
        console.error("Error loading profile:", error);
      }
    };

    fetchProfile();
  }, [userId, loading]);

  // 3. Handle Input Changes
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleCheckboxChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.checked,
    });
  };

  const handlePasswordChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setPasswordData({
      ...passwordData,
      [e.target.name]: e.target.value,
    });
  };

  // 4. Save Data to Firestore
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!userId) return;

    try {
      await setDoc(doc(db, 'users', userId), {
        displayName: formData.fullName,
        email: formData.email,
        phoneNumber: formData.phone,
        role: formData.role,
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
      }, { merge: true }); // merge: true ensures we don't delete the 'role' or 'uid' fields

      alert('Settings saved successfully!');
    } catch (error) {
      console.error("Error saving settings:", error);
      alert('Failed to save settings. Please try again.');
    }
  };

  const handlePasswordSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (passwordData.newPassword !== passwordData.confirmPassword) {
      alert('New passwords do not match!');
      return;
    }
    alert('Password changed successfully! (Note: Firebase Password change requires re-authentication)');
    setPasswordData({ currentPassword: '', newPassword: '', confirmPassword: '' });
  };

  const tabs = [
    { id: 'profile', label: 'Profile', icon: '👤' },
    { id: 'notifications', label: 'Notifications', icon: '🔔' },
    { id: 'preferences', label: 'Preferences', icon: '⚙️' },
    { id: 'security', label: 'Security', icon: '🔒' },
  ];

  if (loading) {
    return <div style={{ display: 'flex', justifyContent: 'center', padding: '50px' }}>Loading settings...</div>;
  }

  return (
    <Layout>
      <div style={styles.container}>
        <div style={styles.header}>
          <div>
            <h1 style={styles.pageTitle}>Settings</h1>
            <p style={styles.pageSubtitle}>Manage your account preferences</p>
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
            {/* Profile Tab */}
            {activeTab === 'profile' && (
              <form onSubmit={handleSubmit}>
                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>Personal Information</h3>
                  <div style={styles.formGrid}>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>Full Name</label>
                      <input
                        type="text"
                        name="fullName"
                        value={formData.fullName}
                        onChange={handleInputChange}
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
                        style={styles.input}
                      />
                    </div>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>Role</label>
                      <select
                        name="role"
                        value={formData.role}
                        onChange={handleInputChange}
                        style={styles.select}
                      >
                        <option>Administrator</option>
                        <option>Doctor</option>
                        <option>Nurse</option>
                        <option>Receptionist</option>
                        <option>CHW Supervisor</option>
                      </select>
                    </div>
                  </div>
                </div>

                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>Clinic Information</h3>
                  <div style={styles.formGroup}>
                    <label style={styles.label}>Clinic Name</label>
                    <input
                      type="text"
                      name="clinicName"
                      value={formData.clinicName}
                      onChange={handleInputChange}
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
                      style={styles.input}
                    />
                  </div>
                </div>

                <div style={styles.formActions}>
                  <button type="submit" style={styles.saveButton}>
                    Save Changes
                  </button>
                </div>
              </form>
            )}

            {/* Notifications Tab */}
            {activeTab === 'notifications' && (
              <form onSubmit={handleSubmit}>
                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>Notification Preferences</h3>
                  
                  <div style={styles.toggleGroup}>
                    <div style={styles.toggleItem}>
                      <div>
                        <p style={styles.toggleLabel}>Push Notifications</p>
                        <p style={styles.toggleDescription}>Receive notifications in browser</p>
                      </div>
                      <label style={styles.switch}>
                        <input
                          type="checkbox"
                          name="notifications"
                          checked={formData.notifications}
                          onChange={handleCheckboxChange}
                          style={styles.switchInput}
                        />
                        <span style={styles.switchSlider}></span>
                      </label>
                    </div>

                    <div style={styles.toggleItem}>
                      <div>
                        <p style={styles.toggleLabel}>Email Alerts</p>
                        <p style={styles.toggleDescription}>Receive email notifications for appointments</p>
                      </div>
                      <label style={styles.switch}>
                        <input
                          type="checkbox"
                          name="emailAlerts"
                          checked={formData.emailAlerts}
                          onChange={handleCheckboxChange}
                          style={styles.switchInput}
                        />
                        <span style={styles.switchSlider}></span>
                      </label>
                    </div>

                    <div style={styles.toggleItem}>
                      <div>
                        <p style={styles.toggleLabel}>SMS Alerts</p>
                        <p style={styles.toggleDescription}>Receive text message reminders</p>
                      </div>
                      <label style={styles.switch}>
                        <input
                          type="checkbox"
                          name="smsAlerts"
                          checked={formData.smsAlerts}
                          onChange={handleCheckboxChange}
                          style={styles.switchInput}
                        />
                        <span style={styles.switchSlider}></span>
                      </label>
                    </div>

                    <div style={styles.toggleItem}>
                      <div>
                        <p style={styles.toggleLabel}>Appointment Reminders</p>
                        <p style={styles.toggleDescription}>Get reminders for upcoming appointments</p>
                      </div>
                      <label style={styles.switch}>
                        <input
                          type="checkbox"
                          name="appointmentReminders"
                          checked={formData.appointmentReminders}
                          onChange={handleCheckboxChange}
                          style={styles.switchInput}
                        />
                        <span style={styles.switchSlider}></span>
                      </label>
                    </div>

                    <div style={styles.toggleItem}>
                      <div>
                        <p style={styles.toggleLabel}>Weekly Report</p>
                        <p style={styles.toggleDescription}>Receive weekly performance summary</p>
                      </div>
                      <label style={styles.switch}>
                        <input
                          type="checkbox"
                          name="weeklyReport"
                          checked={formData.weeklyReport}
                          onChange={handleCheckboxChange}
                          style={styles.switchInput}
                        />
                        <span style={styles.switchSlider}></span>
                      </label>
                    </div>
                  </div>
                </div>

                <div style={styles.formActions}>
                  <button type="submit" style={styles.saveButton}>
                    Save Changes
                  </button>
                </div>
              </form>
            )}

            {/* Preferences Tab */}
            {activeTab === 'preferences' && (
              <form onSubmit={handleSubmit}>
                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>Display Preferences</h3>
                  
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
                  <button type="submit" style={styles.saveButton}>
                    Save Changes
                  </button>
                </div>
              </form>
            )}

            {/* Security Tab */}
            {activeTab === 'security' && (
              <div>
                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>Security Settings</h3>
                  
                  <div style={styles.toggleItem}>
                    <div>
                      <p style={styles.toggleLabel}>Two-Factor Authentication</p>
                      <p style={styles.toggleDescription}>Add an extra layer of security to your account</p>
                    </div>
                    <label style={styles.switch}>
                      <input
                        type="checkbox"
                        name="twoFactorAuth"
                        checked={formData.twoFactorAuth}
                        onChange={handleCheckboxChange}
                        style={styles.switchInput}
                      />
                      <span style={styles.switchSlider}></span>
                    </label>
                  </div>
                </div>

                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>Change Password</h3>
                  <form onSubmit={handlePasswordSubmit}>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>Current Password</label>
                      <input
                        type="password"
                        name="currentPassword"
                        value={passwordData.currentPassword}
                        onChange={handlePasswordChange}
                        placeholder="Enter current password"
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
                        placeholder="Enter new password"
                        style={styles.input}
                      />
                    </div>
                    <div style={styles.formGroup}>
                      <label style={styles.label}>Confirm New Password</label>
                      <input
                        type="password"
                        name="confirmPassword"
                        value={passwordData.confirmPassword}
                        onChange={handlePasswordChange}
                        placeholder="Confirm new password"
                        style={styles.input}
                      />
                    </div>
                    <div style={styles.formActions}>
                      <button type="submit" style={styles.saveButton}>
                        Change Password
                      </button>
                    </div>
                  </form>
                </div>

                <div style={styles.formSection}>
                  <h3 style={styles.sectionTitle}>Session Management</h3>
                  <div style={styles.sessionInfo}>
                    <div style={styles.sessionItem}>
                      <div>
                        <p style={styles.sessionDevice}>Chrome on Windows</p>
                        <p style={styles.sessionLocation}>Johannesburg, South Africa</p>
                        <p style={styles.sessionTime}>Last active: Today, 14:30</p>
                      </div>
                      <button style={styles.revokeButton}>Revoke</button>
                    </div>
                    <div style={styles.sessionItem}>
                      <div>
                        <p style={styles.sessionDevice}>Safari on iPhone</p>
                        <p style={styles.sessionLocation}>Johannesburg, South Africa</p>
                        <p style={styles.sessionTime}>Last active: Yesterday, 19:45</p>
                      </div>
                      <button style={styles.revokeButton}>Revoke</button>
                    </div>
                  </div>
                  <button style={styles.revokeAllButton}>Revoke All Other Sessions</button>
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
  header: {
    marginBottom: '28px',
  },
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
  tabIcon: {
    fontSize: '16px',
  },
  tabContent: {
    padding: '32px',
  },
  formSection: {
    marginBottom: '32px',
  },
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
  formGroup: {
    marginBottom: '20px',
  },
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
  switch: {
    position: 'relative' as const,
    display: 'inline-block',
    width: '50px',
    height: '26px',
  },
  switchInput: {
    opacity: 0,
    width: 0,
    height: 0,
  },
  switchSlider: {
    position: 'absolute' as const,
    cursor: 'pointer',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: '#ccc',
    transition: '0.3s',
    borderRadius: '34px',
  },
  sessionInfo: {
    marginBottom: '20px',
  },
  sessionItem: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '16px',
    backgroundColor: '#f9fafb',
    borderRadius: '10px',
    marginBottom: '12px',
  },
  sessionDevice: {
    fontSize: '14px',
    fontWeight: '600' as const,
    margin: 0,
    color: '#1a1a2e',
  },
  sessionLocation: {
    fontSize: '12px',
    color: '#666',
    margin: '4px 0 0',
  },
  sessionTime: {
    fontSize: '11px',
    color: '#888',
    margin: '2px 0 0',
  },
  revokeButton: {
    backgroundColor: 'transparent',
    color: '#ef4444',
    border: '1px solid #ef4444',
    padding: '6px 12px',
    borderRadius: '6px',
    cursor: 'pointer',
    fontSize: '12px',
    transition: 'all 0.2s',
  },
  revokeAllButton: {
    backgroundColor: 'transparent',
    color: '#ef4444',
    border: '1px solid #ef4444',
    padding: '8px 16px',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '13px',
    transition: 'all 0.2s',
    width: '100%',
  },
};