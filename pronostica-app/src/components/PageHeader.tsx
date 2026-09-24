import { useNavigate } from 'react-router-dom';
import { BackIcon } from './icons';

export function PageHeader({ title }: { title: string }) {
  const navigate = useNavigate();
  return (
    <div style={{ flex: 'none', padding: '6px 18px 12px', display: 'flex', alignItems: 'center', gap: 12 }}>
      <div
        onClick={() => navigate(-1)}
        style={{ flex: 'none', width: 36, height: 36, borderRadius: 11, background: 'var(--color-surface)', border: '1px solid var(--color-border)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}
      >
        <BackIcon />
      </div>
      <span style={{ fontFamily: 'var(--font-heading)', fontSize: 20 }}>{title}</span>
    </div>
  );
}
