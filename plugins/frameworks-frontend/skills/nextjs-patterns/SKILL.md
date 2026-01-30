---
name: nextjs-patterns
description: Next.js App Router patterns for Server/Client Components, data fetching, caching, and server actions. Use when building Next.js applications.
---

# Next.js App Router Patterns

## Purpose

Provide patterns for building applications with Next.js App Router, including Server and Client Components, data fetching with SSR/SSG/ISR, caching strategies, middleware, route handlers, parallel and intercepting routes, and server actions.

## Project Structure

```
app/
  layout.tsx          # Root layout (required)
  page.tsx            # Home page
  loading.tsx         # Loading UI (Suspense boundary)
  error.tsx           # Error boundary
  not-found.tsx       # 404 page
  (auth)/             # Route group (no URL segment)
    login/page.tsx
    register/page.tsx
  dashboard/
    layout.tsx        # Nested layout
    page.tsx
    settings/page.tsx
  api/
    users/route.ts    # API route handler
  blog/
    [slug]/page.tsx   # Dynamic route
```

## Server vs Client Components

### Server Component (default)

```typescript
// app/users/page.tsx (Server Component by default)
import { db } from "@/lib/db";

export default async function UsersPage() {
  const users = await db.query.users.findMany();

  return (
    <section>
      <h1>Users</h1>
      <ul>
        {users.map((user) => (
          <li key={user.id}>{user.name}</li>
        ))}
      </ul>
    </section>
  );
}
```

### Client Component

```typescript
"use client";

import { useState } from "react";

export function Counter() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>Increment</button>
    </div>
  );
}
```

### Composition Pattern

```typescript
// Server Component wraps Client Component with data
import { db } from "@/lib/db";
import { UserList } from "./user-list"; // Client Component

export default async function UsersPage() {
  const users = await db.query.users.findMany();
  return <UserList initialUsers={users} />;
}
```

## Data Fetching

### Static Generation (SSG)

```typescript
// Statically generated at build time
export default async function BlogPage() {
  const posts = await fetchPosts(); // Cached indefinitely by default
  return <PostList posts={posts} />;
}

export async function generateStaticParams() {
  const posts = await fetchAllSlugs();
  return posts.map((post) => ({ slug: post.slug }));
}
```

### Server-Side Rendering (SSR)

```typescript
// Re-fetched on every request
export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const stats = await fetchDashboardStats();
  return <Dashboard stats={stats} />;
}
```

### Incremental Static Regeneration (ISR)

```typescript
// Revalidate every 60 seconds
export const revalidate = 60;

export default async function ProductsPage() {
  const products = await fetchProducts();
  return <ProductGrid products={products} />;
}
```

## Caching Strategies

### Fetch-Level Caching

```typescript
// Cache indefinitely (default)
const data = await fetch("https://api.example.com/data");

// Revalidate every 60 seconds
const data = await fetch("https://api.example.com/data", {
  next: { revalidate: 60 },
});

// No cache (always fresh)
const data = await fetch("https://api.example.com/data", {
  cache: "no-store",
});

// Tag-based revalidation
const data = await fetch("https://api.example.com/posts", {
  next: { tags: ["posts"] },
});
```

### On-Demand Revalidation

```typescript
// app/api/revalidate/route.ts
import { revalidatePath, revalidateTag } from "next/cache";

export async function POST(request: Request) {
  const { tag, path } = await request.json();

  if (tag) revalidateTag(tag);
  if (path) revalidatePath(path);

  return Response.json({ revalidated: true });
}
```

## Server Actions

```typescript
// app/actions.ts
"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

const createPostSchema = z.object({
  title: z.string().min(1),
  content: z.string().min(10),
});

export async function createPost(formData: FormData) {
  const parsed = createPostSchema.safeParse({
    title: formData.get("title"),
    content: formData.get("content"),
  });

  if (!parsed.success) {
    return { errors: parsed.error.flatten().fieldErrors };
  }

  await db.insert(posts).values(parsed.data);
  revalidatePath("/blog");
  redirect("/blog");
}
```

```typescript
// Usage in a Client Component
"use client";

import { createPost } from "../actions";
import { useActionState } from "react";

export function CreatePostForm() {
  const [state, formAction, pending] = useActionState(createPost, null);

  return (
    <form action={formAction}>
      <input name="title" required />
      {state?.errors?.title && <span>{state.errors.title}</span>}
      <textarea name="content" required />
      <button type="submit" disabled={pending}>
        {pending ? "Creating..." : "Create Post"}
      </button>
    </form>
  );
}
```

## Middleware

```typescript
// middleware.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const token = request.cookies.get("session-token");

  if (!token && request.nextUrl.pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  const response = NextResponse.next();
  response.headers.set("x-pathname", request.nextUrl.pathname);
  return response;
}

export const config = {
  matcher: ["/dashboard/:path*", "/api/:path*"],
};
```

## Route Handlers

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from "next/server";

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const page = Number(searchParams.get("page")) || 1;
  const users = await fetchUsers({ page });
  return NextResponse.json({ data: users });
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  const user = await createUser(body);
  return NextResponse.json({ data: user }, { status: 201 });
}
```

## Loading and Error States

```typescript
// app/dashboard/loading.tsx
export default function DashboardLoading() {
  return <div className="animate-pulse">Loading dashboard...</div>;
}

// app/dashboard/error.tsx
"use client";

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

## Best Practices

- Use Server Components by default; add `"use client"` only when needed (hooks, events, browser APIs)
- Fetch data in Server Components to avoid client-side waterfalls
- Use the composition pattern: Server Components fetch data, Client Components handle interactivity
- Use `loading.tsx` and `error.tsx` for automatic Suspense and Error Boundary wrappers
- Use route groups `(folder)` to organize routes without affecting the URL
- Use Server Actions for form mutations instead of API routes
- Apply ISR with `revalidate` for content that changes periodically
- Use tag-based revalidation for fine-grained cache invalidation
- Keep middleware lightweight; it runs on every matched request at the edge
- Use `generateStaticParams` to pre-render known dynamic routes at build time
