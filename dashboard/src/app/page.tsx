'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { isAuthenticated } from '@/lib/auth';
import Link from 'next/link';

export default function Home() {
  const router = useRouter();

  useEffect(() => {
    // Redirect to dashboard if authenticated
    if (isAuthenticated()) {
      router.push('/dashboard');
    }
  }, [router]);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24 bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="text-center max-w-3xl">
        <h1 className="text-6xl font-bold mb-4 text-gray-900">
          🚀 BYTHEWISE SaaS
        </h1>
        <p className="text-2xl text-gray-700 mb-8">
          Automated SEO Content Generation Platform
        </p>
        <p className="text-lg text-gray-600 mb-12">
          Transform 1 seed keyword into 200+ variations, cluster them
          intelligently, and automatically publish SEO-optimized articles to
          your WordPress site.
        </p>

        <div className="space-x-4">
          <Link
            href="/login"
            className="inline-block bg-blue-600 text-white px-8 py-4 rounded-lg hover:bg-blue-700 transition text-lg font-semibold shadow-lg"
          >
            Sign In
          </Link>
          <Link
            href="/register"
            className="inline-block bg-white text-blue-600 px-8 py-4 rounded-lg hover:bg-gray-100 transition text-lg font-semibold shadow-lg border-2 border-blue-600"
          >
            Get Started
          </Link>
        </div>

        <div className="mt-16 grid grid-cols-1 md:grid-cols-3 gap-8">
          <div className="bg-white p-6 rounded-lg shadow-md">
            <div className="text-4xl mb-3">📈</div>
            <h3 className="text-lg font-semibold mb-2">WF1 - Expansion</h3>
            <p className="text-gray-600 text-sm">
              1 seed → 200+ keyword variations
            </p>
          </div>
          <div className="bg-white p-6 rounded-lg shadow-md">
            <div className="text-4xl mb-3">🎯</div>
            <h3 className="text-lg font-semibold mb-2">WF2 - Clustering</h3>
            <p className="text-gray-600 text-sm">
              200 keywords → 60 smart clusters
            </p>
          </div>
          <div className="bg-white p-6 rounded-lg shadow-md">
            <div className="text-4xl mb-3">✍️</div>
            <h3 className="text-lg font-semibold mb-2">WF3 - Generation</h3>
            <p className="text-gray-600 text-sm">
              1 cluster → 1 published article
            </p>
          </div>
        </div>
      </div>
    </main>
  );
}
