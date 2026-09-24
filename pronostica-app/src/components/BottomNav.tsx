import { NavLink } from 'react-router-dom';
import { HomeIcon, PronosticiIcon, ClassificaIcon, MenuIcon } from './icons';
import './BottomNav.css';

const items = [
  { to: '/', label: 'Home', Icon: HomeIcon, end: true },
  { to: '/pronostici', label: 'Pronostici', Icon: PronosticiIcon, end: false },
  { to: '/classifica', label: 'Classifica', Icon: ClassificaIcon, end: false },
  { to: '/menu', label: 'Menu', Icon: MenuIcon, end: false },
];

export function BottomNav() {
  return (
    <nav className="bottom-nav">
      {items.map(({ to, label, Icon, end }) => (
        <NavLink key={to} to={to} end={end} className="bottom-nav__item">
          {({ isActive }) => (
            <>
              <Icon color={isActive ? '#101A33' : '#5B6785'} />
              <span className={isActive ? 'bottom-nav__label bottom-nav__label--active' : 'bottom-nav__label'}>
                {label}
              </span>
            </>
          )}
        </NavLink>
      ))}
    </nav>
  );
}
