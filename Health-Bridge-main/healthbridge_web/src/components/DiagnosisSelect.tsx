import { useEffect, useMemo, useRef, useState } from 'react';
import icd10 from '../data/icd10.json';

type Code = { code: string; name: string; category: string };

export default function DiagnosisSelect({
  value,
  onChange,
}: {
  value: string;
  onChange: (label: string, code: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const wrapperRef = useRef<HTMLDivElement>(null);

  const codes = (icd10 as { codes: Code[] }).codes;

  // Filter by code, name, or category
  const filtered = useMemo(() => {
    if (!query.trim()) return codes.slice(0, 60);
    const q = query.toLowerCase();
    return codes
      .filter(
        (c) =>
          c.code.toLowerCase().includes(q) ||
          c.name.toLowerCase().includes(q) ||
          c.category.toLowerCase().includes(q)
      )
      .slice(0, 60);
  }, [query, codes]);

  // Close when clicking outside
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (wrapperRef.current && !wrapperRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  const pick = (c: Code) => {
    onChange(`${c.code} — ${c.name}`, c.code);
    setQuery('');
    setOpen(false);
  };

  const clear = () => {
    onChange('', '');
    setQuery('');
  };

  return (
    <div ref={wrapperRef} style={styles.wrapper}>
      <div style={styles.inputRow}>
        <input
          type="text"
          value={open ? query : value}
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          placeholder="Search diagnosis by name or ICD-10 code..."
          style={styles.input}
        />
        {value && !open && (
          <button type="button" onClick={clear} style={styles.clearBtn} aria-label="Clear">
            ×
          </button>
        )}
      </div>

      {open && (
        <div style={styles.dropdown}>
          {filtered.length === 0 ? (
            <div style={styles.empty}>No matching diagnosis found.</div>
          ) : (
            filtered.map((c) => (
              <button
                type="button"
                key={c.code}
                onClick={() => pick(c)}
                style={styles.option}
              >
                <div style={styles.optionTop}>
                  <span style={styles.codeBadge}>{c.code}</span>
                  <span style={styles.category}>{c.category}</span>
                </div>
                <div style={styles.name}>{c.name}</div>
              </button>
            ))
          )}
          {query === '' && codes.length > 60 && (
            <div style={styles.hint}>
              Showing first 60 of {codes.length}. Type to search.
            </div>
          )}
        </div>
      )}
    </div>
  );
}

const styles = {
  wrapper: {
    position: 'relative' as const,
    width: '100%',
  },
  inputRow: {
    position: 'relative' as const,
    display: 'flex',
    alignItems: 'center',
  },
  input: {
    width: '100%',
    padding: '10px 36px 10px 12px',
    border: '1px solid #e5e7eb',
    borderRadius: '8px',
    fontSize: '14px',
    outline: 'none',
    fontFamily: 'inherit',
    backgroundColor: 'white',
  },
  clearBtn: {
    position: 'absolute' as const,
    right: '8px',
    background: 'none',
    border: 'none',
    fontSize: '18px',
    cursor: 'pointer',
    color: '#888',
    lineHeight: 1,
  },
  dropdown: {
    position: 'absolute' as const,
    top: '100%',
    left: 0,
    right: 0,
    marginTop: '4px',
    backgroundColor: 'white',
    border: '1px solid #e5e7eb',
    borderRadius: '8px',
    boxShadow: '0 10px 30px rgba(0,0,0,0.15)',
    maxHeight: '320px',
    overflowY: 'auto' as const,
    zIndex: 50,
  },
  option: {
    display: 'block',
    width: '100%',
    textAlign: 'left' as const,
    padding: '10px 14px',
    background: 'none',
    border: 'none',
    borderBottom: '1px solid #f3f4f6',
    cursor: 'pointer',
    fontFamily: 'inherit',
  },
  optionTop: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '4px',
  },
  codeBadge: {
    backgroundColor: '#dbeafe',
    color: '#1e40af',
    padding: '2px 8px',
    borderRadius: '6px',
    fontSize: '11px',
    fontWeight: '600' as const,
    fontFamily: 'monospace',
  },
  category: {
    fontSize: '11px',
    color: '#888',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.5px',
  },
  name: {
    fontSize: '13px',
    color: '#1a1a2e',
  },
  empty: {
    padding: '16px',
    textAlign: 'center' as const,
    color: '#888',
    fontSize: '13px',
  },
  hint: {
    padding: '10px 14px',
    fontSize: '11px',
    color: '#888',
    textAlign: 'center' as const,
    backgroundColor: '#f9fafb',
  },
};