---
name: vercel-specialist
description: Vercel deployment and optimization patterns. Use when deploying to Vercel, configuring edge functions, ISR, or build optimization.
---

# Vercel Deployment Specialist

## Purpose

Provide patterns for deploying and optimizing applications on Vercel, including project configuration, environment variables, edge functions, ISR (Incremental Static Regeneration), middleware, analytics, custom domains, and build optimization.

## Project Configuration

### vercel.json

```json
{
  "framework": "nextjs",
  "buildCommand": "pnpm build",
  "outputDirectory": ".next",
  "installCommand": "pnpm install",
  "regions": ["iad1"],
  "rewrites": [
    { "source": "/api/:path*", "destination": "/api/:path*" }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "X-XSS-Protection", "value": "1; mode=block" },
        { "key": "Strict-Transport-Security", "value": "max-age=63072000" }
      ]
    },
    {
      "source": "/static/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    }
  ],
  "redirects": [
    { "source": "/old-path", "destination": "/new-path", "permanent": true }
  ]
}
```

## Environment Variables

### CLI Management

```bash
# Add a variable to production
vercel env add DATABASE_URL production

# Add to all environments
vercel env add NEXT_PUBLIC_API_URL

# Pull variables to local .env.local
vercel env pull .env.local

# List all variables
vercel env ls
```

### Environment Scoping

| Environment   | Purpose          | Example Variables               |
|---------------|------------------|---------------------------------|
| `production`  | Live site        | Production DB, live API keys    |
| `preview`     | PR previews      | Staging DB, test API keys       |
| `development` | Local dev        | Local DB, dev API keys          |

## Edge Functions

### Middleware

```typescript
// middleware.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  // Authentication check
  const token = request.cookies.get("auth-token");
  if (!token && request.nextUrl.pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  // Geolocation-based routing
  const country = request.geo?.country;
  if (country === "DE" && request.nextUrl.pathname === "/") {
    return NextResponse.redirect(new URL("/de", request.url));
  }

  // Add custom headers
  const response = NextResponse.next();
  response.headers.set("x-request-id", crypto.randomUUID());
  return response;
}

export const config = {
  matcher: ["/dashboard/:path*", "/api/:path*"],
};
```

### Edge API Route

```typescript
// app/api/hello/route.ts
export const runtime = "edge";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const name = searchParams.get("name") ?? "World";

  return new Response(JSON.stringify({ message: `Hello, ${name}!` }), {
    headers: { "Content-Type": "application/json" },
  });
}
```

## Incremental Static Regeneration (ISR)

```typescript
// app/blog/[slug]/page.tsx
export const revalidate = 3600; // Revalidate every hour

export async function generateStaticParams() {
  const posts = await fetchAllPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

export default async function BlogPost({ params }: { params: { slug: string } }) {
  const post = await fetchPost(params.slug);
  return <article><h1>{post.title}</h1><div>{post.content}</div></article>;
}
```

### On-Demand Revalidation

```typescript
// app/api/revalidate/route.ts
import { revalidatePath, revalidateTag } from "next/cache";
import { NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  const { path, tag, secret } = await request.json();

  if (secret !== process.env.REVALIDATION_SECRET) {
    return new Response("Invalid secret", { status: 401 });
  }

  if (tag) revalidateTag(tag);
  if (path) revalidatePath(path);

  return Response.json({ revalidated: true, now: Date.now() });
}
```

## Analytics and Web Vitals

```typescript
// app/layout.tsx
import { Analytics } from "@vercel/analytics/react";
import { SpeedInsights } from "@vercel/speed-insights/next";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
```

## Preview Deployments

### Git Integration

```yaml
# Automatic deployment configuration
production_branch: main
preview_branches:
  - develop
  - feature/*
  - fix/*

ignored_build_step: |
  if [[ "$VERCEL_GIT_COMMIT_REF" == "docs-only" ]]; then
    echo "Skipping build for docs branch"
    exit 0
  fi
```

### Deployment Protection

```json
{
  "vercelAuthentication": {
    "deployment": "standard_protection"
  }
}
```

## Custom Domains

### DNS Configuration

| Type  | Name | Value            | TTL  |
|-------|------|------------------|------|
| A     | @    | 76.76.21.21      | 3600 |
| CNAME | www  | cname.vercel-dns.com | 3600 |

### Automatic SSL

- Certificates provisioned automatically
- Auto-renewal before expiration
- HTTP to HTTPS redirect enabled by default
- HTTP/2 and HTTP/3 support

## Build Optimization

```json
{
  "build": {
    "env": {
      "NEXT_TELEMETRY_DISABLED": "1",
      "NODE_ENV": "production"
    }
  },
  "caching": {
    "dependencies": true,
    "buildOutputs": true
  }
}
```

### Performance Targets

| Metric             | Target       |
|--------------------|--------------|
| Build time         | < 3 minutes  |
| Cache hit rate     | > 80%        |
| LCP                | < 2.5s       |
| FID / INP          | < 200ms      |
| CLS                | < 0.1        |

## Serverless Function Configuration

```json
{
  "functions": {
    "api/heavy-task.ts": {
      "memory": 1024,
      "maxDuration": 30
    },
    "api/quick-response.ts": {
      "memory": 256,
      "maxDuration": 5
    }
  }
}
```

## Best Practices

- Test in preview deployments before promoting to production
- Use separate environment variables per environment (production, preview, development)
- Use edge middleware for auth checks, redirects, and geolocation routing
- Enable ISR with appropriate revalidation intervals for content-heavy pages
- Use on-demand revalidation via webhooks for CMS-driven content updates
- Add `@vercel/analytics` and `@vercel/speed-insights` for real user monitoring
- Set security headers globally in vercel.json for all routes
- Use `Cache-Control: immutable` for static assets with hashed filenames
- Configure function memory and duration limits based on actual needs
- Use the Vercel CLI (`vercel env pull`) to sync environment variables locally
