import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import {
  verifyPasswordResetCode,
  confirmPasswordReset,
  AuthErrorCodes,
} from 'firebase/auth';
import { auth } from '../lib/firebase';

// ------------------------------------------------------------------
// Password rules — MUST MATCH the Firebase Console password policy
// ------------------------------------------------------------------
const PASSWORD_RULES = {
  minLength: 10,
  requireUppercase: true,
  requireLowercase: true,
  requireNumeric: true,
  requireSpecial: true,
};

function evaluatePassword(password: string) {
  return {
    length: password.length >= PASSWORD_RULES.minLength,
    uppercase: /[A-Z]/.test(password),
    lowercase: /[a-z]/.test(password),
    numeric: /[0-9]/.test(password),
    special: /[^A-Za-z0-9]/.test(password),
  };
}

function passwordStrength(password: string): {
  score: number; // 0–4
  label: string;
  color: string;
} {
  const checks = evaluatePassword(password);
  const score = Object.values(checks).filter(Boolean).length;
  if (password.length === 0) return { score: 0, label: '', color: '#E5E7EB' };
  if (score <= 2) return { score, label: 'Weak', color: '#EF4444' };
  if (score === 3) return { score, label: 'Fair', color: '#F59E0B' };
  if (score === 4) return { score, label: 'Good', color: '#10B981' };
  return { score, label: 'Strong', color: '#059669' };
}

