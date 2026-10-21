import { ReactNode, useSyncExternalStore } from 'react';
import Sidebar from './Sidebar';
import Header from './Header';

interface LayoutProps {
  children: ReactNode;
}

/**
 * Subscribe to browser connectivity without scheduling state updates from an
 * effect. The server snapshot stays online to keep SSR output deterministic.
 */
function useOnline(): boolean {
  return useSyncExternalStore(
    (onStoreChange) => {
      window.addEventListener('online', onStoreChange);
      window.addEventListener('offline', onStoreChange);
      return () => {
        window.removeEventListener('online', onStoreChange);
        window.removeEventListener('offline', onStoreChange);
      };
    },
    () => navigator.onLine,
    () => true
  );
}

export default function Layout({ children }: LayoutProps) {
  const isOnline = useOnline();

  return (
    <div style={styles.container}>
      {/* ---- OFFLINE BANNER ---- */}
      {!isOnline && (
        <div style={styles.offlineBanner}>
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="white"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M1 1l22 22M16.72 11.06A10.94 10.94 0 0 1 19 12.55M5 12.55a10.94 10.94 0 0 1 5.17-2.39M10.71 5.05A16 16 0 0 1 22.58 9M1.42 9a15.91 15.91 0 0 1 4.7-2.88M8.53 16.11a6 6 0 0 1 6.95 0M12 20h.01" />
          </svg>
          <span>
            You are offline. Changes may not be saved until your
            connection returns.
          </span>
        </div>
      )}

      <div style={styles.shell}>
        <Sidebar />
        <div style={styles.mainArea}>
          <Header />
          <main style={styles.content}>{children}</main>
        </div>
      </div>
    </div>
  );
}

const styles = {
  container: {
    display: 'flex',
    flexDirection: 'column' as const,
    height: '100vh',
    backgroundColor: '#f9fafb',
  },
  shell: {
    display: 'flex',
    flex: 1,
    overflow: 'hidden',
  },
  offlineBanner: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '10px',
    padding: '10px 16px',
    backgroundColor: '#f59e0b',
    color: 'white',
    fontSize: '13px',
    fontWeight: '500' as const,
    boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
    zIndex: 100,
  },
  mainArea: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column' as const,
    overflow: 'hidden',
  },
  content: {
    flex: 1,
    overflowY: 'auto' as const,
    padding: '24px',
  },
};