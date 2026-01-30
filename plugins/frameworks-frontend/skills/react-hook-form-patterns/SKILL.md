# React Hook Form Patterns

## Purpose

Provide patterns for building performant forms with React Hook Form and Zod validation, including basic forms, nested objects, dynamic field arrays, controlled components with Controller, file uploads, async validation, and UI library integration.

## Basic Form with Zod

```typescript
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

const loginSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(8, "Minimum 8 characters"),
  rememberMe: z.boolean().optional(),
});

type LoginFormData = z.infer<typeof loginSchema>;

function LoginForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "", rememberMe: false },
  });

  const onSubmit = async (data: LoginFormData) => {
    await loginUser(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register("email")} aria-invalid={!!errors.email} />
      {errors.email && <span role="alert">{errors.email.message}</span>}

      <input type="password" {...register("password")} />
      {errors.password && <span role="alert">{errors.password.message}</span>}

      <label>
        <input type="checkbox" {...register("rememberMe")} />
        Remember me
      </label>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? "Logging in..." : "Log in"}
      </button>
    </form>
  );
}
```

## Nested Object Schemas

```typescript
const userSchema = z.object({
  firstName: z.string().min(1, "Required"),
  lastName: z.string().min(1, "Required"),
  address: z.object({
    street: z.string().min(1, "Required"),
    city: z.string().min(1, "Required"),
    zipCode: z.string().regex(/^\d{5}$/, "Must be 5 digits"),
  }),
});

type UserFormData = z.infer<typeof userSchema>;

function UserForm() {
  const { register, formState: { errors } } = useForm<UserFormData>({
    resolver: zodResolver(userSchema),
  });

  return (
    <form>
      <input {...register("firstName")} />
      <input {...register("address.street")} />
      <input {...register("address.city")} />
      <input {...register("address.zipCode")} />
      {errors.address?.zipCode && <span>{errors.address.zipCode.message}</span>}
    </form>
  );
}
```

## Dynamic Field Arrays

```typescript
import { useForm, useFieldArray } from "react-hook-form";

const orderSchema = z.object({
  items: z
    .array(
      z.object({
        productId: z.string().min(1, "Required"),
        quantity: z.number().min(1, "Min 1"),
        notes: z.string().optional(),
      })
    )
    .min(1, "At least one item required"),
});

type OrderFormData = z.infer<typeof orderSchema>;

function OrderForm() {
  const { control, register, handleSubmit, formState: { errors } } = useForm<OrderFormData>({
    resolver: zodResolver(orderSchema),
    defaultValues: { items: [{ productId: "", quantity: 1, notes: "" }] },
  });

  const { fields, append, remove } = useFieldArray({ control, name: "items" });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {fields.map((field, index) => (
        <div key={field.id}>
          <input {...register(`items.${index}.productId`)} />
          <input
            type="number"
            {...register(`items.${index}.quantity`, { valueAsNumber: true })}
          />
          <button type="button" onClick={() => remove(index)}>Remove</button>
          {errors.items?.[index]?.productId && (
            <span>{errors.items[index]?.productId?.message}</span>
          )}
        </div>
      ))}
      <button type="button" onClick={() => append({ productId: "", quantity: 1, notes: "" })}>
        Add Item
      </button>
      <button type="submit">Submit</button>
    </form>
  );
}
```

## Controlled Components with Controller

```typescript
import { Controller, useForm } from "react-hook-form";

const eventSchema = z.object({
  title: z.string().min(1),
  date: z.date(),
  category: z.enum(["meeting", "deadline", "reminder"]),
});

function EventForm() {
  const { control, handleSubmit } = useForm({
    resolver: zodResolver(eventSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Controller
        name="date"
        control={control}
        render={({ field, fieldState: { error } }) => (
          <DatePicker
            selected={field.value}
            onChange={field.onChange}
            error={error?.message}
          />
        )}
      />
      <Controller
        name="category"
        control={control}
        render={({ field }) => (
          <Select
            value={field.value}
            onValueChange={field.onChange}
            options={[
              { label: "Meeting", value: "meeting" },
              { label: "Deadline", value: "deadline" },
            ]}
          />
        )}
      />
    </form>
  );
}
```

## UI Library Integration (Shadcn)

```typescript
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Form, FormField, FormItem, FormLabel, FormControl, FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

function ProfileForm() {
  const form = useForm({
    resolver: zodResolver(profileSchema),
    defaultValues: { username: "", bio: "" },
  });

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="username"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Username</FormLabel>
              <FormControl>
                <Input placeholder="johndoe" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button type="submit">Save</Button>
      </form>
    </Form>
  );
}
```

## File Upload Validation

```typescript
const uploadSchema = z.object({
  title: z.string().min(1),
  file: z
    .instanceof(FileList)
    .refine((files) => files.length > 0, "File is required")
    .refine((files) => files[0]?.size <= 5 * 1024 * 1024, "Max 5MB")
    .refine(
      (files) => ["image/jpeg", "image/png"].includes(files[0]?.type),
      "Only JPEG/PNG allowed"
    ),
});

function UploadForm() {
  const { register, handleSubmit } = useForm({
    resolver: zodResolver(uploadSchema),
  });

  const onSubmit = async (data: z.infer<typeof uploadSchema>) => {
    const formData = new FormData();
    formData.append("file", data.file[0]);
    await uploadFile(formData);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register("title")} />
      <input type="file" {...register("file")} accept="image/jpeg,image/png" />
      <button type="submit">Upload</button>
    </form>
  );
}
```

## Async Validation

```typescript
function RegisterForm() {
  const form = useForm({
    resolver: zodResolver(registerSchema),
    mode: "onBlur",
  });

  const validateUsername = async (username: string) => {
    const res = await fetch(`/api/check-username?username=${username}`);
    const { available } = await res.json();
    if (!available) {
      form.setError("username", { type: "manual", message: "Username taken" });
    }
  };

  return (
    <form>
      <input
        {...form.register("username")}
        onBlur={(e) => validateUsername(e.target.value)}
      />
    </form>
  );
}
```

## Best Practices

- Define Zod schemas in separate files for reuse and unit testing
- Use `z.infer<typeof schema>` for type inference instead of manual types
- Set `mode: "onBlur"` for better UX (validate when user leaves a field)
- Use `Controller` for third-party components that don't support `ref`
- Use `useFieldArray` for dynamic arrays; never manually manage array indexes
- Always provide `defaultValues` to avoid uncontrolled-to-controlled warnings
- Show errors with `role="alert"` for accessibility
- Use `isSubmitting` to disable the submit button during async operations
- Use `valueAsNumber` for number inputs to avoid string coercion
- Compose schemas with `z.object().merge()` or `.extend()` for multi-step forms
