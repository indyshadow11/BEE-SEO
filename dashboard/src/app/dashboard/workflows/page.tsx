'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import WorkflowStatus from '@/components/WorkflowStatus';
import { workflowAPI } from '@/lib/api';
import { getCurrentUser, isAuthenticated } from '@/lib/auth';
import { WorkflowStatus as WorkflowStatusType } from '@/types';

export default function WorkflowsPage() {
  const router = useRouter();
  const [workflows, setWorkflows] = useState<WorkflowStatusType[]>([]);
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
      loadWorkflows(currentUser.tenantId);
    }
  }, [router]);

  const loadWorkflows = async (tenantId: string) => {
    try {
      // Mock workflows data (replace with actual API call)
      const mockWorkflows: WorkflowStatusType[] = [
        {
          id: 'wf1-seed-expansion',
          name: 'WF1 - Seed Expansion',
          active: true,
          webhookUrl: `https://tenant.app.bythewise.com/webhook/wf1-seed-expansion`,
          lastExecution: {
            status: 'success',
            startedAt: new Date(Date.now() - 86400000).toISOString(),
            finishedAt: new Date(Date.now() - 86400000 + 120000).toISOString(),
          },
        },
        {
          id: 'wf2-clustering',
          name: 'WF2 - Clustering',
          active: true,
          webhookUrl: `https://tenant.app.bythewise.com/webhook/wf2-clustering`,
          lastExecution: {
            status: 'success',
            startedAt: new Date(Date.now() - 86400000 + 150000).toISOString(),
            finishedAt: new Date(Date.now() - 86400000 + 420000).toISOString(),
          },
        },
        {
          id: 'wf3-generation',
          name: 'WF3 - Article Generation',
          active: true,
          schedule: 'Mon & Thu at 8:00 AM',
          lastExecution: {
            status: 'success',
            startedAt: new Date(Date.now() - 259200000).toISOString(),
            finishedAt: new Date(Date.now() - 259200000 + 600000).toISOString(),
          },
        },
      ];

      setWorkflows(mockWorkflows);
    } catch (error) {
      console.error('Error loading workflows:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleExecuteWorkflow = async (workflowId: string) => {
    if (!user?.tenantId) return;

    try {
      const seedKeyword = prompt('Enter seed keyword for WF1:');
      if (!seedKeyword) return;

      await workflowAPI.execute(user.tenantId, workflowId, {
        seed_keyword: seedKeyword,
      });

      alert('Workflow triggered successfully!');
      loadWorkflows(user.tenantId);
    } catch (error) {
      console.error('Error executing workflow:', error);
      alert('Failed to execute workflow');
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading workflows...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Workflows</h1>
          <p className="mt-2 text-gray-600">
            Monitor and manage your SEO automation workflows
          </p>
        </div>

        {/* Info Banner */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-8">
          <h3 className="text-sm font-medium text-blue-900 mb-2">
            📖 Workflow Pipeline
          </h3>
          <div className="text-sm text-blue-800 space-y-1">
            <p>
              <strong>WF1:</strong> 1 seed keyword → 200+ variations (Manual
              trigger)
            </p>
            <p>
              <strong>WF2:</strong> 200 variations → ~60 clusters (Auto-trigger
              after WF1)
            </p>
            <p>
              <strong>WF3:</strong> 1 cluster → 1 article published (Mon & Thu
              8am)
            </p>
          </div>
        </div>

        {/* Workflows List */}
        <div className="space-y-6">
          {workflows.map((workflow) => (
            <WorkflowStatus
              key={workflow.id}
              workflow={workflow}
              onExecute={
                workflow.id === 'wf1-seed-expansion'
                  ? () => handleExecuteWorkflow(workflow.id)
                  : undefined
              }
            />
          ))}
        </div>

        {/* Documentation */}
        <div className="mt-8 bg-white rounded-lg shadow border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">
            How to Use
          </h2>
          <div className="space-y-4 text-sm text-gray-600">
            <div>
              <h3 className="font-medium text-gray-900 mb-1">
                Triggering WF1 (Seed Expansion)
              </h3>
              <p>
                Click the "Execute" button and enter a seed keyword (e.g.,
                "digital marketing"). The workflow will generate 200+ keyword
                variations and automatically trigger WF2.
              </p>
            </div>
            <div>
              <h3 className="font-medium text-gray-900 mb-1">
                WF2 Auto-Trigger
              </h3>
              <p>
                After WF1 completes, WF2 automatically clusters the keywords
                into ~60 semantic groups of 3 keywords each, ready for article
                generation.
              </p>
            </div>
            <div>
              <h3 className="font-medium text-gray-900 mb-1">
                WF3 Scheduled Execution
              </h3>
              <p>
                Every Monday and Thursday at 8:00 AM, WF3 automatically fetches
                a pending cluster, generates a complete SEO article, and
                publishes it to your WordPress site.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
