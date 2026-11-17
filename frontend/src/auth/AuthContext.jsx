import { createContext, useContext, useState } from 'react';

const AuthContext = createContext(null);

// STUB owned by B. Reads the saved user so routing can work. B adds the real login().
export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    try { return JSON.parse(localStorage.getItem('user')); } catch { return null; }
  });

  const saveLogin = (token, u) => {
    localStorage.setItem('token', token);
    localStorage.setItem('user', JSON.stringify(u));
    setUser(u);
  };
  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setUser(null);
  };

  return <AuthContext.Provider value={{ user, saveLogin, logout }}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
