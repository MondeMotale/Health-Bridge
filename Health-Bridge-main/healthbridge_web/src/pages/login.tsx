import { useState } from 'react';
import { useRouter } from 'next/router';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../lib/firebase';
import { getAuthError } from '../lib/errors';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setInfo('');

    const trimmedEmail = email.trim();
    if (!trimmedEmail) return setError('Please enter your email address.');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail))
      return setError('Please enter a valid email address.');
    if (!password) return setError('Please enter your password.');

    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, trimmedEmail, password);
      router.push('/dashboard');
    } catch (err: unknown) {
      // Narrow the error — Firebase errors are objects with `code` and `message`.
      const firebaseErr = err as { code?: string; message?: string };
      console.error('Login error:', firebaseErr?.code, firebaseErr?.message);
      setError(getAuthError(firebaseErr));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.page}>
      {/* Brand strip top-left */}
      <div style={styles.brandStrip}>
        <div style={styles.brandMark}>
          <svg
            width="22"
            height="22"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#ffffff"
            strokeWidth="2.4"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M12 3v18M3 12h18" />
          </svg>
        </div>
        <div>
          <p style={styles.brandName}>HealthBridge</p>
          <p style={styles.brandTag}>Clinical Operations Platform</p>
        </div>
      </div>

      <div style={styles.card}>
        {/* Logo mark */}
        <div style={styles.logoWrap}>
          <div style={styles.logoMark}>
            <svg
              width="34"
              height="34"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#ffffff"
              strokeWidth="2.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M12 4v6M9 7h6" />
              <path d="M4 14h4l2-3 3 6 2-3h5" />
            </svg>
          </div>
        </div>

        {/* Title */}
        <div style={styles.titleBlock}>
          <h1 style={styles.title}>Sign in to HealthBridge</h1>
          <p style={styles.subtitle}>
            Secure access for authorised clinical staff
          </p>
        </div>

        {/* Banners */}
        {error && (
          <div style={styles.errorBanner}>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#b91c1c"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            <span>{error}</span>
          </div>
        )}
        {info && (
          <div style={styles.infoBanner}>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#1E3A8A"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="16" x2="12" y2="12" />
              <line x1="12" y1="8" x2="12.01" y2="8" />
            </svg>
            <span>{info}</span>
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleLogin} style={styles.form}>
          <div style={styles.field}>
            <label style={styles.label}>Work email</label>
            <div style={styles.inputWrap}>
              <span style={styles.inputIcon}>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="#64748b"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <rect x="2" y="4" width="20" height="16" rx="2" />
                  <path d="M22 6L12 13 2 6" />
                </svg>
              </span>
              <input
                type="email"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                  if (error) setError('');
                }}
                style={styles.input}
                placeholder="name@clinic.org"
                autoComplete="email"
                required
                disabled={loading}
              />
            </div>
          </div>

          <div style={styles.field}>
            <div style={styles.labelRow}>
              <label style={styles.label}>Password</label>
              <button
                type="button"
                onClick={() => {
                  setInfo(
                    'Contact your system administrator to reset your password.'
                  );
                  setError('');
                }}
                style={styles.forgotLink}
              >
                Forgot password?
              </button>
            </div>
            <div style={styles.inputWrap}>
              <span style={styles.inputIcon}>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="#64748b"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <rect x="3" y="11" width="18" height="10" rx="2" />
                  <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                </svg>
              </span>
              <input
                type="password"
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value);
                  if (error) setError('');
                }}
                style={styles.input}
                placeholder="Enter your password"
                autoComplete="current-password"
                required
                disabled={loading}
              />
            </div>
          </div>

          <button
            type="submit"
            style={{
              ...styles.button,
              opacity: loading ? 0.85 : 1,
              cursor: loading ? 'wait' : 'pointer',
            }}
            disabled={loading}
          >
            {loading ? (
              <>
                <span style={styles.spinner} />
                Signing in…
              </>
            ) : (
              <>
                Sign in
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="#ffffff"
                  strokeWidth="2.4"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <line x1="5" y1="12" x2="19" y2="12" />
                  <polyline points="12 5 19 12 12 19" />
                </svg>
              </>
            )}
          </button>
        </form>

        {/* Trust row */}
        <div style={styles.trustRow}>
          <div style={styles.trustItem}>
            <svg
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#1E3A8A"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            </svg>
            <span>End-to-end encrypted</span>
          </div>
          <div style={styles.trustItem}>
            <svg
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#1E3A8A"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <rect x="3" y="11" width="18" height="10" rx="2" />
              <path d="M7 11V7a5 5 0 0 1 10 0v4" />
            </svg>
            <span>POPIA compliant</span>
          </div>
        </div>
      </div>

      {/* Footer */}
      <div style={styles.footer}>
        <span style={styles.footerDot} />
        <span>System operational · v1.0</span>
      </div>

      {/* Vignette overlay for readability */}
      <div style={styles.vignette} aria-hidden="true" />
    </div>
  );
}

