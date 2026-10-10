# shift-planner

Backend for planning employee shifts across stores. Built with Java 25 and Spring Boot 4.

## Running locally

Requirements: Java 25.

```bash
./mvnw spring-boot:run   # start the app on http://localhost:8080
./mvnw test              # run the tests
```

Check that it is up:

```bash
curl http://localhost:8080/actuator/health
# {"status":"UP"}
```

`/actuator/health` (with the liveness and readiness probes) is the only exposed Actuator endpoint.

### Profiles

- `dev`: default profile, with debug logging for `com.frcalderon.shiftplanner`.
- `test`: used by the tests (`@ActiveProfiles("test")`), with quieter logging.

Configuration lives in a single multi-document file: `src/main/resources/application.yaml`.

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
