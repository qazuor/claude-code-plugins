---
name: vercel-react-best-practices
description: 57 performance optimization rules for React and Next.js from Vercel Engineering. Use when writing, reviewing, or refactoring React/Next.js code for optimal performance. Rules are prioritized by impact across 8 categories.
---

# Vercel React Best Practices

Based on [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (MIT License).

## Purpose

57 performance optimization rules for React and Next.js applications, prioritized by impact. Use when writing new components, reviewing code, refactoring for performance, optimizing bundle size, or fixing data fetching waterfalls.

## Activation

Reference these rules when:
- Writing new React components or Next.js pages
- Implementing data fetching (client or server-side)
- Reviewing code for performance issues
- Refactoring existing React/Next.js code
- Optimizing bundle size or load times
- Debugging re-render issues

## Rule Categories by Priority

| Priority | Category | Impact | Rules |
|----------|----------|--------|-------|
| 1 | Eliminating Waterfalls | CRITICAL | 5 |
| 2 | Bundle Size Optimization | CRITICAL | 5 |
| 3 | Server-Side Performance | HIGH | 7 |
| 4 | Client-Side Data Fetching | MEDIUM-HIGH | 4 |
| 5 | Re-render Optimization | MEDIUM | 12 |
| 6 | Rendering Performance | MEDIUM | 9 |
| 7 | JavaScript Performance | LOW-MEDIUM | 12 |
| 8 | Advanced Patterns | LOW | 3 |

---

## 1. Eliminating Waterfalls (CRITICAL)

Waterfalls are the #1 performance killer. Each sequential await adds full network latency.

### 1.1 Defer Await Until Needed

Move `await` into the branches where the value is actually used.

```typescript
// BAD: blocks both branches
async function handleRequest(userId: string, skipProcessing: boolean) {
  const userData = await fetchUserData(userId)
  if (skipProcessing) {
    return { skipped: true } // waited for userData unnecessarily
  }
  return processUserData(userData)
}

// GOOD: only blocks when needed
async function handleRequest(userId: string, skipProcessing: boolean) {
  if (skipProcessing) {
    return { skipped: true } // returns immediately
  }
  const userData = await fetchUserData(userId)
  return processUserData(userData)
}
```

Also applies to sequential checks — fetch only after validating earlier conditions:

```typescript
// GOOD: fetch permissions only after confirming resource exists
async function updateResource(resourceId: string, userId: string) {
  const resource = await getResource(resourceId)
  if (!resource) return { error: 'Not found' }

  const permissions = await fetchPermissions(userId)
  if (!permissions.canEdit) return { error: 'Forbidden' }

  return await updateResourceData(resource, permissions)
}
```

### 1.2 Parallelize Independent Operations

Use `Promise.all()` for independent async operations.

```typescript
// BAD: sequential — total time = sum of all
const user = await fetchUser()
const orders = await fetchOrders()
const config = await fetchConfig()

// GOOD: parallel — total time = max of all
const [user, orders, config] = await Promise.all([
  fetchUser(),
  fetchOrders(),
  fetchConfig(),
])
```

### 1.3 Partial Dependencies with Promise Chaining

When some operations depend on others but not all, chain only the dependent ones.

```typescript
// GOOD: fetchConfig runs parallel to user+profile chain
const userPromise = fetchUser()
const [profile, config] = await Promise.all([
  userPromise.then(user => fetchProfile(user.id)),
  fetchConfig(),
])
```

For complex dependency graphs, consider `better-all` for automated parallelization.

### 1.4 Start Promises Early in API Routes

In API routes and Server Actions, start independent operations immediately, await late.

```typescript
// BAD: sequential
export async function POST(req: Request) {
  const session = await auth()
  const config = await getConfig()
  const data = await fetchData(session.userId, config)
  return Response.json(data)
}

// GOOD: start auth and config in parallel
export async function POST(req: Request) {
  const sessionPromise = auth()
  const configPromise = getConfig()
  const [session, config] = await Promise.all([sessionPromise, configPromise])
  const data = await fetchData(session.userId, config)
  return Response.json(data)
}
```

### 1.5 Use Suspense to Stream Content

Wrap independent async components in Suspense boundaries so they stream independently.

```tsx
async function Page() {
  return (
    <div>
      <Header />
      <Suspense fallback={<StatsSkeleton />}>
        <Stats />
      </Suspense>
      <Suspense fallback={<ChartSkeleton />}>
        <RevenueChart />
      </Suspense>
    </div>
  )
}
```

---

## 2. Bundle Size Optimization (CRITICAL)

Reducing initial bundle size improves Time to Interactive and Largest Contentful Paint.

### 2.1 Avoid Barrel File Imports

Barrel files (index.ts re-exports) prevent tree-shaking and load thousands of unused modules.

```typescript
// BAD: loads all icons (~1,583 modules)
import { Search } from 'lucide-react'

// GOOD: direct import (~1 module)
import Search from 'lucide-react/dist/esm/icons/search'
```

For Next.js 13.5+, use `optimizePackageImports` in next.config.js:

```javascript
module.exports = {
  experimental: {
    optimizePackageImports: ['lucide-react', '@mui/material', 'date-fns'],
  },
}
```

Common offenders: lucide-react, @mui/material, @tabler/icons-react, react-icons, lodash, date-fns, rxjs.

### 2.2 Dynamic Import Heavy Components

Use `next/dynamic` or `React.lazy` for components with large dependencies.

```tsx
import dynamic from 'next/dynamic'

const Editor = dynamic(() => import('./Editor'), {
  loading: () => <EditorSkeleton />,
  ssr: false,
})

const Chart = dynamic(() => import('./Chart'), {
  loading: () => <ChartSkeleton />,
})
```

### 2.3 Defer Third-Party Scripts

Load analytics, logging, and non-critical scripts after hydration.

```tsx
import Script from 'next/script'

<Script src="https://analytics.example.com/script.js" strategy="afterInteractive" />
<Script src="https://chatwidget.example.com/widget.js" strategy="lazyOnload" />
```

### 2.4 Conditional Module Loading

Load large data or modules only when a feature is activated.

```tsx
function AnimationPlayer({ enabled }: { enabled: boolean }) {
  const [frames, setFrames] = useState<Frame[] | null>(null)

  useEffect(() => {
    if (!enabled || typeof window === 'undefined') return
    import('./animation-frames').then(m => setFrames(m.frames)).catch(() => {})
  }, [enabled])

  if (!frames) return null
  return <Player frames={frames} />
}
```

### 2.5 Preload on Hover/Focus

Preload the next page or heavy component when the user shows intent.

```tsx
function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  const preload = () => {
    const link = document.createElement('link')
    link.rel = 'prefetch'
    link.href = href
    document.head.appendChild(link)
  }

  return (
    <a href={href} onMouseEnter={preload} onFocus={preload}>
      {children}
    </a>
  )
}
```

---

## 3. Server-Side Performance (HIGH)

### 3.1 Authenticate Server Actions Like API Routes

Server Actions are public endpoints. Always verify auth inside each action.

```typescript
'use server'
import { verifySession } from '@/lib/auth'
import { z } from 'zod'

const schema = z.object({
  userId: z.string().uuid(),
  name: z.string().min(1).max(100),
})

export async function updateProfile(data: unknown) {
  const validated = schema.parse(data)
  const session = await verifySession()
  if (!session) throw new Error('Unauthorized')
  if (session.user.id !== validated.userId) throw new Error('Forbidden')

  await db.user.update({
    where: { id: validated.userId },
    data: { name: validated.name },
  })
  return { success: true }
}
```

### 3.2 React.cache() for Per-Request Deduplication

Multiple calls to the same function within a single request execute only once.

```typescript
import { cache } from 'react'

export const getCurrentUser = cache(async () => {
  const session = await auth()
  if (!session?.user?.id) return null
  return await db.user.findUnique({ where: { id: session.user.id } })
})
```

Use primitive args (not objects) — `React.cache()` uses `Object.is` for cache hits:

```typescript
// BAD: always cache miss (new object each call)
const getUser = cache(async (params: { uid: number }) => { ... })

// GOOD: cache hit (primitive equality)
const getUser = cache(async (uid: number) => { ... })
```

Note: `fetch()` in Next.js already has built-in memoization. Use `React.cache()` for database queries, auth checks, and other non-fetch async work.

### 3.3 LRU Cache for Cross-Request Caching

`React.cache()` only works within one request. Use LRU cache for data shared across requests.

```typescript
import { LRUCache } from 'lru-cache'

const cache = new LRUCache<string, User>({ max: 1000, ttl: 5 * 60 * 1000 })

export async function getUser(id: string) {
  const cached = cache.get(id)
  if (cached) return cached
  const user = await db.user.findUnique({ where: { id } })
  if (user) cache.set(id, user)
  return user
}
```

### 3.4 Avoid Duplicate Serialization in RSC Props

RSC serialization deduplicates by object reference, not value. Avoid transforming data on the server before passing to client components.

```tsx
// BAD: .toSorted() creates a new array, duplicating serialized data
async function Page() {
  const items = await getItems()
  return <ClientList items={items} sorted={items.toSorted(byDate)} />
}

// GOOD: pass data once, sort on client
async function Page() {
  const items = await getItems()
  return <ClientList items={items} />
}

// Client component
'use client'
function ClientList({ items }: { items: Item[] }) {
  const sorted = useMemo(() => items.toSorted(byDate), [items])
  return <ul>{sorted.map(renderItem)}</ul>
}
```

### 3.5 Minimize Data at RSC Boundaries

Only pass fields the client component actually uses.

```tsx
// BAD: sends 50 fields, client uses 2
async function Page() {
  const user = await getUser() // 50 fields
  return <UserAvatar user={user} />
}

// GOOD: extract only needed data
async function Page() {
  const user = await getUser()
  return <UserAvatar name={user.name} avatar={user.avatar} />
}
```

### 3.6 Restructure Components for Parallel Fetching

Nested async components create server-side waterfalls. Make them siblings.

```tsx
// BAD: sidebar waits for header to finish
async function Page() {
  return (
    <Layout>
      <Header /> {/* awaits fetch */}
      <Sidebar /> {/* waits for Header */}
    </Layout>
  )
}

// GOOD: siblings fetch in parallel
async function Page() {
  return (
    <div>
      <Suspense fallback={<HeaderSkeleton />}><Header /></Suspense>
      <Suspense fallback={<SidebarSkeleton />}><Sidebar /></Suspense>
    </div>
  )
}
```

### 3.7 Use after() for Non-Blocking Operations

Schedule work after the response is sent using Next.js `after()`.

```typescript
import { after } from 'next/server'

export async function POST(request: Request) {
  await updateDatabase(request)

  after(async () => {
    const userAgent = (await headers()).get('user-agent') || 'unknown'
    logUserAction({ userAgent })
  })

  return Response.json({ status: 'success' })
}
```

Common uses: analytics, audit logging, notifications, cache invalidation, cleanup tasks. Works in Server Actions, Route Handlers, and Server Components.

---

## 4. Client-Side Data Fetching (MEDIUM-HIGH)

### 4.1 SWR for Request Deduplication

SWR enables automatic deduplication, caching, and revalidation across component instances.

```tsx
import useSWR from 'swr'

function useUser(id: string) {
  return useSWR(`/api/users/${id}`, fetcher)
}

// Multiple components using useUser(same-id) → single request
```

Use `useSWRImmutable` for data that never changes. Use `useSWRMutation` for triggered operations.

### 4.2 Deduplicate Global Event Listeners

Share a single listener across all hook instances using a module-level Map.

```typescript
const keyCallbacks = new Map<string, Set<() => void>>()

function useKeyboardShortcut(key: string, callback: () => void) {
  useEffect(() => {
    let set = keyCallbacks.get(key)
    if (!set) {
      set = new Set()
      keyCallbacks.set(key, set)
    }
    set.add(callback)

    if (set.size === 1) {
      const handler = (e: KeyboardEvent) => {
        if (e.key === key) set!.forEach(cb => cb())
      }
      document.addEventListener('keydown', handler)
      return () => {
        set!.delete(callback)
        if (set!.size === 0) {
          document.removeEventListener('keydown', handler)
          keyCallbacks.delete(key)
        }
      }
    }

    return () => { set!.delete(callback) }
  }, [key, callback])
}
```

### 4.3 Passive Event Listeners for Scroll Performance

Add `{ passive: true }` to touch and wheel listeners for immediate scrolling.

```typescript
document.addEventListener('touchstart', handleTouch, { passive: true })
document.addEventListener('wheel', handleWheel, { passive: true })
```

Use for tracking, analytics, or any handler that does NOT call `preventDefault()`.

### 4.4 Version and Minimize localStorage Data

Add version prefixes, store only needed fields, wrap in try-catch.

```typescript
const STORAGE_VERSION = 'v2'

function getConfig(): AppConfig {
  try {
    const raw = localStorage.getItem(`config:${STORAGE_VERSION}`)
    return raw ? JSON.parse(raw) : DEFAULT_CONFIG
  } catch {
    return DEFAULT_CONFIG
  }
}

function setConfig(config: AppConfig) {
  try {
    // Store only UI-needed fields, not the full server response
    const minimal = { theme: config.theme, locale: config.locale }
    localStorage.setItem(`config:${STORAGE_VERSION}`, JSON.stringify(minimal))
  } catch { /* quota exceeded or private browsing */ }
}
```

---

## 5. Re-render Optimization (MEDIUM)

### 5.1 Defer State Reads to Usage Point

Don't subscribe to state only used in callbacks.

```tsx
// BAD: re-renders whenever searchParams change
function ShareButton() {
  const searchParams = useSearchParams() // subscription
  const handleShare = () => {
    navigator.clipboard.writeText(window.location.href)
  }
  return <button onClick={handleShare}>Share</button>
}

// GOOD: read on demand in the callback
function ShareButton() {
  const handleShare = () => {
    navigator.clipboard.writeText(window.location.href) // reads URL directly
  }
  return <button onClick={handleShare}>Share</button>
}
```

### 5.2 Extract Expensive Work into Memoized Components

Isolate expensive subtrees with `React.memo` so parent re-renders skip them.

```tsx
const ExpensiveChart = React.memo(function ExpensiveChart({ data }: { data: Point[] }) {
  return <canvas>{/* expensive rendering */}</canvas>
})
```

### 5.3 Hoist Default Non-Primitive Props

Inline defaults break memoization — extract them to constants.

```tsx
// BAD: () => {} creates a new reference every render, breaks memo
const UserAvatar = memo(function UserAvatar({ onClick = () => {} }: Props) { ... })

// GOOD: stable reference
const NOOP = () => {}
const UserAvatar = memo(function UserAvatar({ onClick = NOOP }: Props) { ... })
```

Same applies to default arrays `[]` and objects `{}`.

### 5.4 Use Primitive Dependencies in Effects

Specify primitive dependencies instead of objects.

```tsx
// BAD: re-runs when any user field changes
useEffect(() => { fetchProfile(user.id) }, [user])

// GOOD: only re-runs when ID changes
useEffect(() => { fetchProfile(user.id) }, [user.id])
```

For computed values, derive the boolean outside the effect:

```tsx
const isMobile = width < 768
useEffect(() => { updateLayout(isMobile) }, [isMobile]) // triggers only on boolean change
```

### 5.5 Subscribe to Derived Booleans, Not Raw Values

```tsx
// BAD: re-renders on every pixel change
function Sidebar() {
  const width = useWindowWidth()
  const isMobile = width < 768
  return <nav className={isMobile ? 'mobile' : 'desktop'} />
}

// GOOD: re-renders only when boolean changes
function Sidebar() {
  const isMobile = useMediaQuery('(max-width: 767px)')
  return <nav className={isMobile ? 'mobile' : 'desktop'} />
}
```

### 5.6 Derive State During Render, Not in Effects

If a value can be computed from current props/state, derive it inline.

```tsx
// BAD: redundant state + effect
function Form() {
  const [firstName, setFirstName] = useState('First')
  const [lastName, setLastName] = useState('Last')
  const [fullName, setFullName] = useState('')

  useEffect(() => {
    setFullName(firstName + ' ' + lastName)
  }, [firstName, lastName])

  return <p>{fullName}</p>
}

// GOOD: derive during render
function Form() {
  const [firstName, setFirstName] = useState('First')
  const [lastName, setLastName] = useState('Last')
  const fullName = firstName + ' ' + lastName

  return <p>{fullName}</p>
}
```

### 5.7 Functional setState for Stable Callbacks

Use functional form to eliminate stale closures and reduce deps.

```tsx
// BAD: stale closure risk, recreates on items change
const addItem = useCallback((newItem: Item) => {
  setItems([...items, newItem])
}, [items])

// GOOD: always uses current state, stable reference
const addItem = useCallback((newItem: Item) => {
  setItems(curr => [...curr, newItem])
}, [])
```

### 5.8 Lazy State Initialization

Pass a function to useState for expensive initial values.

```tsx
// BAD: buildSearchIndex runs on every render
const [index, setIndex] = useState(buildSearchIndex(items))

// GOOD: runs only on initial render
const [index, setIndex] = useState(() => buildSearchIndex(items))
```

Use for: parsing localStorage, building data structures, heavy transformations. Not needed for simple primitives.

### 5.9 Avoid Memo for Simple Expressions

Don't memoize cheap primitives.

```tsx
// BAD: useMemo overhead exceeds the computation
const isActive = useMemo(() => status === 'active', [status])

// GOOD: just compute it
const isActive = status === 'active'
```

### 5.10 Put Interaction Logic in Event Handlers

Run side effects from user actions in the handler, not in effects.

```tsx
// BAD: effect re-runs when unrelated deps change
const [submitted, setSubmitted] = useState(false)
useEffect(() => {
  if (submitted) {
    submitToAPI(data)
    toast.success('Submitted')
  }
}, [submitted, data]) // data changes also trigger!

// GOOD: run directly in handler
const handleSubmit = () => {
  submitToAPI(data)
  toast.success('Submitted')
}
```

### 5.11 Use startTransition for Non-Urgent Updates

```tsx
function SearchPage() {
  const [query, setQuery] = useState('')
  const [isPending, startTransition] = useTransition()

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    setQuery(e.target.value) // urgent: update input
    startTransition(() => {
      setSearchResults(filterItems(e.target.value)) // non-urgent
    })
  }

  return (
    <>
      <input value={query} onChange={handleChange} />
      {isPending && <Spinner />}
      <Results />
    </>
  )
}
```

### 5.12 Use Refs for Transient Frequent Values

Values that change often but don't need re-renders (mouse position, timers).

```tsx
// BAD: re-renders on every mousemove
function Tracker() {
  const [x, setX] = useState(0)
  useEffect(() => {
    const handler = (e: MouseEvent) => setX(e.clientX)
    window.addEventListener('mousemove', handler)
    return () => window.removeEventListener('mousemove', handler)
  }, [])
  return <div style={{ transform: `translateX(${x}px)` }} />
}

// GOOD: no re-renders, direct DOM update
function Tracker() {
  const lastXRef = useRef(0)
  const dotRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      lastXRef.current = e.clientX
      if (dotRef.current) {
        dotRef.current.style.transform = `translateX(${e.clientX}px)`
      }
    }
    window.addEventListener('mousemove', handler)
    return () => window.removeEventListener('mousemove', handler)
  }, [])

  return <div ref={dotRef} />
}
```

---

## 6. Rendering Performance (MEDIUM)

### 6.1 Animate Wrapper Divs, Not SVGs

SVG animation lacks GPU acceleration. Wrap SVGs in a div and animate that.

```tsx
// BAD: no GPU acceleration
<svg className="animate-spin"><circle ... /></svg>

// GOOD: GPU-accelerated via wrapper
<div className="animate-spin"><svg><circle ... /></svg></div>
```

Applies to: transform, opacity, translate, scale, rotate.

### 6.2 content-visibility for Long Lists

Skip rendering of off-screen elements.

```tsx
function MessageList({ messages }: { messages: Message[] }) {
  return (
    <div style={{ height: '600px', overflow: 'auto' }}>
      {messages.map(msg => (
        <div
          key={msg.id}
          style={{ contentVisibility: 'auto', containIntrinsicSize: '0 80px' }}
        >
          <MessageItem message={msg} />
        </div>
      ))}
    </div>
  )
}
```

With 1000 items, the browser skips layout/paint for ~990 off-screen items (~10x faster initial render).

### 6.3 Hoist Static JSX Outside Components

Static JSX recreated every render is wasted work.

```tsx
// BAD: recreates skeleton every render
function DataView({ data, isLoading }: Props) {
  if (isLoading) return <div className="animate-pulse h-32 bg-gray-200 rounded" />
  return <div>{data}</div>
}

// GOOD: create once at module level
const loadingSkeleton = <div className="animate-pulse h-32 bg-gray-200 rounded" />

function DataView({ data, isLoading }: Props) {
  if (isLoading) return loadingSkeleton
  return <div>{data}</div>
}
```

Especially helpful for large static SVG nodes. Note: React Compiler handles this automatically.

### 6.4 Reduce SVG Coordinate Precision

```xml
<!-- BAD: excessive precision -->
<path d="M10.293847 20.958372 L30.847261 40.192837" />

<!-- GOOD: minimal precision -->
<path d="M10.3 21 L30.8 40.2" />
```

Automate with SVGO: `npx svgo --precision=1 --multipass icon.svg`

### 6.5 Prevent Hydration Flicker for Client-Only Data

Use an inline script to read localStorage before React hydrates.

```tsx
function ThemeProvider({ children }: { children: React.ReactNode }) {
  return (
    <>
      <script
        dangerouslySetInnerHTML={{
          __html: `
            try {
              document.documentElement.dataset.theme =
                localStorage.getItem('theme') || 'light'
            } catch {}
          `,
        }}
      />
      {children}
    </>
  )
}
```

The inline script executes synchronously before rendering, preventing flash of wrong theme.

### 6.6 Suppress Expected Hydration Mismatches

For values that intentionally differ between server and client (timestamps, random IDs):

```tsx
// GOOD: suppresses expected warning
<span suppressHydrationWarning>{new Date().toLocaleString()}</span>
```

Do NOT use this to hide real bugs. Only for known, expected differences.

### 6.7 Activity Component for Show/Hide

Use React's `<Activity>` to preserve state and DOM for expensive toggle components.

```tsx
import { Activity } from 'react'

function Dropdown({ isOpen }: { isOpen: boolean }) {
  return (
    <Activity mode={isOpen ? 'visible' : 'hidden'}>
      <ExpensiveMenu />
    </Activity>
  )
}
```

Avoids expensive re-renders and state loss on toggle.

### 6.8 Use Ternary, Not && for Conditional Rendering

`&&` with `0` or `NaN` renders those values as text.

```tsx
// BAD: renders "0" when count is 0
{count && <Badge count={count} />}

// GOOD: renders nothing when count is 0
{count > 0 ? <Badge count={count} /> : null}
```

### 6.9 useTransition Over Manual Loading State

```tsx
// BAD: manual loading management
const [isLoading, setIsLoading] = useState(false)
const handleClick = async () => {
  setIsLoading(true)
  await fetchData()
  setIsLoading(false) // what if it throws?
}

// GOOD: automatic, resilient
const [isPending, startTransition] = useTransition()
const handleClick = () => {
  startTransition(async () => { await fetchData() })
}
```

Benefits: auto-resets on error, maintains responsiveness, handles interrupts.

---

## 7. JavaScript Performance (LOW-MEDIUM)

Micro-optimizations for hot paths that add up to meaningful improvements.

### 7.1 Avoid Layout Thrashing

Don't interleave style writes with layout reads.

```typescript
// BAD: forces reflow between writes and reads
element.style.width = '100px'
const width = element.offsetWidth // forced reflow!
element.style.height = '200px'

// GOOD: batch writes, then read
element.style.width = '100px'
element.style.height = '200px'
const { width, height } = element.getBoundingClientRect()

// BETTER: use CSS classes
element.classList.add('highlighted-box')
```

### 7.2 Build Index Maps for Repeated Lookups

```typescript
// BAD: O(n) per lookup × m lookups = O(n*m)
orders.map(order => {
  const user = users.find(u => u.id === order.userId)
  return { ...order, userName: user?.name }
})

// GOOD: O(n+m) total
const userMap = new Map(users.map(u => [u.id, u]))
orders.map(order => ({
  ...order,
  userName: userMap.get(order.userId)?.name,
}))
```

### 7.3 Cache Property Access in Hot Loops

```typescript
// BAD: 3 lookups × N iterations
for (let i = 0; i < arr.length; i++) {
  total += obj.config.settings.value * arr[i]
}

// GOOD: 1 lookup total
const val = obj.config.settings.value
const len = arr.length
for (let i = 0; i < len; i++) {
  total += val * arr[i]
}
```

### 7.4 Cache Function Results in Module-Level Map

```typescript
const formatCache = new Map<string, string>()

function formatCurrency(amount: number, currency: string): string {
  const key = `${amount}:${currency}`
  const cached = formatCache.get(key)
  if (cached) return cached

  const result = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
  }).format(amount)

  formatCache.set(key, result)
  return result
}
```

Works everywhere (utilities, event handlers), not just in React components.

### 7.5 Cache Storage API Calls

localStorage/sessionStorage are synchronous and expensive. Cache reads in memory.

```typescript
const storageCache = new Map<string, string | null>()

function getLocalStorage(key: string) {
  if (!storageCache.has(key)) {
    storageCache.set(key, localStorage.getItem(key))
  }
  return storageCache.get(key)
}

function setLocalStorage(key: string, value: string) {
  localStorage.setItem(key, value)
  storageCache.set(key, value)
}

// Invalidate on external changes
window.addEventListener('storage', (e) => {
  if (e.key) storageCache.delete(e.key)
})
```

### 7.6 Combine Multiple Array Iterations

```typescript
// BAD: 3 passes through the array
const admins = users.filter(u => u.role === 'admin')
const testers = users.filter(u => u.role === 'tester')
const inactive = users.filter(u => !u.active)

// GOOD: single pass
const admins: User[] = []
const testers: User[] = []
const inactive: User[] = []

for (const u of users) {
  if (u.role === 'admin') admins.push(u)
  if (u.role === 'tester') testers.push(u)
  if (!u.active) inactive.push(u)
}
```

### 7.7 Check Array Length Before Expensive Comparisons

```typescript
// BAD: parses every item even if arrays differ in size
function arraysEqual(a: Item[], b: Item[]) {
  return a.every((item, i) => JSON.stringify(item) === JSON.stringify(b[i]))
}

// GOOD: bail early on length mismatch
function arraysEqual(a: Item[], b: Item[]) {
  if (a.length !== b.length) return false
  return a.every((item, i) => JSON.stringify(item) === JSON.stringify(b[i]))
}
```

### 7.8 Return Early from Functions

```typescript
// BAD: processes all items even after finding error
function validateUsers(users: User[]) {
  let hasError = false
  let errorMessage = ''
  for (const user of users) {
    if (!user.email) { hasError = true; errorMessage = 'Email required' }
    if (!user.name) { hasError = true; errorMessage = 'Name required' }
  }
  return hasError ? { valid: false, error: errorMessage } : { valid: true }
}

// GOOD: returns immediately on first error
function validateUsers(users: User[]) {
  for (const user of users) {
    if (!user.email) return { valid: false, error: 'Email required' }
    if (!user.name) return { valid: false, error: 'Name required' }
  }
  return { valid: true }
}
```

### 7.9 Hoist RegExp Outside Loops

```typescript
// BAD: compiles regex on every iteration
for (const item of items) {
  if (/^[A-Z]{2,4}-\d+$/.test(item.code)) { ... }
}

// GOOD: compile once
const CODE_PATTERN = /^[A-Z]{2,4}-\d+$/
for (const item of items) {
  if (CODE_PATTERN.test(item.code)) { ... }
}
```

### 7.10 Use Loop for Min/Max Instead of Sort

```typescript
// BAD: O(n log n) — sorts entire array for one value
const latest = [...projects].sort((a, b) => b.updatedAt - a.updatedAt)[0]

// GOOD: O(n) — single pass
function getLatest(projects: Project[]) {
  if (projects.length === 0) return null
  let latest = projects[0]
  for (let i = 1; i < projects.length; i++) {
    if (projects[i].updatedAt > latest.updatedAt) latest = projects[i]
  }
  return latest
}
```

### 7.11 Use Set/Map for O(1) Lookups

```typescript
// BAD: O(n) per check
const allowedIds = ['a', 'b', 'c']
items.filter(item => allowedIds.includes(item.id))

// GOOD: O(1) per check
const allowedIds = new Set(['a', 'b', 'c'])
items.filter(item => allowedIds.has(item.id))
```

### 7.12 Use toSorted() for Immutable Sorting

`.sort()` mutates arrays in place, breaking React's immutability model.

```tsx
// BAD: mutates the users prop
const sorted = useMemo(() => users.sort((a, b) => a.name.localeCompare(b.name)), [users])

// GOOD: creates new array
const sorted = useMemo(() => users.toSorted((a, b) => a.name.localeCompare(b.name)), [users])
```

Also available: `.toReversed()`, `.toSpliced()`, `.with()`. Fallback: `[...arr].sort()`.

---

## 8. Advanced Patterns (LOW)

### 8.1 Store Event Handlers in Refs

Prevents effect re-subscriptions when handlers change.

```tsx
function useEventListener(event: string, handler: (e: Event) => void) {
  const handlerRef = useRef(handler)
  useEffect(() => { handlerRef.current = handler }, [handler])

  useEffect(() => {
    const listener = (e: Event) => handlerRef.current(e)
    window.addEventListener(event, listener)
    return () => window.removeEventListener(event, listener)
  }, [event]) // handler changes don't re-subscribe
}
```

Modern alternative: `useEffectEvent` provides the same stable reference pattern with a cleaner API.

### 8.2 Initialize App Once, Not Per Mount

Module-level guard prevents duplicate initialization during StrictMode or remounts.

```tsx
let didInit = false

function App() {
  useEffect(() => {
    if (didInit) return
    didInit = true
    loadFromStorage()
    checkAuthToken()
  }, [])
  // ...
}
```

Better: run initialization in your entry module before React renders.

### 8.3 useEffectEvent for Stable Callback Refs

Access latest values in callbacks without adding them to dependency arrays.

```tsx
const onSearchEvent = useEffectEvent(onSearch)

useEffect(() => {
  const timeout = setTimeout(() => onSearchEvent(query), 300)
  return () => clearTimeout(timeout)
}, [query]) // onSearch not needed in deps
```

Prevents unnecessary effect re-executions while avoiding stale closures.

---

## Quick Reference

### Priority Decision Guide

1. **Found a waterfall?** Fix it first (Section 1) — biggest impact
2. **Bundle too large?** Apply Section 2 rules
3. **Slow server responses?** Section 3 optimizations
4. **Redundant API calls?** Section 4 deduplication
5. **UI feels sluggish?** Sections 5-6 re-render and rendering rules
6. **Hot path code?** Section 7 JS micro-optimizations
7. **Subscription churn?** Section 8 advanced patterns
