export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="text-center">
        <h1 className="text-4xl font-bold mb-4">
          🚀 BYTHEWISE SaaS
        </h1>
        <p className="text-xl text-gray-600 mb-8">
          Plateforme d'automatisation de génération de contenu SEO
        </p>
        <div className="space-x-4">
          <a
            href="/dashboard"
            className="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition"
          >
            Dashboard
          </a>
          <a
            href="/api"
            className="inline-block bg-gray-600 text-white px-6 py-3 rounded-lg hover:bg-gray-700 transition"
          >
            API Docs
          </a>
        </div>
      </div>
    </main>
  )
}
