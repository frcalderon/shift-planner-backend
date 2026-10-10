# shift-planner-backend

Backend del Shift Planner: planificación semanal de turnos de empleados por tienda (horarios,
asignaciones, turnos, consolidación semanal y saldo de horas). API REST para el frontend.

## Stack
- Java 25, Spring Boot 4.1.1 (Spring Framework 7, Jackson 3 — paquetes `tools.jackson`)
- Build: Maven (`./mvnw`)
- Starters: `webmvc`, `validation`, `actuator`; Lombok (versión gestionada por Boot)
- BD: PostgreSQL 18 + Flyway (migraciones en `src/main/resources/db/migration`), JPA con `ddl-auto: validate`
  y `open-in-view: false`; `docker-compose.yml` en la raíz
- Tests: JUnit 5, Spring Boot test slices, ArchUnit, Testcontainers 2.x (`postgres:18`)

## Comandos
| Acción | Comando |
|---|---|
| Compilar | `./mvnw -q compile` |
| Tests unitarios y de slice | `./mvnw test` (sin Docker) |
| Suite completa | `./mvnw verify` (requiere Docker: ejecuta los `*IT` con failsafe) |
| Levantar la BD | `docker compose up -d` (`spring-boot:run` también la levanta) |
| Arrancar en local | `./mvnw spring-boot:run` (perfil `dev` por defecto) |
| Comprobar que ha levantado | `curl http://localhost:8080/actuator/health` |
| Formatear / lint | TODO — no configurado |

## Estructura
Arquitectura hexagonal (puertos y adaptadores), paquetes por contexto de negocio:

```
com.frcalderon.shiftplanner
├── shared/{domain, infrastructure/{config, adapter/in/web}}
└── <context>/                           # store, employee, schedule, shift, balance, user...
    ├── domain/                          # modelo y excepciones de dominio — Java puro
    ├── application/
    │   ├── port/in/                     # casos de uso (interfaces) + records de comando/consulta
    │   ├── port/out/                    # puertos de repositorio / sistemas externos
    │   └── service/                     # implementación de casos de uso (@Transactional aquí)
    └── infrastructure/
        ├── adapter/in/web/              # controllers, records request/response, mappers
        ├── adapter/out/persistence/     # entidades JPA, repos Spring Data, adaptadores de puertos
        └── config/                      # wiring de beans del contexto
```

- Dependencias: `infrastructure → application → domain`. El dominio no depende de Spring, JPA
  ni Lombok. Los adaptadores de entrada no usan los de salida. Sin ciclos entre contextos.
- Estas reglas las hace cumplir `ArchitectureTest` (ArchUnit); si falla, corrige el diseño,
  no la regla.
- `shared` contiene solo lo transversal (VOs comunes, configuración, manejo global de errores).

## Convenciones propias
- `record` para DTOs, comandos, consultas y value objects. Lombok solo en infraestructura
  (p. ej. entidades JPA).
- Las entidades JPA no salen de `adapter/out/persistence`: se mapean a modelo de dominio.
- Código autodescriptivo: evita Javadoc y comentarios salvo para explicar un porqué no obvio.
  Sin `package-info.java`; los paquetes se crean con su primera clase.
- Salud de la app vía Actuator (`/actuator/health`, con `liveness`/`readiness`); no crear
  endpoints de health propios. Solo `health` está expuesto.
- Semanas ISO-8601 (`year` = año ISO de la semana, `week` 1–53); `dayOfWeek` ISO (1 = lunes).
  Horas como `"HH:mm"` ↔ `LocalTime`, granularidad de 15 min. Horas decimales `BigDecimal`
  con 2 decimales.
- Issues en GitHub (`frcalderon/shift-planner-backend`); ramas `feature/GH-<n>-<slug>`.

## Flujo de GitHub
Las issues viven en el Project "Shift Planner" (columna `Status`: Backlog → In progress → In review → Done).
El estado se consulta y cambia con `scripts/gh-issue-status.sh <issue> [<estado> [--if <estado-actual>]]`.

1. **Al empezar una issue** ("completa/haz la issue N"): `scripts/gh-issue-status.sh N "In progress" --if Backlog`.
   Si no estaba en Backlog, el script no la toca; avisa al usuario de en qué estado estaba.
2. **Al abrir la PR** (siempre contra `develop`, con `Closes #N` en la descripción):
   `scripts/gh-issue-status.sh N "In review"`.
3. **Al mergear en `develop`**: GitHub solo aplica `Closes #N` en PRs contra la rama por defecto (`main`),
   así que el workflow `.github/workflows/close-issues-on-develop-merge.yml` cierra las issues referenciadas
   (`Closes/Fixes/Resolves #N` en la descripción, o `GH-N` en el nombre de la rama). La automatización
   "Item closed" del Project la mueve a Done. No hay que hacer nada a mano.

## Tests
- Perfil `test` (`@ActiveProfiles("test")`) en los tests de Spring.
- `@WebMvcTest` está en `org.springframework.boot.webmvc.test.autoconfigure` (Boot 4).
- `ArchitectureTest`: reglas de arquitectura. `archunit.properties` tiene
  `archRule.failOnEmptyShould=false` porque aún hay paquetes vacíos.
- Integración: anota la clase con `@IntegrationTest` (`@SpringBootTest` + perfil `test` +
  `TestcontainersConfiguration`, PostgreSQL con `@ServiceConnection` y Flyway real) y nómbrala `*IT`
  para que la ejecute failsafe en `verify`. Los `*Test` (surefire) no deben necesitar BD.

## Notas
- `application.yaml` es un único fichero multi-documento con perfiles `dev` y `test`.
- Hilos virtuales activados (`spring.threads.virtual.enabled=true`): evita `synchronized`
  alrededor de I/O.
- Los avisos de Mockito/byte-buddy sobre agentes dinámicos en JDK 25 son ruido inofensivo.
- CI: TODO — issue #4.
- `.agents/` se versiona y solo contiene documentos de feature (`.agents/features/<slug>.md`).
  No guardes ahí ficheros temporales ni locales.
