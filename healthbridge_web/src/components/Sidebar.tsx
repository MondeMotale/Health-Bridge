import { useRouter } from 'next/router';

interface SidebarProps {
  onNavigate?: () => void;
}

const menuItems = [
  { name: 'Dashboard', path: '/dashboard', icon: 'dashboard' },
  { name: 'Referrals', path: '/referrals', icon: 'referrals', showBadge: true },
  { name: 'Patients', path: '/patients', icon: 'patients' },
  { name: 'Home-Based Care', path: '/hbc', icon: 'hbc' },
  { name: 'Reports', path: '/reports', icon: 'reports' },
  { name: 'Analytics', path: '/analytics', icon: 'analytics' },
  { name: 'Settings', path: '/settings', icon: 'settings' },
];

function Icon({ name, color = '#ffffff' }: { name: string; color?: string }) {
  const common = {
    width: 20,
    height: 20,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: color,
    strokeWidth: 2,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
  };
  switch (name) {
    case 'dashboard':
      return (
        <svg {...common}>
          <rect x="3" y="3" width="7" height="9" />
          <rect x="14" y="3" width="7" height="5" />
          <rect x="14" y="12" width="7" height="9" />
          <rect x="3" y="16" width="7" height="5" />
        </svg>
      );
    case 'referrals':
      return (
        <svg {...common}>
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
          <polyline points="14 2 14 8 20 8" />
          <line x1="9" y1="13" x2="15" y2="13" />
          <line x1="9" y1="17" x2="13" y2="17" />
        </svg>
      );
    case 'patients':
      return (
        <svg {...common}>
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
          <circle cx="9" cy="7" r="4" />
          <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
          <path d="M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
      );
    case 'hbc':
      return (
        <svg {...common}>
          <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
          <polyline points="9 22 9 12 15 12 15 22" />
        </svg>
      );
    case 'reports':
      return (
        <svg {...common}>
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
          <polyline points="14 2 14 8 20 8" />
          <line x1="16" y1="13" x2="8" y2="13" />
          <line x1="16" y1="17" x2="8" y2="17" />
          <polyline points="10 9 9 9 8 9" />
        </svg>
      );
    case 'analytics':
      return (
        <svg {...common}>
          <line x1="18" y1="20" x2="18" y2="10" />
          <line x1="12" y1="20" x2="12" y2="4" />
          <line x1="6" y1="20" x2="6" y2="14" />
        </svg>
      );
    case 'settings':
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="3" />
          <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />
        </svg>
      );
    default:
      return null;
  }
}

export default function Sidebar({ onNavigate }: SidebarProps) {
  const router = useRouter();

  return (
    <div className="w-64 bg-[#1a1a2e] text-white flex flex-col h-full">
      {/* Logo */}
      <div className="p-6 text-center border-b border-white/10">
        <div className="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center mx-auto mb-3">
          <span className="text-xl font-bold">HB</span>
        </div>
        <h2 className="text-lg font-semibold">HealthBridge</h2>
      </div>

      {/* Nav */}
      <nav className="flex-1 p-4 flex flex-col gap-1">
        {menuItems.map((item) => {
          const isActive = router.pathname === item.path;
          return (
            <button
              key={item.name}
              onClick={() => {
                router.push(item.path);
                onNavigate?.();
              }}
              className={`relative w-full px-4 py-3 rounded-lg flex items-center gap-3 transition-colors ${
                isActive
                  ? 'bg-blue-600 text-white'
                  : 'text-white/80 hover:bg-white/5'
              }`}
            >
              <Icon name={item.icon} color={isActive ? '#ffffff' : '#cbd5e1'} />
              <span className="text-sm font-medium">{item.name}</span>
              {item.showBadge && (
                <span className="absolute right-4 bg-red-500 text-white text-[10px] px-1.5 py-0.5 rounded-full">
                  new
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="p-5 border-t border-white/10 text-center">
        <p className="text-[11px] text-gray-400 mb-2">HealthBridge v1.0</p>
        <p className="text-[11px] text-emerald-400 flex items-center justify-center gap-1.5">
          <span className="w-2 h-2 bg-emerald-400 rounded-full inline-block"></span>
          Online
        </p>
      </div>
    </div>
  );
}