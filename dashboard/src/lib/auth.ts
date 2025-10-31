import { jwtDecode } from 'jwt-decode';

const TOKEN_KEY = 'bythewise_auth_token';
const USER_KEY = 'bythewise_user';

export interface User {
  id: string;
  email: string;
  name: string;
  tenantId: string;
  role: string;
}

export interface AuthToken {
  token: string;
  user: User;
  expiresAt: number;
}

// Get auth token from localStorage
export function getAuthToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(TOKEN_KEY);
}

// Set auth token in localStorage
export function setAuthToken(token: string): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem(TOKEN_KEY, token);
}

// Remove auth token
export function removeAuthToken(): void {
  if (typeof window === 'undefined') return;
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}

// Get current user from localStorage
export function getCurrentUser(): User | null {
  if (typeof window === 'undefined') return null;

  const userJson = localStorage.getItem(USER_KEY);
  if (!userJson) return null;

  try {
    return JSON.parse(userJson);
  } catch {
    return null;
  }
}

// Set current user in localStorage
export function setCurrentUser(user: User): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

// Check if token is expired
export function isTokenExpired(token: string): boolean {
  try {
    const decoded: any = jwtDecode(token);
    if (!decoded.exp) return false;

    const currentTime = Date.now() / 1000;
    return decoded.exp < currentTime;
  } catch {
    return true;
  }
}

// Check if user is authenticated
export function isAuthenticated(): boolean {
  const token = getAuthToken();
  if (!token) return false;

  return !isTokenExpired(token);
}

// Login
export function login(token: string, user: User): void {
  setAuthToken(token);
  setCurrentUser(user);
}

// Logout
export function logout(): void {
  removeAuthToken();
  if (typeof window !== 'undefined') {
    window.location.href = '/login';
  }
}

// Get tenant ID from current user
export function getTenantId(): string | null {
  const user = getCurrentUser();
  return user?.tenantId || null;
}
