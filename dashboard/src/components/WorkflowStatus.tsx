import { WorkflowStatus as WorkflowStatusType } from '@/types';

interface WorkflowStatusProps {
  workflow: WorkflowStatusType;
  onExecute?: () => void;
}

const statusColors = {
  running: 'bg-yellow-100 text-yellow-800',
  success: 'bg-green-100 text-green-800',
  error: 'bg-red-100 text-red-800',
  waiting: 'bg-blue-100 text-blue-800',
  inactive: 'bg-gray-100 text-gray-800',
};

export default function WorkflowStatus({
  workflow,
  onExecute,
}: WorkflowStatusProps) {
  const lastStatus = workflow.lastExecution?.status || 'inactive';

  const formatDate = (dateString?: string) => {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  };

  return (
    <div className="bg-white rounded-lg shadow border border-gray-200 p-6">
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <div className="flex items-center">
            <h3 className="text-lg font-semibold text-gray-900">
              {workflow.name}
            </h3>
            <span
              className={`ml-3 px-2.5 py-0.5 rounded-full text-xs font-medium ${
                workflow.active
                  ? 'bg-green-100 text-green-800'
                  : 'bg-gray-100 text-gray-800'
              }`}
            >
              {workflow.active ? 'Active' : 'Inactive'}
            </span>
          </div>

          {workflow.schedule && (
            <p className="mt-1 text-sm text-gray-500">
              📅 Schedule: {workflow.schedule}
            </p>
          )}

          {workflow.webhookUrl && (
            <p className="mt-1 text-sm text-gray-500 truncate">
              🔗 Webhook: {workflow.webhookUrl}
            </p>
          )}

          <div className="mt-4 grid grid-cols-2 gap-4">
            <div>
              <p className="text-xs text-gray-500">Last Execution</p>
              <p className="text-sm font-medium text-gray-900">
                {formatDate(workflow.lastExecution?.startedAt)}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500">Status</p>
              <span
                className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                  statusColors[lastStatus as keyof typeof statusColors] ||
                  statusColors.inactive
                }`}
              >
                {lastStatus}
              </span>
            </div>
          </div>
        </div>

        {onExecute && workflow.webhookUrl && (
          <button
            onClick={onExecute}
            className="ml-4 px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
          >
            Execute
          </button>
        )}
      </div>
    </div>
  );
}
