import { initializeApp, deleteApp } from 'firebase/app';
import {
  getAuth,
  createUserWithEmailAndPassword,
  sendPasswordResetEmail,
  signOut,
} from 'firebase/auth';
import { firebaseConfig, auth as primaryAuth } from './firebase';

/**
 * Creates a Firebase Auth user on a throwaway app instance so the
 * admin's current session is never disturbed.
 *
 * Returns the new user's uid.
 */
export async function createAuthUserWithoutSessionSwitch(
  email: string,
  tempPassword: string
): Promise<string> {
  const appName = `patient-invite-${Date.now()}-${Math.random().toString(36).slice(-6)}`;
  const secondaryApp = initializeApp(firebaseConfig, appName);
  const secondaryAuth = getAuth(secondaryApp);

  try {
    const cred = await createUserWithEmailAndPassword(
      secondaryAuth,
      email,
      tempPassword
    );
    const uid = cred.user.uid;
    await signOut(secondaryAuth);
    return uid;
  } finally {
    await deleteApp(secondaryApp);
  }
}

/**
 * Sends the "set your password" email via Firebase's password reset flow.
 * Runs on the primary app — the admin's session is untouched.
 *
 * NOTE: `continueUrl` must always be a real string (never undefined),
 * because Firebase's `sendPasswordResetEmail` requires `url: string`.
 * We fall back to the production URL during SSR / build time when
 * `window` isn't available.
 */
export async function sendPatientInvite(email: string): Promise<void> {
  const FALLBACK_URL =
    'https://health-bridge-git-main-mondemotale.vercel.app';

  const continueUrl =
    typeof window !== 'undefined'
      ? `${window.location.origin}/login`
      : `${FALLBACK_URL}/login`;

  await sendPasswordResetEmail(primaryAuth, email, {
    url: continueUrl,
    handleCodeInApp: false,
  });
}

/**
 * Full invite flow:
 *   1. Create the Auth user on a throwaway app
 *   2. Send the password-setup email
 *   3. Return { uid, inviteSent, alreadyExisted }
 *
 * If the email already exists, we skip creation and just resend the invite.
 */
export async function invitePatient(
  email: string
): Promise<{ uid: string | null; inviteSent: boolean; alreadyExisted: boolean }> {
  const tempPassword = 'Hb@' + Math.random().toString(36).slice(-10) + 'A1';

  let uid: string | null = null;
  let alreadyExisted = false;

  try {
    uid = await createAuthUserWithoutSessionSwitch(email, tempPassword);
  } catch (err: any) {
    if (err?.code === 'auth/email-already-in-use') {
      alreadyExisted = true;
    } else {
      throw err;
    }
  }

  let inviteSent = false;
  try {
    await sendPatientInvite(email);
    inviteSent = true;
  } catch (err) {
    console.warn('Failed to send invite email:', err);
  }

  return { uid, inviteSent, alreadyExisted };
}