---
name: prisma-patterns
description: Prisma patterns for schema design, Client API, migrations, and relations. Use when building database layers with Prisma ORM.
---

# Prisma ORM Patterns

## Purpose

Provide patterns for database operations with Prisma, including schema design, Client API for CRUD operations, relations, migrations, middleware, transactions, type-safe queries, and testing strategies.

## Schema Definition

### Models with Relations

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  role      Role     @default(USER)
  posts     Post[]
  profile   Profile?
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  @@map("users")
}

model Post {
  id          String     @id @default(cuid())
  title       String
  content     String?
  published   Boolean    @default(false)
  author      User       @relation(fields: [authorId], references: [id], onDelete: Cascade)
  authorId    String     @map("author_id")
  categories  Category[]
  createdAt   DateTime   @default(now()) @map("created_at")
  updatedAt   DateTime   @updatedAt @map("updated_at")
  deletedAt   DateTime?  @map("deleted_at")

  @@index([authorId])
  @@index([published])
  @@map("posts")
}

model Category {
  id    String @id @default(cuid())
  name  String @unique
  posts Post[]

  @@map("categories")
}

model Profile {
  id     String @id @default(cuid())
  bio    String?
  avatar String?
  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)
  userId String @unique @map("user_id")

  @@map("profiles")
}

enum Role {
  USER
  ADMIN
  EDITOR
}
```

## Client Setup

```typescript
// lib/prisma.ts
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["query", "warn", "error"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
```

## CRUD Operations

### Create

```typescript
// Create with relation
const user = await prisma.user.create({
  data: {
    email: "alice@example.com",
    name: "Alice",
    profile: {
      create: { bio: "Software developer" },
    },
  },
  include: { profile: true },
});

// Create many
const count = await prisma.post.createMany({
  data: [
    { title: "Post 1", authorId: user.id },
    { title: "Post 2", authorId: user.id },
  ],
  skipDuplicates: true,
});
```

### Read

```typescript
// Find unique
const user = await prisma.user.findUnique({
  where: { email: "alice@example.com" },
  include: { posts: true, profile: true },
});

// Find many with filters, sorting, and pagination
const posts = await prisma.post.findMany({
  where: {
    published: true,
    deletedAt: null,
    author: { role: "ADMIN" },
    title: { contains: "prisma", mode: "insensitive" },
  },
  orderBy: { createdAt: "desc" },
  skip: 0,
  take: 10,
  include: { author: { select: { name: true, email: true } } },
});

// Count
const totalPosts = await prisma.post.count({
  where: { published: true, deletedAt: null },
});
```

### Update

```typescript
// Update one
const updated = await prisma.post.update({
  where: { id: postId },
  data: { title: "Updated Title", published: true },
});

// Upsert
const user = await prisma.user.upsert({
  where: { email: "alice@example.com" },
  update: { name: "Alice Updated" },
  create: { email: "alice@example.com", name: "Alice" },
});

// Update many
await prisma.post.updateMany({
  where: { authorId: userId, published: false },
  data: { published: true },
});
```

### Delete

```typescript
// Soft delete
await prisma.post.update({
  where: { id: postId },
  data: { deletedAt: new Date() },
});

// Hard delete
await prisma.post.delete({ where: { id: postId } });
```

## Pagination

```typescript
async function getPaginatedPosts(page: number, pageSize: number) {
  const skip = (page - 1) * pageSize;

  const [posts, total] = await Promise.all([
    prisma.post.findMany({
      where: { published: true, deletedAt: null },
      orderBy: { createdAt: "desc" },
      skip,
      take: pageSize,
      include: { author: { select: { name: true } } },
    }),
    prisma.post.count({
      where: { published: true, deletedAt: null },
    }),
  ]);

  return {
    data: posts,
    pagination: {
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    },
  };
}
```

## Transactions

```typescript
// Interactive transaction
const result = await prisma.$transaction(async (tx) => {
  const post = await tx.post.create({
    data: { title: "New Post", authorId: userId },
  });

  await tx.post.update({
    where: { id: post.id },
    data: {
      categories: {
        connect: categoryIds.map((id) => ({ id })),
      },
    },
  });

  return post;
});

// Sequential transaction (simpler)
const [user, post] = await prisma.$transaction([
  prisma.user.create({ data: { email: "bob@example.com", name: "Bob" } }),
  prisma.post.create({ data: { title: "Hello", authorId: "..." } }),
]);
```

## Middleware

```typescript
// Soft delete middleware
prisma.$use(async (params, next) => {
  if (params.action === "delete") {
    params.action = "update";
    params.args.data = { deletedAt: new Date() };
  }

  if (params.action === "findMany" || params.action === "findFirst") {
    if (!params.args.where) params.args.where = {};
    params.args.where.deletedAt = null;
  }

  return next(params);
});

// Logging middleware
prisma.$use(async (params, next) => {
  const start = Date.now();
  const result = await next(params);
  const duration = Date.now() - start;
  console.log(`${params.model}.${params.action} - ${duration}ms`);
  return result;
});
```

## Migrations

```bash
# Create migration from schema changes
npx prisma migrate dev --name add_categories

# Apply migrations in production
npx prisma migrate deploy

# Reset database (development only)
npx prisma migrate reset

# Generate Prisma Client
npx prisma generate

# Open Prisma Studio
npx prisma studio
```

## Testing

```typescript
import { describe, it, expect, beforeEach, afterAll } from "vitest";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

describe("User operations", () => {
  beforeEach(async () => {
    await prisma.post.deleteMany();
    await prisma.user.deleteMany();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it("should create a user with posts", async () => {
    const user = await prisma.user.create({
      data: {
        email: "test@example.com",
        name: "Test User",
        posts: { create: [{ title: "Post 1" }] },
      },
      include: { posts: true },
    });

    expect(user.posts).toHaveLength(1);
    expect(user.posts[0].title).toBe("Post 1");
  });
});
```

## Best Practices

- Use the singleton pattern for PrismaClient to avoid connection exhaustion in development
- Use `include` for eager loading and `select` to fetch only needed fields
- Use `@map` and `@@map` to keep database column/table names in snake_case
- Implement soft deletes with a `deletedAt` field and middleware for automatic filtering
- Run `count` and `findMany` in parallel with `Promise.all` for pagination
- Use interactive transactions (`$transaction(async (tx) => ...)`) for multi-step operations
- Use `createMany` with `skipDuplicates` for bulk inserts
- Generate types from the schema; never manually define database types
- Use `prisma migrate dev` in development and `prisma migrate deploy` in production
- Add `@@index` to frequently queried columns for query performance
