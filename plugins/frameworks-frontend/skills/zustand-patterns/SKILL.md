---
name: zustand-patterns
description: Zustand state management patterns with middleware. Use when creating stores, slice patterns, persist/immer middleware, or computed values.
---

# Zustand State Management Patterns

## Purpose

Provide patterns for lightweight state management with Zustand, including store creation, async actions, slice patterns, middleware (persist, immer, devtools), selectors, computed values, and usage outside React components.

## Basic Store

```typescript
import { create } from "zustand";

interface CounterState {
  count: number;
  increment: () => void;
  decrement: () => void;
  reset: () => void;
}

export const useCounterStore = create<CounterState>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
  reset: () => set({ count: 0 }),
}));
```

## Async Actions

```typescript
interface UserState {
  user: User | null;
  isLoading: boolean;
  error: string | null;
  fetchUser: (id: string) => Promise<void>;
  updateUser: (data: Partial<User>) => Promise<void>;
  clearUser: () => void;
}

export const useUserStore = create<UserState>((set, get) => ({
  user: null,
  isLoading: false,
  error: null,

  fetchUser: async (id: string) => {
    set({ isLoading: true, error: null });
    try {
      const response = await fetch(`/api/users/${id}`);
      if (!response.ok) throw new Error("Failed to fetch");
      const user = await response.json();
      set({ user, isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  updateUser: async (data: Partial<User>) => {
    const currentUser = get().user;
    if (!currentUser) return;
    set({ isLoading: true, error: null });
    try {
      const response = await fetch(`/api/users/${currentUser.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });
      const updatedUser = await response.json();
      set({ user: updatedUser, isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  clearUser: () => set({ user: null, error: null }),
}));
```

## Slices Pattern

```typescript
import { create, type StateCreator } from "zustand";

interface AuthSlice {
  token: string | null;
  isAuthenticated: boolean;
  login: (token: string) => void;
  logout: () => void;
}

const createAuthSlice: StateCreator<AppStore, [], [], AuthSlice> = (set) => ({
  token: null,
  isAuthenticated: false,
  login: (token) => set({ token, isAuthenticated: true }),
  logout: () => set({ token: null, isAuthenticated: false }),
});

interface UserSlice {
  user: User | null;
  setUser: (user: User | null) => void;
}

const createUserSlice: StateCreator<AppStore, [], [], UserSlice> = (set) => ({
  user: null,
  setUser: (user) => set({ user }),
});

type AppStore = AuthSlice & UserSlice;

export const useAppStore = create<AppStore>()((...args) => ({
  ...createAuthSlice(...args),
  ...createUserSlice(...args),
}));
```

## Middleware

### Persist

```typescript
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

interface SettingsState {
  theme: "light" | "dark";
  language: string;
  setTheme: (theme: "light" | "dark") => void;
  setLanguage: (lang: string) => void;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      theme: "light",
      language: "en",
      setTheme: (theme) => set({ theme }),
      setLanguage: (language) => set({ language }),
    }),
    {
      name: "settings-storage",
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        theme: state.theme,
        language: state.language,
      }),
    }
  )
);
```

### Immer

```typescript
import { create } from "zustand";
import { immer } from "zustand/middleware/immer";

interface TodoState {
  todos: Todo[];
  addTodo: (text: string) => void;
  toggleTodo: (id: string) => void;
  removeTodo: (id: string) => void;
}

export const useTodoStore = create<TodoState>()(
  immer((set) => ({
    todos: [],
    addTodo: (text) =>
      set((state) => {
        state.todos.push({ id: crypto.randomUUID(), text, completed: false });
      }),
    toggleTodo: (id) =>
      set((state) => {
        const todo = state.todos.find((t) => t.id === id);
        if (todo) todo.completed = !todo.completed;
      }),
    removeTodo: (id) =>
      set((state) => {
        state.todos = state.todos.filter((t) => t.id !== id);
      }),
  }))
);
```

### Devtools

```typescript
import { create } from "zustand";
import { devtools } from "zustand/middleware";

export const useStore = create<StoreState>()(
  devtools(
    (set) => ({
      // ... state and actions
    }),
    { name: "MyStore", enabled: process.env.NODE_ENV === "development" }
  )
);
```

## Selectors and Computed Values

```typescript
import { useShallow } from "zustand/react/shallow";

// Single value selector (re-renders only when count changes)
const count = useCounterStore((state) => state.count);

// Action selector (stable reference, no re-renders)
const increment = useCounterStore((state) => state.increment);

// Multiple values with shallow comparison
const { user, isLoading } = useUserStore(
  useShallow((state) => ({ user: state.user, isLoading: state.isLoading }))
);

// Computed values as selectors
export const useCartTotal = () =>
  useCartStore((state) =>
    state.items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  );
```

## Usage Outside React

```typescript
// Read current state
const currentCount = useCounterStore.getState().count;

// Call actions imperatively
useCounterStore.getState().increment();

// Subscribe to state changes
const unsubscribe = useCounterStore.subscribe((state) => {
  console.log("Count changed:", state.count);
});
```

## Best Practices

- Always use selectors to minimize re-renders; never destructure the entire store
- Use `useShallow` when selecting multiple values to avoid unnecessary re-renders
- Keep actions inside the store, not in components
- Use the slices pattern to split large stores into maintainable pieces
- Use `persist` middleware for user preferences and settings
- Use `immer` middleware for complex nested state updates
- Enable `devtools` middleware in development for debugging
- Use `partialize` with persist to store only serializable state
- Use `get()` inside actions to read current state without stale closures
- Prefer Zustand for client state; use TanStack Query for server state
