---
slug: gh-4-ci-workflow
state: checking            # draft | planned | implementing | checking | ready | closed | needs-decision
size: L                 # S | M | L
risk: high              # low | medium | high
plan_approved: yes      # yes cuando el usuario aprueba el plan
base: d8238cf8b4b22b07edea29ea288ba39ff907441d
candidate: eb0fcec32d685832 # hash del candidato congelado (candidate.sh)
tests: pass             # pending | pass | fail
review: approved-with-notes # pending | approved | approved-with-notes | changes-requested
corrections: 1          # máximo 1
---

# GH-4 — CI con GitHub Actions y release automática

## Objetivo
Que cada PR tenga checks que bloqueen el merge si fallan (unitarios siempre, IT en las PR a `main`),
poder lanzar los IT a mano, y que cada merge a `main` publique una release versionada (tag,
GitHub Release, imagen en GHCR) y abra la PR de la siguiente snapshot contra `develop`.
El despliegue (Kubernetes) queda para otra issue.

## Contexto
- Flujo de ramas: `feature/*` → PR a `develop` → PR `develop` → `main`. Merge commits, no squash.
- Ya existe `.github/workflows/close-issues-on-develop-merge.yml`.
- `./mvnw verify` ejecuta surefire (`*Test`) y failsafe (`*IT`, Testcontainers, necesita Docker).
  failsafe respeta `-DskipITs`.
- `pom.xml`: versión `0.0.1-SNAPSHOT`, parent `spring-boot-starter-parent` 4.1.1 (gestiona
  `versions-maven-plugin`). Aún no hay tags en el repo.
- Repo público → rulesets y GHCR disponibles sin coste. Ni `main` ni `develop` tienen protección hoy.
- Actuator ya expone `liveness`/`readiness` (útil para las probes de Kubernetes más adelante).
- Lo que un workflow crea con `GITHUB_TOKEN` no dispara otros workflows → el bot de release usa
  un token de GitHub App.

## Criterios de aceptación
- [ ] Toda PR contra `develop` o `main` ejecuta `Build and unit tests` (`./mvnw verify -DskipITs`).
- [ ] Las PR contra `main` ejecutan además `Integration tests` (`./mvnw verify` completo).
- [ ] Los IT se pueden lanzar a mano desde Actions o con `gh workflow run integration-tests.yml --ref <rama>`.
- [ ] Un test que falla pone el check en rojo y el ruleset impide mergear la PR.
- [ ] Al mergear a `main`: commit `chore(release): vX.Y.Z` con la versión del pom, tag `vX.Y.Z`,
      GitHub Release con notas e imagen `ghcr.io/frcalderon/shift-planner-backend:X.Y.Z`.
- [ ] Tras la release se abre una PR contra `develop` con `X.Y.(Z+1)-SNAPSHOT` que trae el
      historial de `main` y que ejecuta la CI.
- [ ] La versión se calcula con conventional commits desde el último tag.

## Decisiones
| Decisión | Elegido | Alternativa | Por qué |
|---|---|---|---|
| Flujo de release | Automática al mergear a `main`; el bot hace commit de la versión en `main` | Rama `release/*` estilo git-flow | Mantiene el flujo actual (PR develop→main) — decisión del usuario |
| Versionado | Conventional commits desde el último tag: `BREAKING`/`!` → major, `feat` → minor, resto → patch. Sin tags previos → versión del pom sin `-SNAPSHOT` | Patch automático + edición manual del pom | Decisión del usuario |
| Siguiente snapshot | Patch + 1 (`X.Y.(Z+1)-SNAPSHOT`), solo indicativa | Predecirla | La versión real la decide la release a partir de los commits |
| Artefacto | Imagen OCI en GHCR con buildpacks (`spring-boot:build-image-no-fork`), tag inmutable `X.Y.Z`, sin `latest` + GitHub Release solo con notas | Jar adjunto / GitHub Packages Maven | El destino es Kubernetes (autoescalado, rollouts); sin Dockerfile que mantener |
| Token del bot | GitHub App (variable `RELEASE_APP_CLIENT_ID`, secret `RELEASE_APP_PRIVATE_KEY`; `create-github-app-token@v3` usa client-id) | PAT fine-grained | Bypass del ruleset de `main` solo para el bot; token efímero — decisión del usuario |
| Disparo manual de IT | `workflow_dispatch` (+ `workflow_call` para reutilizarlo desde la CI) | Comando `/it` en comentarios de la PR | Un comentario ejecuta en el contexto de la rama por defecto y no adjunta el check a la PR; más complejo sin ganancia |
| Bloqueo de merge | Rulesets: `develop` exige PR + `Build and unit tests`; `main` exige PR + ambos checks; sin aprobaciones; no force-push ni borrado; bypass en `main` solo para la App | Branch protection clásica | Los rulesets permiten bypass por App; sin aprobaciones porque el autor no puede aprobar sus propias PR |
| Evitar bucle de release | `release.yml` se salta los commits que empiezan por `chore(release):` | — | El push del bot con token de App sí dispara workflows |

