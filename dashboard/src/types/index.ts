export interface User {
  id: string;
  email: string;
  name: string;
  tenantId: string;
  role: 'admin' | 'user' | 'viewer';
}

export interface Tenant {
  id: string;
  name: string;
  subdomain: string;
  plan: 'starter' | 'pro' | 'business' | 'enterprise';
  status: 'provisioning' | 'active' | 'suspended' | 'deleted';
  n8n_url: string;
  created_at: string;
}

export interface WorkflowExecution {
  id: string;
  workflowId: string;
  workflowName: string;
  status: 'running' | 'success' | 'error' | 'waiting';
  startedAt: string;
  finishedAt?: string;
  durationMs?: number;
  errorMessage?: string;
}

export interface Article {
  id: string;
  clusterId: string;
  title: string;
  content: string;
  wordpressUrl: string;
  wordpressId: number;
  publishedAt: string;
  metadata: {
    keywords?: string[];
    wordCount?: number;
    featuredImageUrl?: string;
  };
}

export interface Cluster {
  id: string;
  clusterId: string;
  keywords: string[];
  intent: string;
  topic: string;
  priority: 'high' | 'medium' | 'low';
  published: boolean;
  publishedAt?: string;
  createdAt: string;
}

export interface TenantMetrics {
  totalExecutions: number;
  successfulExecutions: number;
  failedExecutions: number;
  articlesPublished: number;
  clustersCreated: number;
  pendingClusters: number;
  maxWorkflows: number;
  maxExecutionsPerMonth: number;
  maxArticlesPerWeek: number;
}

export interface WorkflowStatus {
  id: string;
  name: string;
  active: boolean;
  lastExecution?: {
    status: string;
    startedAt: string;
    finishedAt?: string;
  };
  webhookUrl?: string;
  schedule?: string;
}
