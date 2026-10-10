export default function ErrorBanner({
  message,
  onClose,
}: {
  message: string;
  onClose?: () => void;
}) {
  if (!message) return null;

  return (
    <div style={styles.banner}>
      <span style={styles.icon}>⚠️</span>
      <span style={styles.text}>{message}</span>
      {onClose && (
        <button onClick={onClose} style={styles.closeBtn} aria-label="Dismiss">
          ×
        </button>
      )}
    </div>
  );
}

const styles = {
  banner: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '12px 16px',
    backgroundColor: '#fee2e2',
    color: '#991b1b',
    borderRadius: '10px',
    border: '1px solid #fecaca',
    fontSize: '14px',
    marginBottom: '20px',
  },
  icon: { fontSize: '18px' },
  text: { flex: 1 },
  closeBtn: {
    background: 'none',
    border: 'none',
    fontSize: '20px',
    cursor: 'pointer',
    color: '#991b1b',
    lineHeight: 1,
  },
};