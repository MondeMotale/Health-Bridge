import { useEffect, useState } from 'react';
import { collection, getDocs, updateDoc, doc } from 'firebase/firestore';
import { db } from '../lib/firebase';

export default function Migrate() {
  const [log, setLog] = useState<string[]>([]);

  useEffect(() => {
    const run = async () => {
      const lines: string[] = [];
      const snap = await getDocs(collection(db, 'patients'));
      let fixed = 0;

      for (const d of snap.docs) {
        const data = d.data();
        if (!data.conditionCode && data.condition) {
          const match = String(data.condition).match(/^([A-Z]\d{2}(?:\.\d+)?)/);
          if (match) {
            await updateDoc(doc(db, 'patients', d.id), { conditionCode: match[1] });
            fixed++;
            lines.push(`✔ ${data.name} → ${match[1]}`);
          } else {
            lines.push(`⚠ ${data.name} → no code in "${data.condition}"`);
          }
        }
      }
      lines.push(`Fixed ${fixed} patients`);
      setLog(lines);
    };
    run();
  }, []);

  return (
    <div style={{ padding: '24px', fontFamily: 'monospace' }}>
      <h1>Migration log</h1>
      {log.map((l, i) => <p key={i}>{l}</p>)}
      <p style={{ marginTop: '24px', color: '#666' }}>Delete this file when done.</p>
    </div>
  );
}