## Plan
### Fase 1 — CI e IT manuales
- Riesgo: low
- Ficheros previstos: `.github/workflows/ci.yml`, `.github/workflows/integration-tests.yml`
- Tests que la demuestran: `./mvnw -B verify -DskipITs` y `./mvnw -B verify` en local; checks en la PR de esta issue
- [x] `integration-tests.yml`: `workflow_dispatch` + `workflow_call`; Temurin 25 con caché Maven; `./mvnw -B verify`; sube los informes de failsafe/surefire si falla
- [x] `ci.yml`: `pull_request` a `develop` y `main`; job `build` (`./mvnw -B verify -DskipITs`); job `integration-tests` que llama al reutilizable solo si `github.base_ref == 'main'`; `concurrency` que cancela runs anteriores de la misma PR

### Fase 2 — Release
- Riesgo: medium
- Ficheros previstos: `.github/workflows/release.yml`, `scripts/release-version.sh`, `pom.xml` (configuración de la imagen)
- Tests que la demuestran: `scripts/release-version.sh` contra un repo git temporal con casos sin tag, `fix`, `feat`, `feat!`/`BREAKING CHANGE`; `./mvnw spring-boot:build-image-no-fork` en local
- [x] `scripts/release-version.sh`: imprime la versión de release a partir del último tag `v*` y de los commits (sin merges) desde él
- [x] `pom.xml`: `spring-boot-maven-plugin` con nombre de imagen `ghcr.io/frcalderon/shift-planner-backend:${project.version}` y etiqueta OCI `org.opencontainers.image.source`
- [x] `release.yml` en push a `main` (con la guarda `chore(release):`, `concurrency` sin cancelar): token de App → checkout con historial completo → calcular versión → `versions:set` → `./mvnw -B verify spring-boot:build-image-no-fork` → commit y tag, push a `main` → login en GHCR y push de la imagen → `gh release create --generate-notes` → rama `chore/next-snapshot-X.Y.(Z+1)` con `versions:set` a la siguiente snapshot → PR contra `develop`

### Fase 3 — Rulesets y documentación
- Riesgo: medium (cambia la configuración del repo)
- Requisito: el usuario ha creado e instalado la GitHub App y guardado los secrets (pasos en el resumen al usuario)
- Ficheros previstos: `AGENTS.md` (sección CI/Release), `scripts/gh-rulesets.sh` (rulesets como código, idempotente)
- Tests que la demuestran: los nombres de los checks se toman de la primera ejecución en la PR; PR de prueba con un test roto → merge bloqueado
- [ ] Crear los rulesets de `develop` y `main` con `gh api` (bypass en `main` para la App)
- [x] Documentar en `AGENTS.md` los workflows, el disparo manual de IT, el flujo de release y la configuración de la App

## Recibo de revisión
```
base: d8238cf8b4b22b07edea29ea288ba39ff907441d   candidate: eb0fcec32d685832   riesgo: high
tests: pass (./mvnw -B verify: 5 unit + 2 IT; actionlint (falso positivo client-id), shellcheck, release-version.sh 10+5 casos, push atómico contra remoto local)
veredicto: approved-with-notes
correcciones: 1 (token de la App aislado de Maven y no persistido, imagen antes del push, merge-only, tag semver más alto)
notas: la rama de snapshot se empuja en un segundo push no atómico (recuperación manual documentada); autor de los commits del bot = github-actions[bot] (cosmético); pendiente aplicar rulesets y validar release en GitHub tras el merge a main.
```

## Registro
- 2026-10-10 — creado; decisiones de flujo, versionado, artefacto y token tomadas con el usuario; plan escrito, pendiente de aprobación.
- 2026-10-10 — plan aprobado por el usuario; empieza la fase 1.
- 2026-10-10 — fase 1 hecha (ci.yml, integration-tests.yml); actionlint limpio, `verify -DskipITs` y `verify` en verde en local.
- 2026-10-10 — fase 2 hecha (release.yml, scripts/release-version.sh, imagen en pom); script probado con 10 casos, imagen buildpacks generada en local con la etiqueta OCI. actionlint marca un falso positivo en `create-github-app-token@v3` (`client-id`, metadatos desfasados). El workflow no se puede probar hasta tener la App y el ruleset.
- 2026-10-10 — fase 3 preparada: `scripts/gh-rulesets.sh` (probado en seco) y sección *CI y releases* en `AGENTS.md`. Falta aplicar los rulesets tras la primera ejecución en la PR. App `frcalderon-release-bot` (ID 5262413) creada e instalada; variable y secret configurados.
- 2026-10-10 — revisión 1 (riesgo high, candidato 3f0547f82a79414a): approved-with-notes. Corrección acotada aplicada a las notas: el token de la App se genera después de todos los pasos de Maven y no se persiste en `.git/config`; la imagen se publica antes del push a git; los rulesets solo permiten merge commit; `release-version.sh` toma el tag semver más alto e ignora pre-releases; documentados la visibilidad de GHCR y la recuperación manual.
- 2026-10-10 — re-revisión (candidato eb0fcec32d685832): approved-with-notes, sin bloqueantes. `verify` completo en verde. Pendiente: commit, PR, aplicar rulesets.
