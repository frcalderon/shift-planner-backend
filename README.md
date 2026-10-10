# shift-planner

Backend for planning employee shifts across stores. Built with Java 25 and Spring Boot 4.

## Running locally

Requirements: Java 25 and Docker (for the PostgreSQL database).

```bash
docker compose up -d     # start PostgreSQL
./mvnw spring-boot:run   # start the app on http://localhost:8080
./mvnw test              # run the tests
```

`./mvnw spring-boot:run` also starts the `docker-compose.yml` services automatically (and leaves them running
when the app stops), so the explicit `docker compose up -d` is optional.

Check that it is up:

```bash
curl http://localhost:8080/actuator/health
# {"status":"UP","components":{"db":{"status":"UP"},...}}
```

`/actuator/health` (with the liveness and readiness probes) is the only exposed Actuator endpoint. It reports
the `db` component (database connectivity) without details.

### Profiles

- `dev`: default profile, with debug logging for `com.frcalderon.shiftplanner`.
- `test`: used by the tests (`@ActiveProfiles("test")`), with quieter logging.

Configuration lives in a single multi-document file: `src/main/resources/application.yaml`.

### Database

PostgreSQL 18, started with `docker compose up -d` (see `docker-compose.yml`). The app connects with the
following settings, all overridable through environment variables:

| Variable | Default |
|---|---|
| `DB_HOST` | `localhost` |
| `DB_PORT` | `5432` |
| `DB_NAME` | `shiftplanner` |
| `DB_USERNAME` | `shiftplanner` |
| `DB_PASSWORD` | `shiftplanner` |

The compose service itself reads `POSTGRES_DB`, `POSTGRES_USER` and `POSTGRES_PASSWORD` (same defaults).

Schema changes are Flyway migrations in `src/main/resources/db/migration` (`V<n>__<description>.sql`), applied
automatically at startup. Hibernate runs with `ddl-auto=validate`: it never changes the schema, it only checks
that the entities match it.

The `test` profile excludes the database auto-configuration for now; Testcontainers will replace this.

## Architecture

Hexagonal architecture, organized by bounded context. Each context has its own
`domain`, `application` and `infrastructure` packages; `shared` holds what is common to all of them.

```
com.frcalderon.shiftplanner
├── ShiftPlannerApplication
├── shared/
│   ├── domain/
│   └── infrastructure/
│       ├── config/
│       └── adapter/in/web/
└── <context>/                           # store, employee, schedule, shift, balance, user...
    ├── domain/                          # model, domain exceptions — plain Java
    ├── application/
    │   ├── port/in/                     # use case interfaces + command/query records
    │   ├── port/out/                    # repository / external ports
    │   └── service/                     # use case implementations
    └── infrastructure/
        ├── adapter/in/web/              # controllers, request/response records, mappers
        ├── adapter/out/persistence/     # JPA entities, Spring Data repos, port adapters
        └── config/                      # bean wiring
```

### Dependency rule

Dependencies point inwards: `infrastructure → application → domain`.

- `domain` is plain Java: no Spring, JPA or Lombok.
- `application` depends only on `domain` and defines the ports (`port/in`, `port/out`).
  `@Transactional` lives in the application services.
- `infrastructure` implements the ports and wires everything with Spring.
- Lombok is used only in `infrastructure`.
- Use records for DTOs, commands/queries and value objects.

These rules are enforced by `ArchitectureTest` (ArchUnit), which runs with the regular tests.
