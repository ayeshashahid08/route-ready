import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import LoginPage from './auth/LoginPage';
import HeadHome from './head/HeadHome';
import StudentHome from './student/StudentHome';
import CaptainHome from './captain/CaptainHome';

// Where each person lands after login. A head who also drives lands on the head area.
function homeFor(user) {
  if (user.roles.includes('head')) return '/head';
  if (user.roles.includes('captain')) return '/captain';
  return '/student';
}

// Blocks a page unless the logged-in user has the needed role.
function RequireRole({ role, children }) {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  if (!user.roles.includes(role)) return <Navigate to={homeFor(user)} replace />;
  return children;
}

function Home() {
  const { user } = useAuth();
  return <Navigate to={user ? homeFor(user) : '/login'} replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="/login" element={<LoginRoute />} />
      <Route path="/head/*" element={<RequireRole role="head"><HeadHome /></RequireRole>} />
      <Route path="/student/*" element={<RequireRole role="student"><StudentHome /></RequireRole>} />
      <Route path="/captain/*" element={<RequireRole role="captain"><CaptainHome /></RequireRole>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

// If someone is already logged in, /login sends them to their home page instead.
function LoginRoute() {
  const { user } = useAuth();
  return user ? <Navigate to={homeFor(user)} replace /> : <LoginPage />;
}
