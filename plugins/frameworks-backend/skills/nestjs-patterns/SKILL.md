---
name: nestjs-patterns
description: NestJS patterns for modules, DI, guards, pipes, and interceptors. Use when building scalable server-side applications with NestJS.
---

# NestJS Patterns

## Purpose

Provide patterns for building scalable server-side applications with NestJS, including modules, dependency injection, controllers, services, guards, pipes, interceptors, exception filters, and testing strategies.

## Module Organization

```typescript
import { Module } from "@nestjs/common";
import { UsersController } from "./users.controller";
import { UsersService } from "./users.service";
import { UsersRepository } from "./users.repository";

@Module({
  controllers: [UsersController],
  providers: [UsersService, UsersRepository],
  exports: [UsersService],
})
export class UsersModule {}
```

### App Module with Configuration

```typescript
import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { UsersModule } from "./users/users.module";
import { AuthModule } from "./auth/auth.module";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: ".env" }),
    TypeOrmModule.forRootAsync({
      useFactory: (config: ConfigService) => ({
        type: "postgres",
        url: config.get("DATABASE_URL"),
        autoLoadEntities: true,
      }),
      inject: [ConfigService],
    }),
    UsersModule,
    AuthModule,
  ],
})
export class AppModule {}
```

## Controllers

```typescript
import {
  Controller, Get, Post, Put, Delete, Body, Param,
  Query, HttpCode, HttpStatus, UseGuards, ParseUUIDPipe,
} from "@nestjs/common";
import { UsersService } from "./users.service";
import { CreateUserDto, UpdateUserDto, ListUsersQueryDto } from "./dto";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { CurrentUser } from "../auth/decorators/current-user.decorator";

@Controller("users")
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  findAll(@Query() query: ListUsersQueryDto) {
    return this.usersService.findAll(query);
  }

  @Get(":id")
  findOne(@Param("id", ParseUUIDPipe) id: string) {
    return this.usersService.findOne(id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() dto: CreateUserDto, @CurrentUser() actor: User) {
    return this.usersService.create(dto, actor);
  }

  @Put(":id")
  update(
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserDto
  ) {
    return this.usersService.update(id, dto);
  }

  @Delete(":id")
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param("id", ParseUUIDPipe) id: string) {
    return this.usersService.remove(id);
  }
}
```

## Services

```typescript
import { Injectable, NotFoundException } from "@nestjs/common";
import { UsersRepository } from "./users.repository";
import { CreateUserDto, UpdateUserDto } from "./dto";

@Injectable()
export class UsersService {
  constructor(private readonly usersRepository: UsersRepository) {}

  async findAll(query: ListUsersQueryDto) {
    return this.usersRepository.findPaginated(query);
  }

  async findOne(id: string) {
    const user = await this.usersRepository.findById(id);
    if (!user) throw new NotFoundException(`User ${id} not found`);
    return user;
  }

  async create(dto: CreateUserDto, actor: User) {
    return this.usersRepository.create({ ...dto, createdBy: actor.id });
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.findOne(id);
    return this.usersRepository.update(id, dto);
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.usersRepository.softDelete(id);
  }
}
```

## Guards

```typescript
import { Injectable, CanActivate, ExecutionContext } from "@nestjs/common";
import { Reflector } from "@nestjs/core";

export const ROLES_KEY = "roles";
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles) return true;
    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some((role) => user.roles?.includes(role));
  }
}
```

## Pipes (Validation)

```typescript
import { PipeTransform, Injectable, BadRequestException } from "@nestjs/common";
import { ZodSchema } from "zod";

@Injectable()
export class ZodValidationPipe implements PipeTransform {
  constructor(private schema: ZodSchema) {}

  transform(value: unknown) {
    const result = this.schema.safeParse(value);
    if (!result.success) {
      throw new BadRequestException(result.error.flatten());
    }
    return result.data;
  }
}

// Usage
@Post()
create(@Body(new ZodValidationPipe(createUserSchema)) dto: CreateUserDto) {
  return this.usersService.create(dto);
}
```

## Interceptors

```typescript
import {
  Injectable, NestInterceptor, ExecutionContext, CallHandler,
} from "@nestjs/common";
import { Observable, map, tap } from "rxjs";

@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<T, Response<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<Response<T>> {
    return next.handle().pipe(
      map((data) => ({
        success: true,
        data,
        timestamp: new Date().toISOString(),
      }))
    );
  }
}

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const now = Date.now();
    const req = context.switchToHttp().getRequest();
    return next.handle().pipe(
      tap(() => console.log(`${req.method} ${req.url} - ${Date.now() - now}ms`))
    );
  }
}
```

## Exception Filters

```typescript
import {
  ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus,
} from "@nestjs/common";

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? exception.getResponse()
        : "Internal server error";

    response.status(status).json({
      success: false,
      statusCode: status,
      message,
      timestamp: new Date().toISOString(),
    });
  }
}
```

## Testing

```typescript
import { Test, TestingModule } from "@nestjs/testing";
import { UsersController } from "./users.controller";
import { UsersService } from "./users.service";

describe("UsersController", () => {
  let controller: UsersController;
  let service: UsersService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: {
            findAll: vi.fn().mockResolvedValue([]),
            findOne: vi.fn().mockResolvedValue({ id: "1", name: "Test" }),
            create: vi.fn().mockResolvedValue({ id: "1", name: "New" }),
            update: vi.fn().mockResolvedValue({ id: "1", name: "Updated" }),
            remove: vi.fn().mockResolvedValue(undefined),
          },
        },
      ],
    }).compile();

    controller = module.get(UsersController);
    service = module.get(UsersService);
  });

  it("should return all users", async () => {
    const result = await controller.findAll({});
    expect(result).toEqual([]);
    expect(service.findAll).toHaveBeenCalled();
  });

  it("should create a user", async () => {
    const dto = { name: "New", email: "new@test.com" };
    const result = await controller.create(dto, mockActor);
    expect(result.name).toBe("New");
  });
});
```

## Best Practices

- Organize code into feature modules with clear boundaries
- Use constructor injection for all dependencies (services, repositories)
- Keep controllers thin; delegate business logic to services
- Use DTOs with validation for all request payloads
- Apply guards at the controller or method level for authorization
- Use interceptors for cross-cutting concerns (logging, transformation)
- Use custom exception filters for consistent error responses
- Write unit tests with mocked providers using `Test.createTestingModule`
- Use `ParseUUIDPipe` and other built-in pipes for parameter validation
- Prefer `@Injectable()` with scope `DEFAULT` (singleton) for performance
