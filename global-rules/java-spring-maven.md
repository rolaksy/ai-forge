# Java / Spring / Maven Global Rules

> Derived from: KP-Xmit-LinkCentral, KP-Xmit-LinkDevice, KP-Xmit-LinkDeviceSimulator,
> KP-Xmit-LinkSimulator, KP-Xmit-VLink-2.0, KP-Library-Java-ProtocolDataMapping, KP-MapJava

---

## 0. First Steps — Always Do This Before Editing

1. Read the existing class and its neighbours before writing any code.
2. Identify which repo / module you are working in (see §1).
3. Check the root or module `pom.xml` for Java version, Spring Boot version, and
   managed dependencies before proposing any changes.
4. Never copy patterns from a different repo without confirming they match the target
   repo's Java version and Spring Boot generation.

---

## 1. Repository Map & Java Versions

| Repository | Base Package | Java | Spring Boot |
|---|---|---|---|
| `KP-Xmit-LinkCentral` | `com.kiwiplan.link.linkcentral` | 25 | 3.4.x |
| `KP-Xmit-LinkDevice` | `com.kiwiplan.linkdevice` | 25 | 3.4.x |
| `KP-Xmit-LinkDeviceSimulator` | `com.kiwiplan` | 11 | 2.7.x |
| `KP-Xmit-LinkSimulator` | `com.kiwiplan.simulator` | 11 | 2.7.x |
| `KP-Xmit-VLink-2.0` | `com.kiwiplan.vlink` | 11 | 2.7.x |
| `KP-Library-Java-ProtocolDataMapping` | `com.kiwiplan.link.datamapping` | 11 | — (library) |
| `KP-MapJava` | `com.kiwiplan` | varies (see kp-parent) | varies |

- **Jakarta vs. javax**: LinkCentral and LinkDevice (Spring Boot 3.x) use `jakarta.*`.
  LinkDeviceSimulator, LinkSimulator, VLink-2.0, and ProtocolDataMapping use `javax.*`.
  Never mix them within a module.
- **SDKMAN commands**: `sdk use java 11.0.28-ms` (for Java 11 repos),
  `sdk use java 25-ms` (for LinkCentral and LinkDevice).

---

## 2. Package & Module Structure

### Standard per-module layout (all repos)
```
src/main/java/<base-package>/
  config/          # @Configuration, @ControllerAdvice, @Bean factories, Properties
  controller/      # @RestController — thin; delegate to service immediately
  service/         # Interfaces + impl/ sub-package for implementations
  dao/             # Data-access objects (JDBI in LinkCentral; custom TCP/file in others)
  dto/             # Data-transfer objects (request/response); sub-packages by domain
  mapper/          # MapStruct interfaces or manual mapper utilities (util/ in LinkCentral)
  exception/       # Typed checked exceptions + ErrorResponse
  util/            # Stateless helper classes and @FunctionalInterface types
```

### Multi-module POMs (VLink, LinkDevice, MapJava)
- Module build order matters — respect the declared `<modules>` sequence.
- `vlink-web` must be built before `vlink-app` (web assets are copied in).
- `linkdevice-web` must be built before `linkdevice-app` (same pattern).
- When adding a module dependency, add it to the parent `pom.xml`'s
  `<dependencyManagement>` first; pin the version there only.

---

## 3. Layering & Dependency Rules

- `controller` → `service interface` → `service impl` → `dao/repository`
- `controller` must **never** import from `dao` or `mapper` directly.
- `service impl` must **never** import from `controller`.
- `config` wires implementations together; it is the only place that calls `new`
  on service / DAO classes that are not Spring-managed (see `AppServicesConfig`
  pattern in LinkCentral).
- **Cyclic imports are forbidden**, especially inside `comms/core` (LinkCentral) and
  `com.kiwiplan.linkcentral.comms.core` (KP-MapJava). Run
  `mvn dependency:analyze` when touching those packages.

---

## 4. Spring Bean & Injection Patterns

- **Constructor injection always** — never `@Autowired` on a field.
- Declare beans explicitly in a `@Configuration` class (`AppServicesConfig`,
  `AppConfig`) when the implementation is chosen at runtime (e.g., env-switch
  with `EnvContext`).
- Use `@Autowired` on the constructor of a `@Configuration` class only when
  injecting Spring-managed config beans (consistent with existing code).
- Strategy / factory patterns: register all `@Bean` strategy impls, inject them by
  list or use a `Factory` bean (`LineupStrategyFactory` pattern).