// ------------------------------------------------------------------
export default function ResetPasswordPage() {
  const router = useRouter();
  const { oobCode, mode } = router.query;

  const [email, setEmail] = useState<string>('');
  const [verifying, setVerifying] = useState(true);
  const [verifyError, setVerifyError] = useState<string | null>(null);

  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  // Step 1: verify the oobCode when the page loads
  useEffect(() => {
    if (!router.isReady) return;
    if (typeof oobCode !== 'string') {
      setVerifyError('Missing or invalid reset link.');
      setVerifying(false);
      return;
    }

    verifyPasswordResetCode(auth, oobCode)
      .then((emailFromCode) => {
        setEmail(emailFromCode);
        setVerifying(false);
      })
      .catch((err) => {
        const code = (err as any)?.code ?? '';
        let message = 'This reset link is no longer valid.';
        if (code === AuthErrorCodes.EXPIRED_OOB_CODE) {
          message = 'This reset link has expired. Please request a new one.';
        } else if (code === AuthErrorCodes.INVALID_OOB_CODE) {
          message = 'This reset link is invalid. Please request a new one.';
        } else if (code === AuthErrorCodes.USER_DISABLED) {
          message = 'This account has been disabled.';
        }
        setVerifyError(message);
        setVerifying(false);
      });
  }, [router.isReady, oobCode]);

  // Step 2: handle submit
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitError(null);

    // Client-side validation (server also enforces — this is UX only)
    const checks = evaluatePassword(password);
    if (!Object.values(checks).every(Boolean)) {
      setSubmitError('Password does not meet all requirements.');
      return;
    }
    if (password !== confirm) {
      setSubmitError('Passwords do not match.');
      return;
    }
    if (typeof oobCode !== 'string') {
      setSubmitError('Reset code missing.');
      return;
    }

    setSubmitting(true);
    try {
      await confirmPasswordReset(auth, oobCode, password);
      setSuccess(true);
      // Give the user a moment to read the success state, then send to login
      setTimeout(() => router.push('/login'), 2500);
    } catch (err) {
      const code = (err as any)?.code ?? '';
      let message = 'Could not reset password. Please try again.';
      if (code === AuthErrorCodes.WEAK_PASSWORD) {
        message = 'Password is too weak. Please follow the requirements below.';
      } else if (code === AuthErrorCodes.EXPIRED_OOB_CODE) {
        message = 'This reset link has expired. Please request a new one.';
      } else if (code === AuthErrorCodes.INVALID_OOB_CODE) {
        message = 'This reset link is invalid. Please request a new one.';
      }
      setSubmitError(message);
    } finally {
      setSubmitting(false);
    }
  };

  // -------- RENDER --------
  const strength = passwordStrength(password);
  const checks = evaluatePassword(password);
  const allValid = Object.values(checks).every(Boolean);

  return (
    <>
      <Head>
        <title>Set Password — Health-Bridge</title>
      </Head>
      <div style={styles.page}>
        <div style={styles.card}>
          <div style={styles.logoRow}>
            <div style={styles.logoDot} />
            <span style={styles.logoText}>Health-Bridge</span>
          </div>

          {verifying && (
            <div style={styles.stateBox}>
              <div style={styles.spinner} />
              <p style={styles.stateText}>Verifying your reset link…</p>
            </div>
          )}

          {!verifying && verifyError && (
            <div style={styles.stateBox}>
              <div style={styles.errorIcon}>!</div>
              <h2 style={styles.stateTitle}>Link problem</h2>
              <p style={styles.stateText}>{verifyError}</p>
              <button
                style={styles.primaryButton}
                onClick={() => router.push('/login')}
              >
                Back to login
              </button>
            </div>
          )}

          {!verifying && !verifyError && !success && (
            <>
              <h1 style={styles.title}>Set your password</h1>
              <p style={styles.subtitle}>
                For <strong>{email}</strong>
              </p>

              <form onSubmit={handleSubmit} style={styles.form}>
                {/* Password field */}
                <label style={styles.label}>New password</label>
                <div style={styles.inputWrapper}>
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    style={styles.input}
                    placeholder="Enter a strong password"
                    autoComplete="new-password"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((v) => !v)}
                    style={styles.eyeButton}
                    aria-label="Toggle password visibility"
                  >
                    {showPassword ? '🙈' : '👁'}
                  </button>
                </div>

                {/* Strength bar */}
                {password.length > 0 && (
                  <div style={styles.strengthWrap}>
                    <div style={styles.strengthBarBg}>
                      <div
                        style={{
                          ...styles.strengthBarFill,
                          width: `${(strength.score / 5) * 100}%`,
                          backgroundColor: strength.color,
                        }}
                      />
                    </div>
                    <span style={{ ...styles.strengthLabel, color: strength.color }}>
                      {strength.label}
                    </span>
                  </div>
                )}

                {/* Requirement checklist */}
                <ul style={styles.checklist}>
                  <Requirement ok={checks.length}>
                    At least {PASSWORD_RULES.minLength} characters
                  </Requirement>
                  <Requirement ok={checks.uppercase}>
                    One uppercase letter (A–Z)
                  </Requirement>
                  <Requirement ok={checks.lowercase}>
                    One lowercase letter (a–z)
                  </Requirement>
                  <Requirement ok={checks.numeric}>One number (0–9)</Requirement>
                  <Requirement ok={checks.special}>
                    One special character (!@#$…)
                  </Requirement>
                </ul>

                {/* Confirm field */}
                <label style={{ ...styles.label, marginTop: 16 }}>
                  Confirm password
                </label>
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  style={styles.input}
                  placeholder="Repeat password"
                  autoComplete="new-password"
                />
                {confirm.length > 0 && confirm !== password && (
                  <p style={styles.inlineError}>Passwords do not match.</p>
                )}

                {/* Errors */}
                {submitError && (
                  <div style={styles.errorBanner}>{submitError}</div>
                )}

                {/* Submit */}
                <button
                  type="submit"
                  disabled={submitting || !allValid || password !== confirm}
                  style={{
                    ...styles.primaryButton,
                    opacity:
                      submitting || !allValid || password !== confirm ? 0.5 : 1,
                    cursor:
                      submitting || !allValid || password !== confirm
                        ? 'not-allowed'
                        : 'pointer',
                    marginTop: 20,
                  }}
                >
                  {submitting ? 'Saving…' : 'Set password'}
                </button>
              </form>
            </>
          )}

          {!verifying && !verifyError && success && (
            <div style={styles.stateBox}>
              <div style={styles.successIcon}>✓</div>
              <h2 style={styles.stateTitle}>Password set!</h2>
              <p style={styles.stateText}>
                You can now sign in with your new password.
              </p>
              <p style={styles.stateTextSmall}>Redirecting to login…</p>
            </div>
          )}
        </div>
      </div>
    </>
  );
}

// ------------------------------------------------------------------
// Small helper component for each requirement line
// ------------------------------------------------------------------
function Requirement({
  ok,
  children,
}: {
  ok: boolean;
  children: React.ReactNode;
}) {
  return (
    <li
      style={{
        ...styles.checkItem,
        color: ok ? '#10B981' : '#6B7280',
      }}
    >
      <span style={{ marginRight: 8 }}>{ok ? '✓' : '○'}</span>
      {children}
    </li>
  );
}

