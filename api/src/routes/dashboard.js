/**
 * Dashboard routes for tenant metrics, workflows, and articles
 */

// Mock data for demo
const mockData = {
  metrics: {
    totalExecutions: 1247,
    successfulExecutions: 1189,
    failedExecutions: 58,
    articlesPublished: 12,
    clustersCreated: 67,
    pendingClusters: 23,
    maxWorkflows: 25,
    maxExecutionsPerMonth: 50000,
    maxArticlesPerWeek: 8,
  },
  workflows: [
    {
      id: 'wf1-seed-expansion',
      name: 'WF1 - Seed Expansion',
      active: true,
      webhookUrl: 'https://tenant.app.bythewise.com/webhook/wf1-seed-expansion',
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
      webhookUrl: 'https://tenant.app.bythewise.com/webhook/wf2-clustering',
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
  ],
  executions: [
    {
      id: 'exec-001',
      workflowId: 'wf3-generation',
      workflowName: 'WF3 - Article Generation',
      status: 'success',
      startedAt: new Date(Date.now() - 259200000).toISOString(),
      finishedAt: new Date(Date.now() - 259200000 + 600000).toISOString(),
      durationMs: 600000,
    },
    {
      id: 'exec-002',
      workflowId: 'wf2-clustering',
      workflowName: 'WF2 - Clustering',
      status: 'success',
      startedAt: new Date(Date.now() - 86400000 + 150000).toISOString(),
      finishedAt: new Date(Date.now() - 86400000 + 420000).toISOString(),
      durationMs: 270000,
    },
    {
      id: 'exec-003',
      workflowId: 'wf1-seed-expansion',
      workflowName: 'WF1 - Seed Expansion',
      status: 'success',
      startedAt: new Date(Date.now() - 86400000).toISOString(),
      finishedAt: new Date(Date.now() - 86400000 + 120000).toISOString(),
      durationMs: 120000,
    },
    {
      id: 'exec-004',
      workflowId: 'wf1-seed-expansion',
      workflowName: 'WF1 - Seed Expansion',
      status: 'success',
      startedAt: new Date(Date.now() - 172800000).toISOString(),
      finishedAt: new Date(Date.now() - 172800000 + 115000).toISOString(),
      durationMs: 115000,
    },
    {
      id: 'exec-005',
      workflowId: 'wf2-clustering',
      workflowName: 'WF2 - Clustering',
      status: 'error',
      startedAt: new Date(Date.now() - 345600000).toISOString(),
      finishedAt: new Date(Date.now() - 345600000 + 45000).toISOString(),
      durationMs: 45000,
      errorMessage: 'OpenAI API rate limit exceeded',
    },
  ],
  articles: [
    {
      id: 'article-001',
      clusterId: 'cluster_123',
      title: 'The Ultimate Guide to Digital Marketing in 2025',
      content: 'Full article content...',
      wordpressUrl: 'https://example.com/digital-marketing-guide-2025',
      wordpressId: 1001,
      publishedAt: new Date(Date.now() - 172800000).toISOString(),
      metadata: {
        keywords: [
          'digital marketing',
          'online marketing strategy',
          'marketing automation',
        ],
        wordCount: 2847,
        featuredImageUrl: 'https://example.com/image1.jpg',
      },
    },
    {
      id: 'article-002',
      clusterId: 'cluster_124',
      title: 'SEO Best Practices for E-commerce Websites',
      content: 'Full article content...',
      wordpressUrl: 'https://example.com/seo-ecommerce-best-practices',
      wordpressId: 1002,
      publishedAt: new Date(Date.now() - 432000000).toISOString(),
      metadata: {
        keywords: [
          'SEO best practices',
          'e-commerce SEO',
          'product page optimization',
        ],
        wordCount: 3124,
        featuredImageUrl: 'https://example.com/image2.jpg',
      },
    },
    {
      id: 'article-003',
      clusterId: 'cluster_125',
      title: 'How to Build a Content Marketing Strategy That Works',
      content: 'Full article content...',
      wordpressUrl: 'https://example.com/content-marketing-strategy',
      wordpressId: 1003,
      publishedAt: new Date(Date.now() - 691200000).toISOString(),
      metadata: {
        keywords: [
          'content marketing strategy',
          'content planning',
          'content calendar',
        ],
        wordCount: 2956,
        featuredImageUrl: 'https://example.com/image3.jpg',
      },
    },
  ],
};

export default async function dashboardRoutes(fastify, options) {
  /**
   * GET /api/tenants/:id/metrics
   * Get tenant metrics
   */
  fastify.get('/:id/metrics', {
    preHandler: [fastify.authenticate, fastify.checkTenantAccess],
  }, async (request, reply) => {
    const { id: tenantId } = request.params;

    return {
      success: true,
      ...mockData.metrics,
    };
  });

  /**
   * GET /api/tenants/:id/status
   * Get tenant status
   */
  fastify.get('/:id/status', {
    preHandler: [fastify.authenticate, fastify.checkTenantAccess],
  }, async (request, reply) => {
    const { id: tenantId } = request.params;

    return {
      success: true,
      tenant: {
        id: tenantId,
        name: 'Demo Tenant',
        subdomain: 'demo',
        plan: 'pro',
        status: 'active',
        n8n_url: 'https://demo.app.bythewise.com',
        created_at: new Date(Date.now() - 2592000000).toISOString(),
      },
    };
  });

  /**
   * GET /api/tenants/:id/workflows
   * List workflows for tenant
   */
  fastify.get('/:id/workflows', {
    preHandler: [fastify.authenticate, fastify.checkTenantAccess],
  }, async (request, reply) => {
    const { id: tenantId } = request.params;

    return {
      success: true,
      workflows: mockData.workflows,
    };
  });

  /**
   * GET /api/tenants/:id/executions
   * Get workflow executions history
   */
  fastify.get('/:id/executions', {
    preHandler: [fastify.authenticate, fastify.checkTenantAccess],
  }, async (request, reply) => {
    const { id: tenantId } = request.params;
    const { limit = 20 } = request.query;

    return {
      success: true,
      executions: mockData.executions.slice(0, parseInt(limit)),
      total: mockData.executions.length,
    };
  });

  /**
   * POST /api/tenants/:id/workflows/:workflowId/execute
   * Execute a workflow
   */
  fastify.post('/:id/workflows/:workflowId/execute', {
    preHandler: [fastify.authenticate, fastify.checkTenantAccess],
  }, async (request, reply) => {
    const { id: tenantId, workflowId } = request.params;
    const data = request.body;

    // Mock execution response
    const executionId = `exec-${Date.now()}`;

    return {
      success: true,
      message: 'Workflow execution triggered',
      executionId,
      workflowId,
      data,
    };
  });

  /**
   * GET /api/tenants/:id/articles
   * Get published articles
   */
  fastify.get('/:id/articles', {
    preHandler: [fastify.authenticate, fastify.checkTenantAccess],
  }, async (request, reply) => {
    const { id: tenantId } = request.params;
    const { limit = 20 } = request.query;

    return {
      success: true,
      articles: mockData.articles.slice(0, parseInt(limit)),
      total: mockData.articles.length,
    };
  });

  /**
   * GET /api/tenants/:id/articles/:articleId
   * Get single article
   */
  fastify.get('/:id/articles/:articleId', {
    preHandler: [fastify.authenticate, fastify.checkTenantAccess],
  }, async (request, reply) => {
    const { id: tenantId, articleId } = request.params;

    const article = mockData.articles.find((a) => a.id === articleId);

    if (!article) {
      return reply.code(404).send({
        error: 'Not Found',
        message: 'Article not found',
      });
    }

    return {
      success: true,
      article,
    };
  });

  /**
   * GET /api/tenants/:id/clusters
   * Get clusters
   */
  fastify.get('/:id/clusters', {
    preHandler: [fastify.authenticate, fastify.checkTenantAccess],
  }, async (request, reply) => {
    const { id: tenantId } = request.params;
    const { published } = request.query;

    // Mock clusters
    const clusters = [
      {
        id: 'cluster_123',
        keywords: ['digital marketing', 'online marketing', 'internet marketing'],
        intent: 'informational',
        topic: 'Digital Marketing',
        priority: 'high',
        published: true,
        publishedAt: new Date(Date.now() - 172800000).toISOString(),
      },
      {
        id: 'cluster_124',
        keywords: ['SEO best practices', 'search optimization', 'SEO tips'],
        intent: 'informational',
        topic: 'SEO',
        priority: 'high',
        published: true,
        publishedAt: new Date(Date.now() - 432000000).toISOString(),
      },
      {
        id: 'cluster_125',
        keywords: ['content marketing', 'content strategy', 'content planning'],
        intent: 'informational',
        topic: 'Content Marketing',
        priority: 'medium',
        published: false,
      },
    ];

    const filteredClusters = published !== undefined
      ? clusters.filter((c) => c.published === (published === 'true'))
      : clusters;

    return {
      success: true,
      clusters: filteredClusters,
      total: filteredClusters.length,
    };
  });
}