- Environment-based bean selection: use a `switch` on an enum (`EnvContext.Env`)
  inside a `@Bean` factory method, not `@ConditionalOn*` annotation, to stay
  consistent with the existing approach in `AppServicesConfig`.

---

## 5. Controller Rules

- Annotate with `@RestController` + `@RequestMapping("/api/v1")`.
- Add `@Validated` at the class level when any parameter uses JSR-303 constraints.
- Return `ResponseEntity<T>` — never return the raw DTO directly.
- Declare checked exceptions in the method signature (`throws OperationException`);
  let `AppExceptionHandler` / `@ControllerAdvice` translate them to HTTP responses.
- Validate query parameter sets explicitly when needed (see `Set.of("limit","fields")`
  pattern in `LineupController`).
- Do **not** put business logic in controllers.

---

## 6. Service Layer Rules

- Every service has an **interface** in `service/` and one or more implementations
  in `service/impl/<variant>/` (e.g., `impl/classic/`, `impl/csconlyrefresh/`).
- Service implementations are **not** `@Service`-annotated; they are constructed
  by the `@Configuration` factory bean.
- Use the `DActions<T, E extends Exception>` functional interface for deferred DB
  operations that must be wrapped in a transaction or lock (LinkCentral pattern).
- Log entry (`log.info`) and exit / result (`log.info` or `log.debug`) for every
  public service method that touches external systems.
- Non-critical side-effects (e.g., waste recording) must catch their own exceptions
  and log at `error` without propagating — never break the main flow for optional ops.

---

## 7. DAO / Data-Access Rules

- LinkCentral uses **JDBI 3** (`Jdbi`, `GenericDAO<T>`). Do not introduce JPA/Hibernate.
- Extend `GenericDAO<T>` for standard CRUD; use `fetchRecordsByMixedParams` for
  `IN`-clause queries.
- Mark DAO classes `@Transactional` at the class level (inherited from `GenericDAO`).
- SQL queries stay in the DAO class, not in services.
- VLink / LinkDevice use TCP / file-based communication layers (`ServerCoreNonBlocking`,
  `TcpListener`) — do not introduce a relational DB unless the module already has one.

---

## 8. DTO Rules

- Use `@Data` (Lombok) on DTOs — no manual getters/setters.
- Use `@JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss")`
  for all `Date` / `LocalDateTime` fields in DTOs.
- Sub-package DTOs by domain (`dto/lineup/`, `dto/wetend/`, `dto/api/lineupv3/`).
- Request DTOs: suffix `ReqDTO` or `Request`. Response DTOs: suffix `Dto`, `DTO`,
  or `ResponseDto`.
- Never return raw entity / model objects from controllers — always map to a DTO.

---

## 9. Mapping Rules

