export function getFirestoreError(err: any): string {
  const code = err?.code || '';
  switch (code) {
    case 'permission-denied':
      return 'You don\u2019t have permission to access this data. Please contact your administrator.';
    case 'unavailable':
      return 'Cannot reach the server. Check your internet connection and try again.';
    case 'deadline-exceeded':
      return 'The request took too long. Please try again.';
    case 'not-found':
      return 'The requested record was not found.';
    case 'already-exists':
      return 'This record already exists.';
    case 'failed-precondition':
      return 'A required index is missing in Firestore. Contact your administrator.';
    case 'unauthenticated':
      return 'Your session has expired. Please sign in again.';
    case 'resource-exhausted':
      return 'Too many requests right now. Please wait a moment.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

export function getAuthError(err: any): string {
  const code = err?.code || '';
  switch (code) {
    case 'auth/invalid-email':
      return 'That doesn\u2019t look like a valid email address.';
    case 'auth/missing-password':
      return 'Please enter your password.';
    case 'auth/wrong-password':
    case 'auth/invalid-credential':
      return 'Incorrect email or password. Please try again.';
    case 'auth/user-not-found':
      return 'No account exists with that email.';
    case 'auth/user-disabled':
      return 'This account has been disabled. Contact your administrator.';
    case 'auth/email-already-in-use':
      return 'That email is already registered.';
    case 'auth/weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'auth/too-many-requests':
      return 'Too many failed attempts. Please wait a few minutes.';
    case 'auth/network-request-failed':
      return 'Network error. Check your internet connection.';
    case 'auth/operation-not-allowed':
      return 'Email/Password sign-in is not enabled. Contact your administrator.';
    default:
      return 'Authentication failed. Please try again.';
  }
}