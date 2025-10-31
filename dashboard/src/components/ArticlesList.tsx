import { Article } from '@/types';

interface ArticlesListProps {
  articles: Article[];
  isLoading?: boolean;
}

export default function ArticlesList({
  articles,
  isLoading = false,
}: ArticlesListProps) {
  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    }).format(date);
  };

  if (isLoading) {
    return (
      <div className="bg-white rounded-lg shadow border border-gray-200 p-8">
        <div className="animate-pulse space-y-4">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="h-20 bg-gray-200 rounded"></div>
          ))}
        </div>
      </div>
    );
  }

  if (articles.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow border border-gray-200 p-8 text-center">
        <div className="text-gray-400 text-6xl mb-4">📝</div>
        <h3 className="text-lg font-medium text-gray-900 mb-2">
          No articles yet
        </h3>
        <p className="text-gray-500">
          Articles will appear here once WF3 generates and publishes them.
        </p>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow border border-gray-200 divide-y divide-gray-200">
      {articles.map((article) => (
        <div key={article.id} className="p-6 hover:bg-gray-50 transition-colors">
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                {article.title}
              </h3>

              <div className="flex items-center space-x-4 text-sm text-gray-500">
                <span>📅 {formatDate(article.publishedAt)}</span>
                {article.metadata?.wordCount && (
                  <span>📄 {article.metadata.wordCount.toLocaleString()} words</span>
                )}
                {article.metadata?.keywords && (
                  <span>🔑 {article.metadata.keywords.length} keywords</span>
                )}
              </div>

              {article.metadata?.keywords && (
                <div className="mt-3 flex flex-wrap gap-2">
                  {article.metadata.keywords.slice(0, 5).map((keyword, i) => (
                    <span
                      key={i}
                      className="px-2 py-1 bg-blue-50 text-blue-700 text-xs font-medium rounded"
                    >
                      {keyword}
                    </span>
                  ))}
                  {article.metadata.keywords.length > 5 && (
                    <span className="px-2 py-1 bg-gray-100 text-gray-600 text-xs font-medium rounded">
                      +{article.metadata.keywords.length - 5} more
                    </span>
                  )}
                </div>
              )}
            </div>

            <div className="ml-4 flex flex-col items-end space-y-2">
              {article.wordpressUrl && (
                <a
                  href={article.wordpressUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
                >
                  View on WordPress
                </a>
              )}
              <span className="text-xs text-gray-500">
                ID: {article.wordpressId}
              </span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