- **MapStruct** is the preferred mapper (`@Mapper(componentModel = "spring")`).
  - Always declare `INSTANCE = Mappers.getMapper(...)` for non-Spring use.
  - Use `@Mapping(target=..., source=..., qualifiedByName=...)` for complex fields.
  - Annotate complex custom conversions with `@Named`.
  - Register `lombok-mapstruct-binding` in `annotationProcessorPaths` (already in
    LinkCentral pom — verify it's present before adding a new mapper).
- Manual mappers: interface in `util/` (e.g., `LineupMapper`), implementation
  suffixed `Imp` (e.g., `LineupMapperImp`). Keep them stateless.
- MapStruct interfaces live in `mapper/`; manual interfaces live in `util/`.

---

## 10. Exception Handling Rules

- All domain exceptions extend `Exception` (checked), not `RuntimeException`.
- Every exception class must expose a `getCode()` method returning an
  `UPPER_SNAKE_CASE` string (e.g., `"MACHINE_NOT_FOUND"`).
- `AppExceptionHandler` (`@ControllerAdvice`, `@Order(HIGHEST_PRECEDENCE)`) handles
  all HTTP exception mapping — do **not** add `try/catch` in controllers.
- Return `ErrorData` from `kp-spring-helper` in all error responses; populate with
  `.withLogMessage()` and `.withParameter()` as needed.
- Never expose raw stack traces or internal messages in HTTP responses.

---

## 11. Logging Rules

- Declare loggers as: `private static final Logger log = LoggerFactory.getLogger(ClassName.class);`
  (SLF4J; resolved to Log4j2 at runtime via `log4j-slf4j-impl`).
- Never use `System.out.println` or `java.util.logging`.
- Log4j2 is the logging implementation across **all** repos — exclude
  `spring-boot-starter-logging` (Logback) in every `spring-boot-starter-*` dependency.
- Use parameterised logging: `log.info("msg {}", variable)` — never string concatenation.
- `log.debug` for diagnostic detail; `log.info` for business events; `log.error` with
  the exception object as the last argument.

---

## 12. Maven Rules

- **All dependency versions** must be declared as properties in the owning POM
  (`<spring-boot.version>`, `<log4j2.version>`, etc.) and referenced via `${...}`.
- Do not add a `<version>` tag on a dependency already managed by
  `<dependencyManagement>` or the Spring Boot BOM.
- Avoid `<scope>compile</scope>` (it is the default); use `<scope>provided</scope>`
  for Lombok.
- Always exclude `spring-boot-starter-logging` when adding any Spring Boot starter
  that would pull in Logback.
- Artifact repository: `https://pkgs.dev.azure.com/advantive-devops/Advantive/_packaging/kp.packages/maven/v1`
  — this is the source for all internal Kiwiplan libraries (`kp-spring-helper`,
  `kp-spring-security-*`, `kp-okhttp3`, `kp-measure`, `datamapping`).
- Published releases go to `http://nzartifacts/nexus/repository/kiwiplan-releases/`
  (LinkCentral); library CI publishes to `kp.packages` (ProtocolDataMapping profile `ci`).
- `maven-compiler-plugin` must declare `<annotationProcessorPaths>` containing Lombok
  and MapStruct processor when both are present; use `lombok-mapstruct-binding` to
  enforce correct processing order.

---

## 13. Kiwiplan Internal Libraries

| Artifact | Purpose | Notes |
|---|---|---|
| `kp-spring-helper` | `ErrorData`, common Spring helpers | Used in LinkCentral for error responses |
| `kp-spring-security-service-starter` | SSO service-side security | LinkCentral |
| `kp-spring-security-client-starter` | SSO client-side security | LinkCentral |
| `kp-okhttp3` | OkHttp3 wrapper | LinkCentral |
| `kp-measure` | Unit-of-measure utilities | LinkCentral |
| `datamapping` (`KP-Library-Java-ProtocolDataMapping`) | Byte-array / string protocol mapping | Used by LinkDeviceSimulator v1.4.2 |

- Do **not** replace these with open-source equivalents.
- Check the `kp.packages` feed for the latest available version before bumping.

---

## 14. Comms / Protocol Layer (VLink, LinkDevice, LinkDeviceSimulator)

- TCP communication is managed by `ServerCoreNonBlocking` / `TcpListener` in the
  `comms/core` package — do not refactor these classes without thorough review.
- MQTT integration uses `spring-integration-mqtt` (VLink) — keep message adapters
  in a dedicated `mqtt/adapter/` package.
- Protocol-specific device controllers live under `controller/<vendor>/<device-type>/`
  and are versioned by sub-package (e.g., `bhs/stacker/v2_7/`). Maintain this
  versioning when adding new protocol versions.
- GraalVM JS (`org.graalvm.js`) is used in VLink for scripting — do not remove it.
- `resilience4j` circuit-breaker and retry are used in LinkDeviceSimulator — apply
  these patterns for any new outbound HTTP calls.

---

## 15. Testing Rules

- Framework: **JUnit 5** (`@ExtendWith(MockitoExtension.class)`) across all repos.
- Use `@BeforeEach` for setup; prefer real collaborators over mocks where they are
  lightweight (see `JobServiceTest` using real `JobRepository`).
- Mock only external / IO-bound dependencies (`ApplicationContext`, HTTP clients, DAOs).
- Test class naming: `<ClassUnderTest>Test` in the same package as the source class.
- Tests must mirror the source tree: `src/test/java/<same-package>/`.
- Never weaken or delete a test to make a build pass.

---

## 16. Configuration Files

- Application config file name must match `spring.config.name` set in the main class
  (e.g., `linkcentral.yaml` loaded from `classpath:/` and `file:./kiwiplan/`).
- External config goes under `./kiwiplan/` on the deployment host — do not hard-code
  production values in classpath resources.
- Use `logback-spring.xml` for Logback (Spring Boot 2.x projects); the file must
  exist to avoid framework fallback noise.

---

## 17. API Versioning

- REST API paths are versioned: `/api/v1/...`
- When adding a new endpoint version, create a new sub-package
  (`controller/v2/`, `dto/v2/`) rather than modifying existing versioned code.
- OpenAPI / Swagger docs are provided via `springdoc-openapi` — keep
  `springdoc.properties` and/or `api.yaml` up-to-date when changing endpoints.