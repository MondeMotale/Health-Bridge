import { useRouter } from 'next/router';

interface HeaderProps {
  onMenuClick: () => void;
}

const PAGE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/referrals': 'Referrals',
  '/patients': 'Patients',
  '/hbc': 'Home-Based Care',
  '/reports': 'Reports',
  '/analytics': 'Analytics',
  '/settings': 'Settings',
};

export default function Header({ onMenuClick }: HeaderProps) {
  const router = useRouter();
  const title = PAGE_TITLES[router.pathname] || 'Dashboard';

  const handleLogout = () => {
    localStorage.removeItem('isLoggedIn');
    router.push('/');
  };

  return (
    <header className="bg-white border-b border-gray-200 px-4 md:px-6 py-3 flex justify-between items-center">
      {/* Left — hamburger (mobile only) + title */}
      <div className="flex items-center gap-3">
        <button
          onClick={onMenuClick}
          className="md:hidden p-2 rounded-lg hover:bg-gray-100"
          aria-label="Open menu"
        >
          <svg
            width="22"
            height="22"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#1a1a2e"
            strokeWidth="2"
            strokeLinecap="round"
          >
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>

        <div>
          <h2 className="text-base md:text-xl font-semibold text-[#1a1a2e] m-0">
            {title}
          </h2>
          <p className="hidden sm:block text-xs md:text-sm text-gray-500 mt-0.5">
            Welcome back, Admin
          </p>
        </div>
      </div>

      {/* Right — user + logout */}
      <div className="flex items-center gap-3 md:gap-5">
        <div className="hidden md:flex items-center gap-3">
          <div className="text-right">
            <p className="text-sm font-medium text-gray-800 m-0">ADMIN</p>
            <p className="text-xs text-gray-500 mt-0.5">Administrator</p>
          </div>
          <div className="w-9 h-9 md:w-10 md:h-10 bg-blue-600 rounded-full flex items-center justify-center">
            <span className="text-white text-sm font-bold">MM</span>
          </div>
        </div>

        <button
          onClick={handleLogout}
          className="px-3 md:px-4 py-2 bg-red-600 text-white rounded-md text-xs md:text-sm font-medium hover:bg-red-700 transition-colors"
        >
          Logout
        </button>
      </div>
    </header>
  );
}