const styles = {
  page: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#081831',
    backgroundImage: 'url(/login-bg.jpg)',
    backgroundSize: 'cover',
    backgroundPosition: 'center',
    backgroundRepeat: 'no-repeat',
    padding: '24px',
    position: 'relative' as const,
    overflow: 'hidden' as const,
    fontFamily: "'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
  },
  brandStrip: {
    position: 'absolute' as const,
    top: '24px',
    left: '28px',
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    zIndex: 3,
  },
  brandMark: {
    width: '34px',
    height: '34px',
    borderRadius: '9px',
    background: 'linear-gradient(135deg, #1E3A8A 0%, #2563EB 100%)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    boxShadow: '0 4px 14px rgba(59,130,246,0.55)',
  },
  brandName: {
    fontSize: '14px',
    fontWeight: '700' as const,
    color: '#ffffff',
    margin: 0,
    letterSpacing: '-0.2px',
  },
  brandTag: {
    fontSize: '11px',
    color: '#7dd3fc',
    margin: '1px 0 0',
    letterSpacing: '0.2px',
  },
  card: {
    position: 'relative' as const,
    zIndex: 3,
    width: '100%',
    maxWidth: '420px',
    backgroundColor: '#ffffff',
    borderRadius: '18px',
    padding: '36px 32px 28px',
    boxShadow:
      '0 24px 60px rgba(0,0,0,0.45), 0 2px 6px rgba(0,0,0,0.15), 0 0 0 1px rgba(255,255,255,0.06)',
  },
  logoWrap: {
    display: 'flex',
    justifyContent: 'center',
    marginBottom: '20px',
  },
  logoMark: {
    width: '60px',
    height: '60px',
    borderRadius: '16px',
    background: 'linear-gradient(135deg, #1E3A8A 0%, #2563EB 100%)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    boxShadow:
      '0 10px 24px rgba(30,58,138,0.45), inset 0 0 0 1px rgba(255,255,255,0.15)',
  },
  titleBlock: {
    textAlign: 'center' as const,
    marginBottom: '24px',
  },
  title: {
    fontSize: '20px',
    fontWeight: '700' as const,
    color: '#0f172a',
    margin: 0,
    letterSpacing: '-0.3px',
  },
  subtitle: {
    fontSize: '13px',
    color: '#64748b',
    margin: '6px 0 0',
  },
  errorBanner: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    backgroundColor: '#fef2f2',
    color: '#b91c1c',
    padding: '10px 12px',
    borderRadius: '9px',
    fontSize: '13px',
    border: '1px solid #fecaca',
    marginBottom: '16px',
    lineHeight: 1.4,
  },
  infoBanner: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    backgroundColor: '#eff6ff',
    color: '#1E3A8A',
    padding: '10px 12px',
    borderRadius: '9px',
    fontSize: '13px',
    border: '1px solid #bfdbfe',
    marginBottom: '16px',
    lineHeight: 1.4,
  },
  form: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '16px',
  },
  field: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '6px',
  },
  labelRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  label: {
    fontSize: '12px',
    fontWeight: '600' as const,
    color: '#334155',
    letterSpacing: '0.1px',
  },
  forgotLink: {
    background: 'none',
    border: 'none',
    color: '#1E3A8A',
    fontSize: '12px',
    fontWeight: '600' as const,
    cursor: 'pointer',
    padding: 0,
    textDecoration: 'none',
  },
  inputWrap: {
    position: 'relative' as const,
    display: 'flex',
    alignItems: 'center',
  },
  inputIcon: {
    position: 'absolute' as const,
    left: '12px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    pointerEvents: 'none' as const,
  },
  input: {
    width: '100%',
    padding: '12px 14px 12px 38px',
    border: '1px solid #e2e8f0',
    borderRadius: '10px',
    fontSize: '14px',
    fontFamily: 'inherit',
    outline: 'none',
    color: '#0f172a',
    backgroundColor: '#f8fafc',
    transition:
      'border-color 0.15s ease, box-shadow 0.15s ease, background-color 0.15s ease',
  },
  button: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '10px',
    marginTop: '6px',
    padding: '13px 20px',
    background: 'linear-gradient(135deg, #1E3A8A 0%, #2563EB 100%)',
    color: '#ffffff',
    border: 'none',
    borderRadius: '10px',
    fontSize: '14px',
    fontWeight: '600' as const,
    letterSpacing: '0.1px',
    boxShadow: '0 6px 14px rgba(30,58,138,0.28)',
    transition: 'transform 0.1s ease, box-shadow 0.15s ease',
  },
  spinner: {
    width: '14px',
    height: '14px',
    border: '2px solid rgba(255,255,255,0.4)',
    borderTopColor: '#ffffff',
    borderRadius: '50%',
    display: 'inline-block',
    animation: 'spin 0.8s linear infinite',
  },
  trustRow: {
    display: 'flex',
    justifyContent: 'center',
    gap: '18px',
    marginTop: '22px',
    paddingTop: '18px',
    borderTop: '1px solid #f1f5f9',
    flexWrap: 'wrap' as const,
  },
  trustItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    fontSize: '11px',
    color: '#475569',
    fontWeight: '500' as const,
  },
  footer: {
    position: 'absolute' as const,
    bottom: '20px',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    fontSize: '11px',
    color: '#7dd3fc',
    zIndex: 3,
  },
  footerDot: {
    width: '7px',
    height: '7px',
    borderRadius: '50%',
    backgroundColor: '#10b981',
    boxShadow: '0 0 0 3px rgba(16,185,129,0.28)',
    display: 'inline-block',
  },
  vignette: {
    position: 'absolute' as const,
    inset: 0,
    background:
      'radial-gradient(ellipse at 50% 50%, rgba(8,24,49,0.05) 0%, rgba(8,24,49,0.35) 60%, rgba(8,24,49,0.75) 100%)',
    pointerEvents: 'none' as const,
    zIndex: 1,
  },
};