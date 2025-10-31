'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import MetricCard from '@/components/MetricCard';
import { tenantAPI, workflowAPI } from '@/lib/api';
import { getCurrentUser, isAuthenticated } from '@/lib/auth';
import { TenantMetrics, WorkflowExecution } from '@/types';

export default function DashboardPage() {
  const router = useRouter();
  const [metrics, setMetrics] = useState<TenantMetrics | null>(null);
  const [recentExecutions, setRecentExecutions] = useState<WorkflowExecution[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    if (!isAuthenticated()) {
      router.push('/login');
      return;
    }

    const currentUser = getCurrentUser();
    setUser(currentUser);

    if (currentUser?.tenantId) {
      loadDashboardData(currentUser.tenantId);
    }
  }, [router]);

  const loadDashboardData = async (tenantId: string) => {
    try {
      const [metricsData, executionsData] = await Promise.all([
        tenantAPI.getMetrics(tenantId),
        workflowAPI.getExecutions(tenantId, 10),
      ]);

      setMetrics(metricsData);
      setRecentExecutions(executionsData.executions || []);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">
            Welcome back, {user?.name}!
          </h1>
          <p className="mt-2 text-gray-600">
            Here's what's happening with your SEO automation.
          </p>
        </div>

        {/* Metrics Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <MetricCard
            title="Total Executions"
            value={metrics?.totalExecutions.toLocaleString() || '0'}
            description="Last 30 days"
            icon={<span className="text-2xl">🚀</span>}
          />
          <MetricCard
            title="Success Rate"
            value={
              metrics
                ? `${Math.round(
                    (metrics.successfulExecutions / metrics.totalExecutions) *
                      100
                  )}%`
                : '0%'
            }
            description="Successful workflows"
            icon={<span className="text-2xl">✅</span>}
            trend={{
              value: 12,
              isPositive: true,
            }}
          />
          <MetricCard
            title="Articles Published"
            value={metrics?.articlesPublished || 0}
            description={`Max: ${metrics?.maxArticlesPerWeek || 0}/week`}
            icon={<span className="text-2xl">📝</span>}
          />
          <MetricCard
            title="Pending Clusters"
            value={metrics?.pendingClusters || 0}
            description="Ready for WF3"
            icon={<span className="text-2xl">📊</span>}
          />
        </div>

        {/* Recent Activity */}
        <div className="bg-white rounded-lg shadow border border-gray-200 p-6 mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">
            Recent Workflow Executions
          </h2>

          {recentExecutions.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              No executions yet. Trigger your first workflow!
            </div>
          ) : (
            <div className="space-y-3">
              {recentExecutions.map((execution) => (
                <div
                  key={execution.id}
                  className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
                >
                  <div className="flex-1">
                    <h3 className="font-medium text-gray-900">
                      {execution.workflowName}
                    </h3>
                    <p className="text-sm text-gray-500">
                      Started: {new Date(execution.startedAt).toLocaleString()}
                    </p>
                  </div>
                  <div className="ml-4">
                    <span
                      className={`px-3 py-1 rounded-full text-sm font-medium ${
                        execution.status === 'success'
                          ? 'bg-green-100 text-green-800'
                          : execution.status === 'error'
                          ? 'bg-red-100 text-red-800'
                          : execution.status === 'running'
                          ? 'bg-yellow-100 text-yellow-800'
                          : 'bg-blue-100 text-blue-800'
                      }`}
                    >
                      {execution.status}
                    </span>
                  </div>
                  {execution.durationMs && (
                    <div className="ml-4 text-sm text-gray-500">
                      {(execution.durationMs / 1000).toFixed(1)}s
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <button
            onClick={() => router.push('/dashboard/workflows')}
            className="bg-white p-6 rounded-lg shadow border border-gray-200 hover:shadow-lg transition-shadow text-left"
          >
            <div className="text-3xl mb-2">🔄</div>
            <h3 className="text-lg font-semibold text-gray-900 mb-1">
              View Workflows
            </h3>
            <p className="text-sm text-gray-600">
              Check status and trigger WF1/WF2/WF3
            </p>
          </button>

          <button
            onClick={() => router.push('/dashboard/articles')}
            className="bg-white p-6 rounded-lg shadow border border-gray-200 hover:shadow-lg transition-shadow text-left"
          >
            <div className="text-3xl mb-2">📰</div>
            <h3 className="text-lg font-semibold text-gray-900 mb-1">
              Published Articles
            </h3>
            <p className="text-sm text-gray-600">
              View all generated content
            </p>
          </button>

          <button
            onClick={() => alert('Settings coming soon!')}
            className="bg-white p-6 rounded-lg shadow border border-gray-200 hover:shadow-lg transition-shadow text-left"
          >
            <div className="text-3xl mb-2">⚙️</div>
            <h3 className="text-lg font-semibold text-gray-900 mb-1">
              Settings
            </h3>
            <p className="text-sm text-gray-600">
              Configure credentials and preferences
            </p>
          </button>
        </div>
      </div>
    </div>
  );
}