// ------------------------------------------------------------------
// Inline styles — no CSS imports needed
// ------------------------------------------------------------------
const styles: { [k: string]: React.CSSProperties } = {
  page: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#F5F7FA',
    fontFamily:
      "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    padding: 20,
  },
  card: {
    width: '100%',
    maxWidth: 440,
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 32,
    boxShadow: '0 10px 40px rgba(0,0,0,0.08)',
  },
  logoRow: {
    display: 'flex',
    alignItems: 'center',
    marginBottom: 24,
  },
  logoDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#1E3A8A',
    marginRight: 10,
  },
  logoText: {
    fontSize: 18,
    fontWeight: 700,
    color: '#1E3A8A',
  },
  title: {
    fontSize: 24,
    fontWeight: 700,
    color: '#1A1A2E',
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 14,
    color: '#6B7280',
    marginBottom: 24,
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
  },
  label: {
    fontSize: 13,
    fontWeight: 600,
    color: '#374151',
    marginBottom: 6,
  },
  inputWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
  },
  input: {
    width: '100%',
    padding: '12px 44px 12px 14px',
    fontSize: 15,
    borderRadius: 10,
    border: '1px solid #D1D5DB',
    outline: 'none',
    color: '#1A1A2E',
    backgroundColor: '#FFFFFF',
  },
  eyeButton: {
    position: 'absolute',
    right: 8,
    top: 6,
    background: 'transparent',
    border: 'none',
    cursor: 'pointer',
    fontSize: 18,
    padding: 6,
  },
  strengthWrap: {
    display: 'flex',
    alignItems: 'center',
    marginTop: 10,
    marginBottom: 8,
  },
  strengthBarBg: {
    flex: 1,
    height: 6,
    backgroundColor: '#E5E7EB',
    borderRadius: 3,
    overflow: 'hidden',
  },
  strengthBarFill: {
    height: '100%',
    borderRadius: 3,
    transition: 'width 0.2s, background-color 0.2s',
  },
  strengthLabel: {
    marginLeft: 10,
    fontSize: 12,
    fontWeight: 600,
    minWidth: 50,
    textAlign: 'right',
  },
  checklist: {
    listStyle: 'none',
    padding: 0,
    margin: '12px 0 0 0',
  },
  checkItem: {
    fontSize: 13,
    marginBottom: 4,
    transition: 'color 0.2s',
  },
  inlineError: {
    color: '#EF4444',
    fontSize: 13,
    marginTop: 6,
  },
  errorBanner: {
    marginTop: 16,
    padding: 12,
    borderRadius: 10,
    backgroundColor: 'rgba(239,68,68,0.1)',
    color: '#991B1B',
    fontSize: 13,
    border: '1px solid rgba(239,68,68,0.3)',
  },
  primaryButton: {
    padding: '14px 20px',
    borderRadius: 10,
    backgroundColor: '#1E3A8A',
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: 600,
    border: 'none',
    transition: 'opacity 0.15s',
  },
  stateBox: {
    textAlign: 'center',
    padding: '20px 0',
  },
  stateTitle: {
    fontSize: 20,
    fontWeight: 700,
    color: '#1A1A2E',
    margin: '16px 0 8px',
  },
  stateText: {
    fontSize: 14,
    color: '#6B7280',
    marginBottom: 20,
  },
  stateTextSmall: {
    fontSize: 12,
    color: '#9CA3AF',
  },
  spinner: {
    width: 40,
    height: 40,
    border: '4px solid #E5E7EB',
    borderTopColor: '#1E3A8A',
    borderRadius: '50%',
    margin: '0 auto 16px',
    animation: 'spin 0.8s linear infinite',
  },
  errorIcon: {
    width: 48,
    height: 48,
    lineHeight: '48px',
    borderRadius: 24,
    backgroundColor: 'rgba(239,68,68,0.1)',
    color: '#EF4444',
    fontWeight: 700,
    fontSize: 24,
    margin: '0 auto',
  },
  successIcon: {
    width: 56,
    height: 56,
    lineHeight: '56px',
    borderRadius: 28,
    backgroundColor: 'rgba(16,185,129,0.1)',
    color: '#10B981',
    fontWeight: 700,
    fontSize: 28,
    margin: '0 auto',
  },
};