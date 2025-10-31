import { getAuthToken } from './auth';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

async function fetchAPI(
  endpoint: string,
  options: RequestInit = {}
): Promise<any> {
  const token = getAuthToken();

  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new ApiError(
      response.status,
      errorData.message || response.statusText
    );
  }

  return response.json();
}

// Auth endpoints
export const authAPI = {
  login: (email: string, password: string) =>
    fetchAPI('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }),

  register: (name: string, email: string, password: string) =>
    fetchAPI('/api/auth/register', {
      method: 'POST',
      body: JSON.stringify({ name, email, password }),
    }),

  getCurrentUser: () => fetchAPI('/api/auth/me'),
};

// Tenant endpoints
export const tenantAPI = {
  getStatus: (tenantId: string) =>
    fetchAPI(`/api/tenants/${tenantId}/status`),

  getMetrics: (tenantId: string) =>
    fetchAPI(`/api/tenants/${tenantId}/metrics`),

  list: () => fetchAPI('/api/tenants'),
};

// Workflow endpoints
export const workflowAPI = {
  list: (tenantId: string) =>
    fetchAPI(`/api/tenants/${tenantId}/workflows`),

  getStatus: (tenantId: string, workflowId: string) =>
    fetchAPI(`/api/tenants/${tenantId}/workflows/${workflowId}/status`),

  execute: (tenantId: string, workflowId: string, data: any) =>
    fetchAPI(`/api/tenants/${tenantId}/workflows/${workflowId}/execute`, {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  getExecutions: (tenantId: string, limit = 20) =>
    fetchAPI(`/api/tenants/${tenantId}/executions?limit=${limit}`),
};

// Articles endpoints
export const articlesAPI = {
  list: (tenantId: string, limit = 20) =>
    fetchAPI(`/api/tenants/${tenantId}/articles?limit=${limit}`),

  get: (tenantId: string, articleId: string) =>
    fetchAPI(`/api/tenants/${tenantId}/articles/${articleId}`),
};

// Clusters endpoints
export const clustersAPI = {
  list: (tenantId: string, published?: boolean) => {
    const query = published !== undefined ? `?published=${published}` : '';
    return fetchAPI(`/api/tenants/${tenantId}/clusters${query}`);
  },
};

export default {
  auth: authAPI,
  tenant: tenantAPI,
  workflow: workflowAPI,
  articles: articlesAPI,
  clusters: clustersAPI,
};
