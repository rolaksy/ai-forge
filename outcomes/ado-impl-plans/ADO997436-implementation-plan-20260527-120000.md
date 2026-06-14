# Implement Secure Secret Handling and Setup Wizard for KP-Xmit-LinkCentral Configuration

**ADO Work Item:** [#997436](https://dev.azure.com/advantive-devops/0e254f90-a87c-479e-abde-680deb67b476/_workitems/edit/997436)
**Date:** 2026-05-27
**Assigned To:** laks.yalamati
**Sprint:** Current
**Repository:** KP-Xmit-LinkCentral — `/home/laksyalamat/projects/KP-Xmit-LinkCentral`
**Java Version:** 25 (conservative — no virtual threads, no value types; use Java 17-compatible idioms)
**Research Doc:** [ADO997436-research-20260527-000000.md](../research/ADO997436-research-20260527-000000.md)

---

## Summary

- **Tasks:** 10
- **Files changed:** 11
- **New tests:** 3 test classes (~15 test methods)
- **Backward compatible:** Yes (additive — ENC-wrapped values are transparent to Spring)
- **Version bump required:** No

---

## Context

KP-Xmit-LinkCentral currently stores sensitive credentials in plain text: DB username/password via environment variables (`${KIWI_DB_USER}`/`${KIWI_DB_PASS}`), keystore password via `${KIWI_KS_PASS}`, and KiwiPlan comms credentials hard-coded as `remuser`/`secr8` in sample config files. This creates a security gap identified during the Advantive security remediation review.

The fix introduces two changes: (1) a **runtime Spring `EnvironmentPostProcessor`** that detects `ENC(...)` markers in `linkcentral.yaml` and decrypts them before Spring's `@Value`/`@ConfigurationProperties` bindings are resolved, and (2) a **setup wizard** (`--setup` flag) that prompts for all configuration values, encrypts sensitive ones using `com.kiwiplan.inf:kp-crypto`, and writes the result to `linkcentral.yaml`. The crypto library `kp-crypto:3.0.0` is already present in the local Maven repository; its `PublicKeyUtils` class uses embedded RSA+DES keys, requiring no external key file configuration.

---

## Data Flow

```mermaid
flowchart LR
    subgraph Setup["Setup Wizard (--setup)"]
        A[Operator prompt] -->|plaintext input| B[PublicKeyUtils.encryptString]
        B -->|byte[] → Base64| C[ENC in linkcentral.yaml]
    end

    subgraph Runtime["Spring Boot Startup"]
        C -->|file: ./kiwiplan/linkcentral.yaml| D[EncryptedPropertyDecryptionPostProcessor]
        D -->|PublicKeyUtils.decryptToString| E[Decrypted MapPropertySource]
        E -->|@Value binding| F[JdbiConfiguration]
        E -->|@ConfigurationProperties binding| G[CommsClientConfig]
        E -->|@Value binding| H[server.ssl.key-store-password]
    end

    F --> I[(MariaDB Connection Pool)]
    G --> J[CommsTrimClientProxy → MAP]
```

---

## Files Changed

| # | File | Change Type | Layer |
|---|---|---|---|
| 1 | `pom.xml` | Modify | Build |
| 2 | `src/main/java/com/kiwiplan/link/linkcentral/config/EncryptedPropertyDecryptionPostProcessor.java` | Add | Config / Infrastructure |
| 3 | `src/main/resources/META-INF/spring/org.springframework.boot.env.EnvironmentPostProcessor` | Add | Spring Registration |
| 4 | `src/main/java/com/kiwiplan/link/linkcentral/setup/SetupWizard.java` | Add | Setup Utility |
| 5 | `src/main/java/com/kiwiplan/link/linkcentral/LinkCentralApplication.java` | Modify | Application Entry Point |
| 6 | `src/main/resources/sample/linkcentral.yaml-opal-bhs` | Modify | Config Sample |
| 7 | `src/main/resources/sample/linkcentral.yaml-gopfert-stora` | Modify | Config Sample |
| 8 | `src/main/resources/sample/linkcentral.yaml-para` | Modify | Config Sample |
| 9 | `src/test/java/com/kiwiplan/link/linkcentral/config/EncryptedPropertyDecryptionPostProcessorTest.java` | Add | Test |
| 10 | `src/test/java/com/kiwiplan/link/linkcentral/setup/SetupWizardTest.java` | Add | Test |
| 11 | `README.md` | Modify | Documentation |

---

## Tasks

### Task 1 — Add `kp-crypto` dependency to `pom.xml`

**File:** `pom.xml`
**Change type:** Modify

#### What to change

Add `com.kiwiplan.inf:kp-crypto:3.0.0` as a compile-scoped dependency in the Kiwiplan dependency block (after the existing `kp-measure` entry). Also add a `<kp-crypto.version>` property alongside the other Kiwiplan version properties.

#### Why

`PublicKeyUtils.encryptString()` and `PublicKeyUtils.decryptToString()` are needed by both the setup wizard and the runtime `EnvironmentPostProcessor`. The artifact is already present in the local Maven repository at `com/kiwiplan/inf/kp-crypto/3.0.0/`.

#### Code

```xml
<!-- In <properties> block, alongside other kp version properties -->
<kp-crypto.version>3.0.0</kp-crypto.version>
```

```xml
<!-- In <dependencies> block, after kp-measure -->
<!-- Kiwiplan cryptography -->
<dependency>
  <groupId>com.kiwiplan.inf</groupId>
  <artifactId>kp-crypto</artifactId>
  <version>${kp-crypto.version}</version>
</dependency>
```

#### Notes

- No scope qualifier needed (used in both `main` and test code).
- The library has embedded RSA+DES keys — no key file configuration required at runtime.
- Verify: `mvn dependency:resolve -Dartifact=com.kiwiplan.inf:kp-crypto:3.0.0` resolves cleanly.

---

### Task 2 — Create `EncryptedPropertyDecryptionPostProcessor`

**File:** `src/main/java/com/kiwiplan/link/linkcentral/config/EncryptedPropertyDecryptionPostProcessor.java`
**Change type:** Add

#### What to change

Create a new `EnvironmentPostProcessor` that scans all `PropertySource` entries for values matching the pattern `ENC(<base64>)`, decrypts them using `PublicKeyUtils.decryptToString()`, and injects the decrypted values into the `Environment` as a highest-priority `MapPropertySource` named `decryptedProperties`.

#### Why

`@Value` and `@ConfigurationProperties` bindings are resolved after the `Environment` is fully populated. Using an `EnvironmentPostProcessor` is the correct Spring Boot extension point — it runs before any bean is created, ensuring beans such as `JdbiConfiguration` and `CommsClientConfig` receive the plain-text values without any code changes to those classes.

#### Code

```java
package com.kiwiplan.link.linkcentral.config;

import com.kiwiplan.crypto.PublicKeyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.MutablePropertySources;
import org.springframework.core.env.PropertySource;

import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

/**
 * Decrypts ENC(...) property values in the Spring Environment before bean creation.
 * Encrypted values are stored as: ENC(<Base64-encoded-encrypted-bytes>)
 * Encryption is performed by the setup wizard using PublicKeyUtils.encryptString().
 */
public class EncryptedPropertyDecryptionPostProcessor implements EnvironmentPostProcessor {

    private static final Logger logger = LoggerFactory.getLogger(EncryptedPropertyDecryptionPostProcessor.class);
    private static final String ENC_PREFIX = "ENC(";
    private static final String ENC_SUFFIX = ")";
    private static final String DECRYPTED_SOURCE_NAME = "decryptedProperties";

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        Map<String, Object> decryptedValues = new HashMap<>();
        MutablePropertySources propertySources = environment.getPropertySources();

        for (PropertySource<?> propertySource : propertySources) {
            if (!(propertySource.getSource() instanceof Map)) {
                continue;
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> source = (Map<String, Object>) propertySource.getSource();
            for (Map.Entry<String, Object> entry : source.entrySet()) {
                String key = entry.getKey();
                Object rawValue = entry.getValue();
                if (rawValue instanceof String value && isEncrypted(value)) {
                    String decrypted = decrypt(key, value);
                    if (decrypted != null) {
                        decryptedValues.put(key, decrypted);
                    }
                }
            }
        }

        if (!decryptedValues.isEmpty()) {
            propertySources.addFirst(new MapPropertySource(DECRYPTED_SOURCE_NAME, decryptedValues));
            logger.info("Decrypted {} encrypted configuration properties", decryptedValues.size());
        }
    }

    static boolean isEncrypted(String value) {
        return value != null && value.startsWith(ENC_PREFIX) && value.endsWith(ENC_SUFFIX);
    }

    static String extractBase64(String encValue) {
        return encValue.substring(ENC_PREFIX.length(), encValue.length() - ENC_SUFFIX.length());
    }

    private String decrypt(String key, String encValue) {
        try {
            byte[] encryptedBytes = Base64.getDecoder().decode(extractBase64(encValue));
            return PublicKeyUtils.decryptToString(encryptedBytes);
        } catch (Exception e) {
            // Log property name but never the value — the value is a credential.
            logger.error("Failed to decrypt property '{}'. Verify the value was encrypted with the setup wizard.", key, e);
            return null;
        }
    }
}
```

#### Notes

- **Pattern instanceof with type binding** (`rawValue instanceof String value`) requires Java 16+; this project targets Java 25 — acceptable.
- **Do not log the encrypted or decrypted values** — they are credentials.
- Only `PropertySource` entries whose source is a `Map` are scanned (covers `application.yml`/`linkcentral.yaml` loaded sources). Origin-tracked or non-map sources (e.g., system environment, system properties) are intentionally skipped.
- If decryption fails, the property is left undecrypted and Spring will likely fail during `@NotNull` validation on `CommsClientConfig` — this is the desired fail-fast behavior.
- The `addFirst()` call gives decrypted values highest priority, overriding any raw `ENC(...)` value from lower-priority sources.

---

### Task 3 — Register the `EnvironmentPostProcessor`

**File:** `src/main/resources/META-INF/spring/org.springframework.boot.env.EnvironmentPostProcessor`
**Change type:** Add

#### What to change

Create the registration file at the path above with one line: the fully-qualified class name of the post-processor. This is the Spring Boot 2.7+ / 3.x mechanism (replaces `spring.factories`).

#### Why

Without registration, Spring Boot will not discover and invoke the `EnvironmentPostProcessor`.

#### Code

```
com.kiwiplan.link.linkcentral.config.EncryptedPropertyDecryptionPostProcessor
```

(File contains exactly this one line — no blank lines, no comments needed.)

#### Notes

- The directory `src/main/resources/META-INF/spring/` needs to be created (it does not currently exist).
- Do **not** use `spring.factories` — Spring Boot 3.x warns when it is used; the named-file mechanism is the standard since 2.7.
- If other `EnvironmentPostProcessor` registrations are added in the future, add them on additional lines in this same file.

---

### Task 4 — Create `SetupWizard`

**File:** `src/main/java/com/kiwiplan/link/linkcentral/setup/SetupWizard.java`
**Change type:** Add

#### What to change

Create a standalone wizard class in a new `setup` package. It reads the existing `./kiwiplan/linkcentral.yaml` (or a specified path), prompts the operator for all required values, encrypts sensitive fields, and writes the result back. Must handle the case where the file does not yet exist (first install).

#### Why

Satisfies AC #1–4 (wizard prompts, AC #3/4 sensitive values not written in plain text) and AC #7 (re-runnable).

#### Code

```java
package com.kiwiplan.link.linkcentral.setup;

import com.kiwiplan.crypto.PublicKeyUtils;
import org.yaml.snakeyaml.DumperOptions;
import org.yaml.snakeyaml.Yaml;

import java.io.IOException;
import java.io.InputStream;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Scanner;

/**
 * Interactive setup wizard for LinkCentral configuration.
 * Run with: java -jar linkcentral.jar --setup
 * Or with a custom path: java -jar linkcentral.jar --setup --config-path=/path/to/linkcentral.yaml
 *
 * Prompts for all required values, encrypts sensitive fields using kp-crypto,
 * and writes ENC(...) wrapped values to linkcentral.yaml.
 * Safe to re-run — backs up the existing file before overwriting.
 */
public class SetupWizard {

    static final String ENC_FORMAT = "ENC(%s)";
    private static final Path DEFAULT_CONFIG_PATH = Paths.get("kiwiplan", "linkcentral.yaml");

    private final Scanner scanner;
    private final Path configPath;

    public SetupWizard(Scanner scanner, Path configPath) {
        this.scanner = scanner;
        this.configPath = configPath;
    }

    /**
     * Entry point called from LinkCentralApplication when --setup is detected.
     */
    public static void run(String[] args) {
        Path configPath = resolveConfigPath(args);
        System.out.println("=== LinkCentral Setup Wizard ===");
        System.out.println("Configuration file: " + configPath.toAbsolutePath());

        try (Scanner scanner = new Scanner(System.in)) {
            new SetupWizard(scanner, configPath).execute();
        } catch (Exception e) {
            System.err.println("Setup failed: " + e.getMessage());
            System.exit(1);
        }
    }

    void execute() throws Exception {
        Map<String, Object> config = loadExistingOrEmpty();

        System.out.println("\n-- Database Settings --");
        String dbHost    = prompt("DB host", "localhost");
        String dbPort    = prompt("DB port", "3306");
        String dbUser    = promptSensitive("DB username");
        String dbPass    = promptSensitive("DB password");
        String classicDb = prompt("Classic DB name", "app_map");
        String manDb     = prompt("Manufacturing DB name (leave blank to skip)", "");
        String cscDb     = prompt("CSC DB name (leave blank to skip)", "");

        System.out.println("\n-- Comms Settings --");
        String commsHost = prompt("Comms server host", "localhost");
        String commsPort = prompt("Comms server port", "30125");
        String commsUser = promptSensitive("Comms username");
        String commsPass = promptSensitive("Comms password");

        System.out.println("\n-- SSL / Keystore Settings --");
        String ksPath = prompt("Keystore file path", "/etc/kiwiplan/linkcentral.p12");
        String ksPass = promptSensitive("Keystore password");

        applyValues(config, dbHost, dbPort, dbUser, dbPass, classicDb, manDb, cscDb,
                commsHost, commsPort, commsUser, commsPass, ksPath, ksPass);

        backupExisting();
        writeConfig(config);
        System.out.println("\nConfiguration written to: " + configPath.toAbsolutePath());
        System.out.println("Setup complete. Start LinkCentral normally: java -jar linkcentral.jar");
    }

    @SuppressWarnings("unchecked")
    void applyValues(Map<String, Object> config,
                     String dbHost, String dbPort, String dbUser, String dbPass,
                     String classicDb, String manDb, String cscDb,
                     String commsHost, String commsPort, String commsUser, String commsPass,
                     String ksPath, String ksPass) throws Exception {

        // spring.datasource
        Map<String, Object> spring = (Map<String, Object>) config.computeIfAbsent("spring", k -> new LinkedHashMap<>());
        Map<String, Object> datasource = (Map<String, Object>) spring.computeIfAbsent("datasource", k -> new LinkedHashMap<>());
        datasource.put("driver-class-name", "org.mariadb.jdbc.Driver");
        datasource.put("username", encrypt(dbUser));
        datasource.put("password", encrypt(dbPass));

        // spring.classic.url
        Map<String, Object> classic = (Map<String, Object>) spring.computeIfAbsent("classic", k -> new LinkedHashMap<>());
        classic.put("url", buildJdbcUrl(dbHost, dbPort, classicDb));

        // spring.man.url (optional)
        if (!manDb.isBlank()) {
            Map<String, Object> man = (Map<String, Object>) spring.computeIfAbsent("man", k -> new LinkedHashMap<>());
            man.put("url", buildJdbcUrl(dbHost, dbPort, manDb));
        }

        // spring.csc.url (optional)
        if (!cscDb.isBlank()) {
            Map<String, Object> csc = (Map<String, Object>) spring.computeIfAbsent("csc", k -> new LinkedHashMap<>());
            csc.put("url", buildJdbcUrl(dbHost, dbPort, cscDb));
        }

        // kiwiplan.comms
        Map<String, Object> kiwiplan = (Map<String, Object>) config.computeIfAbsent("kiwiplan", k -> new LinkedHashMap<>());
        Map<String, Object> comms = (Map<String, Object>) kiwiplan.computeIfAbsent("comms", k -> new LinkedHashMap<>());
        comms.put("server", commsHost);
        comms.put("port", Integer.parseInt(commsPort));
        comms.put("username", encrypt(commsUser));
        comms.put("password", encrypt(commsPass));
        comms.put("application-name", "linkcentral");
        comms.put("connection-timeout", 20000);
        comms.put("read-timeout", 60000);

        // server.ssl
        Map<String, Object> server = (Map<String, Object>) config.computeIfAbsent("server", k -> new LinkedHashMap<>());
        Map<String, Object> ssl = (Map<String, Object>) server.computeIfAbsent("ssl", k -> new LinkedHashMap<>());
        ssl.put("key-store-type", "PKCS12");
        ssl.put("key-store", ksPath);
        ssl.put("key-store-password", encrypt(ksPass));
        ssl.put("key-alias", "kiwitls");
    }

    static String encrypt(String plaintext) throws Exception {
        byte[] encryptedBytes = PublicKeyUtils.encryptString(plaintext);
        return String.format(ENC_FORMAT, Base64.getEncoder().encodeToString(encryptedBytes));
    }

    private static String buildJdbcUrl(String host, String port, String dbName) {
        return "jdbc:mariadb://" + host + ":" + port + "/" + dbName + "?characterEncoding=UTF-8";
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> loadExistingOrEmpty() throws IOException {
        if (Files.exists(configPath)) {
            System.out.println("Existing configuration found — values shown in [brackets] are current defaults.");
            Yaml yaml = new Yaml();
            try (InputStream is = Files.newInputStream(configPath)) {
                Map<String, Object> loaded = yaml.load(is);
                return loaded != null ? loaded : new LinkedHashMap<>();
            }
        }
        return new LinkedHashMap<>();
    }

    private void backupExisting() throws IOException {
        if (Files.exists(configPath)) {
            Path backup = configPath.resolveSibling(configPath.getFileName() + ".bak");
            Files.copy(configPath, backup, StandardCopyOption.REPLACE_EXISTING);
            System.out.println("Backup written to: " + backup.toAbsolutePath());
        }
    }

    private void writeConfig(Map<String, Object> config) throws IOException {
        Files.createDirectories(configPath.getParent());
        DumperOptions options = new DumperOptions();
        options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK);
        options.setIndent(2);
        options.setPrettyFlow(true);
        Yaml yaml = new Yaml(options);
        try (Writer writer = Files.newBufferedWriter(configPath)) {
            yaml.dump(config, writer);
        }
    }

    String prompt(String label, String defaultValue) {
        if (defaultValue.isBlank()) {
            System.out.print(label + " (optional, press Enter to skip): ");
        } else {
            System.out.print(label + " [" + defaultValue + "]: ");
        }
        String input = scanner.nextLine().trim();
        return input.isEmpty() ? defaultValue : input;
    }

    String promptSensitive(String label) {
        System.out.print(label + ": ");
        String value = scanner.nextLine().trim();
        if (value.isEmpty()) {
            throw new IllegalArgumentException(label + " cannot be empty.");
        }
        return value;
    }

    private static Path resolveConfigPath(String[] args) {
        for (String arg : args) {
            if (arg.startsWith("--config-path=")) {
                return Paths.get(arg.substring("--config-path=".length()));
            }
        }
        return DEFAULT_CONFIG_PATH;
    }
}
```

#### Notes

- **Do not echo passwords** to the terminal. The `promptSensitive` method reads from `Scanner` (System.in). For a production-grade wizard, consider `System.console().readPassword()` to suppress echo if running in a real terminal (wrap with null check — `System.console()` is null in some CI/test environments).
- **Sensitive fields must not be logged** by the wizard. No `System.out.println` of the plain-text values.
- The `encrypt()` method is `static` and package-visible to allow direct unit-testing without mocking `PublicKeyUtils`.
- `SnakeYAML` strips comments from the YAML on round-trip — this is expected. The sample files with comments remain intact (they are not rewritten by the wizard).
- `Integer.parseInt(commsPort)` is intentionally strict — the wizard should abort if a non-numeric port is entered. This is handled by `run()` catching `Exception` and printing the error.
- For sites without comms (no MAP integration), an empty comms username/password will be rejected by `promptSensitive`. If the site genuinely has no comms, a follow-up story should add an optional comms section flag. Out of scope here.

---

### Task 5 — Add `--setup` dispatch to `LinkCentralApplication`

**File:** `src/main/java/com/kiwiplan/link/linkcentral/LinkCentralApplication.java`
**Change type:** Modify

#### What to change

Add a check at the top of `main()`: if `--setup` is present in `args`, invoke `SetupWizard.run(args)` and return immediately (do not start Spring). Otherwise, proceed with the existing `SpringApplicationBuilder` startup.

#### Why

Satisfies AC #1 (wizard is implemented and invocable) and AC #7 (runnable independently of the Spring context, safe to re-run). Running the wizard before Spring starts avoids loading an encrypted-but-undecrypted config during wizard invocation.

#### Code

```java
// Before (current main method):
public static void main(String[] args) {
    Map<String, Object> props = new HashMap<>();
    props.put("spring.config.name", "linkcentral");
    props.put("spring.config.location", "classpath:/,file:./kiwiplan/");

    new SpringApplicationBuilder(LinkCentralApplication.class)
        .properties(props)
        .build()
        .run(args);
}

// After:
public static void main(String[] args) {
    for (String arg : args) {
        if ("--setup".equals(arg)) {
            SetupWizard.run(args);
            return;
        }
    }

    Map<String, Object> props = new HashMap<>();
    props.put("spring.config.name", "linkcentral");
    props.put("spring.config.location", "classpath:/,file:./kiwiplan/");

    new SpringApplicationBuilder(LinkCentralApplication.class)
        .properties(props)
        .build()
        .run(args);
}
```

Add the import:
```java
import com.kiwiplan.link.linkcentral.setup.SetupWizard;
```

#### Notes

- The `--setup` check uses a simple linear scan — no third-party argument parser needed.
- Spring's own `--` argument handling does not conflict because Spring processes args only after `SpringApplicationBuilder.run()` is called.
- If `--setup` and other Spring args are mixed (e.g., `--setup --spring.profiles.active=dev`), Spring args are ignored during setup — this is correct behavior.

---

### Task 6 — Update `linkcentral.yaml-opal-bhs` sample

**File:** `src/main/resources/sample/linkcentral.yaml-opal-bhs`
**Change type:** Modify

#### What to change

Replace the hard-coded plain-text comms credentials with `ENC(PLACEHOLDER)` markers and add an instructional comment above the `kiwiplan.comms` section. Also remove the plain-text `username`/`password` env var defaults in the `datasource` block (replace with `ENC(PLACEHOLDER)`) and remove the env var for `key-store-password`.

#### Why

AC #12: Legacy hard-coded credentials `remuser`/`secr8` must be removed from sample configs. AC #3/4: Sensitive values must not appear in plain text.

#### Code

Replace in the `kiwiplan.comms` section:
```yaml
# BEFORE:
  comms:
    server: localhost
    port: 30125
    username: remuser
    password: secr8
    application-name: linkcentral
    connection-timeout: 20000
    read-timeout: 60000

# AFTER — run 'java -jar linkcentral.jar --setup' to generate encrypted values:
  comms:
    server: localhost
    port: 30125
    # Run: java -jar linkcentral.jar --setup  to populate these with encrypted values
    username: ENC(PLACEHOLDER)
    password: ENC(PLACEHOLDER)
    application-name: linkcentral
    connection-timeout: 20000
    read-timeout: 60000
```

Replace in the `spring.datasource` section:
```yaml
# BEFORE:
    username: ${KIWI_DB_USER:test}
    password: ${KIWI_DB_PASS:test}

# AFTER:
    # Run: java -jar linkcentral.jar --setup  to populate these with encrypted values
    username: ENC(PLACEHOLDER)
    password: ENC(PLACEHOLDER)
```

Replace `key-store-password`:
```yaml
# BEFORE:
    key-store-password: ${KIWI_KS_PASS}

# AFTER:
    # Run: java -jar linkcentral.jar --setup  to populate this with an encrypted value
    key-store-password: ENC(PLACEHOLDER)
```

#### Notes

- `ENC(PLACEHOLDER)` is intentionally not a valid Base64 value — if someone tries to start LinkCentral with this unmodified sample, the post-processor will log a decryption error and Spring will fail on `@NotNull` validation, giving a clear signal that the wizard must be run first. This is the desired fail-fast behavior.
- `${KIWI_DB_HOST}`, `${KIWI_DB_PORT}`, `${KIWI_CLASSIC_DB}` URL references may remain as-is in this sample (non-sensitive).
- Do not commit a sample with real credentials.

---

### Task 7 — Update `linkcentral.yaml-gopfert-stora` sample

**File:** `src/main/resources/sample/linkcentral.yaml-gopfert-stora`
**Change type:** Modify

#### What to change

Replace the env-var references for sensitive credentials (`${KIWI_COMMS_USER}`, `${KIWI_COMMS_PASS}`, `${KIWI_DB_USER}`, `${KIWI_DB_PASS}`, `${KIWI_KS_PASS}`) with `ENC(PLACEHOLDER)` markers and instructional comments.

#### Why

The env-var approach still stores credentials in plain text at the OS level (shell profile, systemd unit file). The new approach replaces them with `ENC(...)` values generated by the wizard, so env var injection for credentials is no longer required.

#### Code

```yaml
# BEFORE (datasource):
    username: ${KIWI_DB_USER}
    password: ${KIWI_DB_PASS}

# AFTER:
    # Run: java -jar linkcentral.jar --setup  to populate these with encrypted values
    username: ENC(PLACEHOLDER)
    password: ENC(PLACEHOLDER)
```

```yaml
# BEFORE (comms):
    username: ${KIWI_COMMS_USER}
    password: ${KIWI_COMMS_PASS}

# AFTER:
    # Run: java -jar linkcentral.jar --setup  to populate these with encrypted values
    username: ENC(PLACEHOLDER)
    password: ENC(PLACEHOLDER)
```

```yaml
# BEFORE (ssl):
    key-store-password: ${KIWI_KS_PASS}

# AFTER:
    # Run: java -jar linkcentral.jar --setup  to populate this with an encrypted value
    key-store-password: ENC(PLACEHOLDER)
```

#### Notes

- Non-sensitive env vars (`${KIWI_DB_HOST}`, `${KIWI_DB_PORT}`, `${KIWI_CLASSIC_DB}`, `${KIWI_MAN_DB}`, `${KIWI_CSC_DB}`, `${KIWI_COMMS_HOST}`, `${KIWI_COMMS_PORT}`, `${KIWI_KS_PATH}`) remain as env-var references or can be replaced with concrete values by the wizard.
- The gopfert-stora sample references `${KIWI_MES_HOST}` / `${KIWI_MES_PORT}` — these are not credentials; leave them unchanged.

---

### Task 8 — Update `linkcentral.yaml-para` sample

**File:** `src/main/resources/sample/linkcentral.yaml-para`
**Change type:** Modify

#### What to change

This sample has no `kiwiplan.comms` section (para site is comms-only via the `server.ssl` + datasource path). Replace the sensitive env-var references in `datasource` and `server.ssl` sections with `ENC(PLACEHOLDER)` markers. Add a `kiwiplan.comms` section with `ENC(PLACEHOLDER)` credentials (the para site may not use comms but the wizard will prompt — operators can skip by noting N/A in the wizard; the section should exist in the sample for completeness).

Actually — review: if the para site has no comms, forcing a comms section into its sample may be misleading. Instead, **only** replace the datasource and SSL credentials with `ENC(PLACEHOLDER)` and add a comment about the wizard. Leave the comms section absent (consistent with the existing file structure for that site).

#### Code

```yaml
# BEFORE (datasource):
    username: ${KIWI_DB_USER}
    password: ${KIWI_DB_PASS}

# AFTER:
    # Run: java -jar linkcentral.jar --setup  to populate these with encrypted values
    username: ENC(PLACEHOLDER)
    password: ENC(PLACEHOLDER)
```

```yaml
# BEFORE (ssl):
    key-store-password: ${KIWI_KS_PASS}

# AFTER:
    # Run: java -jar linkcentral.jar --setup  to populate this with an encrypted value
    key-store-password: ENC(PLACEHOLDER)
```

#### Notes

- The para sample has no `kiwiplan.comms` section. Do not add one. The wizard will still prompt for comms credentials during setup; if the para site has no comms, the operator can enter placeholder values and skip comms-related startup (or the comms bean will fail to connect — existing behavior).
- `${KIWI_DB_HOST}`, `${KIWI_DB_PORT}`, `${KIWI_CLASSIC_DB}` in the datasource URL remain unchanged.

---

### Task 9 — Add `EncryptedPropertyDecryptionPostProcessorTest`

**File:** `src/test/java/com/kiwiplan/link/linkcentral/config/EncryptedPropertyDecryptionPostProcessorTest.java`
**Change type:** Add

#### What to change

Unit-test the `EncryptedPropertyDecryptionPostProcessor` in isolation — no Spring context needed. Test: (a) `isEncrypted()` pattern matching, (b) `extractBase64()` extraction, (c) `postProcessEnvironment()` with a mock `MapPropertySource` containing a real `ENC(...)` value.

#### Why

Ensures the decryption logic is correct, the ENC pattern is correctly detected, and the `MapPropertySource` injection occurs before property binding.

#### Code

```java
package com.kiwiplan.link.linkcentral.config;

import com.kiwiplan.crypto.PublicKeyUtils;
import org.junit.jupiter.api.Test;
import org.springframework.boot.SpringApplication;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.MutablePropertySources;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.mock.env.MockEnvironment;

import java.util.Base64;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class EncryptedPropertyDecryptionPostProcessorTest {

    private final EncryptedPropertyDecryptionPostProcessor processor =
            new EncryptedPropertyDecryptionPostProcessor();

    @Test
    void isEncrypted_returnsTrue_forValidEncFormat() {
        assertTrue(EncryptedPropertyDecryptionPostProcessor.isEncrypted("ENC(abc123==)"));
    }

    @Test
    void isEncrypted_returnsFalse_forPlainText() {
        assertFalse(EncryptedPropertyDecryptionPostProcessor.isEncrypted("plaintext"));
        assertFalse(EncryptedPropertyDecryptionPostProcessor.isEncrypted(null));
        assertFalse(EncryptedPropertyDecryptionPostProcessor.isEncrypted("ENC(noClosure"));
    }

    @Test
    void extractBase64_returnsInnerContent() {
        assertEquals("abc123==", EncryptedPropertyDecryptionPostProcessor.extractBase64("ENC(abc123==)"));
    }

    @Test
    void postProcessEnvironment_decryptsEncValue_andInjectsDecryptedPropertySource() throws Exception {
        // Encrypt a real value using the actual library
        String plaintext = "testpassword";
        byte[] encrypted = PublicKeyUtils.encryptString(plaintext);
        String encValue = "ENC(" + Base64.getEncoder().encodeToString(encrypted) + ")";

        MockEnvironment environment = new MockEnvironment();
        environment.setProperty("spring.datasource.password", encValue);

        processor.postProcessEnvironment(environment, new SpringApplication());

        // The decrypted value should be first in the property sources
        assertEquals(plaintext, environment.getProperty("spring.datasource.password"));
    }

    @Test
    void postProcessEnvironment_leavesNonEncryptedValues_unchanged() {
        MockEnvironment environment = new MockEnvironment();
        environment.setProperty("server.port", "8444");

        processor.postProcessEnvironment(environment, new SpringApplication());

        assertEquals("8444", environment.getProperty("server.port"));
    }
}
```

#### Notes

- `MockEnvironment` is part of `spring-test` which is already on the classpath via `spring-boot-starter-test`.
- The test uses a **real** `PublicKeyUtils.encryptString()` call — this verifies the full encrypt/decrypt round-trip without mocking the crypto library. This is the correct approach per the testing guidelines (prefer real objects over mocks for integration-like tests).
- `postProcessEnvironment_decryptsEncValue` implicitly validates that `kp-crypto` is correctly wired as a Maven dependency (Task 1).

---

### Task 10 — Add `SetupWizardTest`

**File:** `src/test/java/com/kiwiplan/link/linkcentral/setup/SetupWizardTest.java`
**Change type:** Add

#### What to change

Unit-test `SetupWizard` focusing on: (a) `encrypt()` produces a correct `ENC(...)` value that round-trips, (b) `applyValues()` sets nested map keys correctly, (c) `promptSensitive()` throws on empty input.

#### Why

Ensures the wizard correctly constructs the YAML structure and that credentials are stored as `ENC(...)` — not plain text — before the file is written.

#### Code

```java
package com.kiwiplan.link.linkcentral.setup;

import com.kiwiplan.crypto.PublicKeyUtils;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Scanner;

import static org.junit.jupiter.api.Assertions.*;

class SetupWizardTest {

    @TempDir
    Path tempDir;

    @Test
    void encrypt_producesEncWrappedValue_thatDecryptsToOriginal() throws Exception {
        String plaintext = "mypassword123";
        String enc = SetupWizard.encrypt(plaintext);

        assertTrue(enc.startsWith("ENC("), "Should start with ENC(");
        assertTrue(enc.endsWith(")"), "Should end with )");

        // Round-trip verify
        String inner = enc.substring(4, enc.length() - 1);
        byte[] encBytes = Base64.getDecoder().decode(inner);
        String decrypted = PublicKeyUtils.decryptToString(encBytes);
        assertEquals(plaintext, decrypted);
    }

    @Test
    @SuppressWarnings("unchecked")
    void applyValues_setsEncryptedCredentials_inNestedMap() throws Exception {
        Path configPath = tempDir.resolve("linkcentral.yaml");
        SetupWizard wizard = new SetupWizard(new Scanner(System.in), configPath);
        Map<String, Object> config = new LinkedHashMap<>();

        wizard.applyValues(config,
                "localhost", "3306", "dbuser", "dbpass",
                "app_map", "", "",
                "localhost", "30125", "remuser", "secr8",
                "/etc/kiwi/keystore.p12", "kspass");

        Map<String, Object> spring = (Map<String, Object>) config.get("spring");
        Map<String, Object> datasource = (Map<String, Object>) spring.get("datasource");
        String usernameEnc = (String) datasource.get("username");
        String passwordEnc = (String) datasource.get("password");

        // Must be ENC(...) — not plain text
        assertTrue(usernameEnc.startsWith("ENC("), "DB username must be encrypted");
        assertTrue(passwordEnc.startsWith("ENC("), "DB password must be encrypted");

        // Must NOT contain plain-text values
        assertFalse(usernameEnc.contains("dbuser"), "Plain-text username must not appear in ENC value");
        assertFalse(passwordEnc.contains("dbpass"), "Plain-text password must not appear in ENC value");

        // Verify comms
        Map<String, Object> kiwiplan = (Map<String, Object>) config.get("kiwiplan");
        Map<String, Object> comms = (Map<String, Object>) kiwiplan.get("comms");
        assertTrue(((String) comms.get("username")).startsWith("ENC("));
        assertTrue(((String) comms.get("password")).startsWith("ENC("));

        // Verify SSL keystore
        Map<String, Object> server = (Map<String, Object>) config.get("server");
        Map<String, Object> ssl = (Map<String, Object>) server.get("ssl");
        assertEquals("/etc/kiwi/keystore.p12", ssl.get("key-store"));
        assertTrue(((String) ssl.get("key-store-password")).startsWith("ENC("));
    }

    @Test
    void promptSensitive_throwsIllegalArgument_whenInputIsEmpty() {
        String emptyInput = "\n";
        Scanner scanner = new Scanner(new ByteArrayInputStream(emptyInput.getBytes(StandardCharsets.UTF_8)));
        Path configPath = tempDir.resolve("linkcentral.yaml");
        SetupWizard wizard = new SetupWizard(scanner, configPath);

        assertThrows(IllegalArgumentException.class, () -> wizard.promptSensitive("DB password"));
    }
}
```

#### Notes

- `@TempDir` avoids filesystem side effects — the wizard writes/reads from the temp directory.
- The test for `applyValues` does **not** assert the decrypted value equals the original — that is already tested in `EncryptedPropertyDecryptionPostProcessorTest`. This test only asserts that the stored values are ENC-wrapped and do not contain the plain-text secret.
- No mocking of `PublicKeyUtils` — the real library is used (same rationale as Task 9).

---

### Task 11 — Update `README.md`

**File:** `README.md`
**Change type:** Modify

#### What to change

1. Correct the Technology Stack section (update Java 11 → Java 25, Spring Boot 2.7.18 → Spring Boot 3.4.11 — the README is currently stale).
2. Add a new **"Setup and Configuration"** section after the existing Configuration section documenting:
   - How to run the setup wizard
   - Which values are encrypted vs plain text
   - How to re-run the wizard to update credentials
   - Note that the `KIWI_DB_USER`, `KIWI_DB_PASS`, `KIWI_KS_PASS`, `KIWI_COMMS_USER`, `KIWI_COMMS_PASS` env vars are no longer used; credentials are now stored encrypted in `linkcentral.yaml`.

#### Why

AC #10: Documentation/usage notes must be added.

#### Code

Add after the Configuration section in README.md:

````markdown
## Setup and Configuration

LinkCentral uses encrypted credentials in `kiwiplan/linkcentral.yaml` to protect sensitive values at rest.
Encryption uses the Kiwiplan `kp-crypto` library (RSA+DES, keys embedded in the library).
Encrypted values are stored in the format `ENC(<Base64>)` and decrypted automatically at startup.

### Running the Setup Wizard

Run the setup wizard **before** starting LinkCentral for the first time, or to update credentials:

```bash
java -jar linkcentral.jar --setup
```

To specify a custom config path:

```bash
java -jar linkcentral.jar --setup --config-path=/path/to/kiwiplan/linkcentral.yaml
```

The wizard prompts for:

| Field | Encrypted? |
|---|---|
| DB host | No |
| DB port | No |
| DB username | **Yes** |
| DB password | **Yes** |
| Classic / Man / CSC DB names | No |
| Comms server host | No |
| Comms server port | No |
| Comms username | **Yes** |
| Comms password | **Yes** |
| Keystore file path | No |
| Keystore password | **Yes** |

A backup of the existing `linkcentral.yaml` is created as `linkcentral.yaml.bak` before overwriting.

### Starting LinkCentral

After the wizard completes:

```bash
java -jar linkcentral.jar
```

No environment variables for credentials are required. The `KIWI_DB_USER`, `KIWI_DB_PASS`,
`KIWI_KS_PASS`, `KIWI_COMMS_USER`, and `KIWI_COMMS_PASS` environment variables are no longer used.
````

#### Notes

- The Technology Stack correction (Java 25, Spring Boot 3.4.11) is in-scope here as the README currently states incorrect versions, causing confusion.
- Do not document internal implementation details (ENC format, crypto library internals) in the README — the above is sufficient for operators and developers.

---

## Backward Compatibility Assessment

| Changed interface | Change type | Consumers affected | Action required |
|---|---|---|---|
| `linkcentral.yaml` schema (credentials fields) | **Behavior-changing** | Any deployment using env-var-based credentials (`${KIWI_DB_USER}`, `${KIWI_DB_PASS}`, `${KIWI_KS_PASS}`, `${KIWI_COMMS_USER}`, `${KIWI_COMMS_PASS}`) | **Must run wizard on upgrade.** New deploys and upgrades: wizard must be run to generate `ENC(...)` values. Old env-var-based configs will still work until the wizard is run (env vars are still resolved by Spring if present). |
| `LinkCentralApplication.main()` | Additive | None — `--setup` arg check is new; existing startup path unchanged | None |
| `JdbiConfiguration` | None — no code changes | Not affected | None |
| `CommsClientConfig` | None — no code changes | Not affected | None |
| `EncryptedPropertyDecryptionPostProcessor` | Additive | None — only activates when `ENC(...)` markers are present | None |

**Version bump required:** No. This is an additive change to configuration handling with no REST API, JINI DTO, or public Java interface changes.

**Important upgrade note:** Sites running the current version with env-var-based credentials will continue to work unchanged (the post-processor only acts on `ENC(...)` values). They should be migrated to the wizard-generated encrypted config on their next maintenance window.

---

## Test Plan

| Test Class | Test Method | What it verifies |
|---|---|---|
| `EncryptedPropertyDecryptionPostProcessorTest` | `isEncrypted_returnsTrue_forValidEncFormat` | ENC pattern detection — positive case |
| `EncryptedPropertyDecryptionPostProcessorTest` | `isEncrypted_returnsFalse_forPlainText` | ENC pattern detection — negative cases (null, plain text, malformed) |
| `EncryptedPropertyDecryptionPostProcessorTest` | `extractBase64_returnsInnerContent` | Base64 extraction from ENC wrapper |
| `EncryptedPropertyDecryptionPostProcessorTest` | `postProcessEnvironment_decryptsEncValue_andInjectsDecryptedPropertySource` | Full encrypt→ENC→post-process→decrypted round-trip |
| `EncryptedPropertyDecryptionPostProcessorTest` | `postProcessEnvironment_leavesNonEncryptedValues_unchanged` | Non-ENC values are untouched |
| `SetupWizardTest` | `encrypt_producesEncWrappedValue_thatDecryptsToOriginal` | Round-trip: `encrypt()` → `decryptToString()` |
| `SetupWizardTest` | `applyValues_setsEncryptedCredentials_inNestedMap` | Wizard builds correct YAML map; sensitive fields are ENC-wrapped |
| `SetupWizardTest` | `promptSensitive_throwsIllegalArgument_whenInputIsEmpty` | Wizard rejects empty sensitive input |

Coverage expectations:
- `EncryptedPropertyDecryptionPostProcessor.java`: ~85% line, ~75% branch
- `SetupWizard.java`: ~70% line (interactive `execute()` method and `run()` are harder to cover without a full integration test; the critical encrypt/apply logic has full coverage)
- Integration validation: AC #11 (starts with encrypted credentials) is verified manually during deployment testing.

---

## Dependencies and Risks

| Item | Type | Notes |
|---|---|---|
| `com.kiwiplan.inf:kp-crypto:3.0.0` | Dependency | Already in local Maven repo. Confirm it is present in the CI/CD build agent's Maven repository (Nexus/Artifactory). If not, it must be published there before the CI build can resolve it. |
| `PublicKeyUtils` key embeddedness | Design constraint | The RSA+DES keys are baked into the `kp-crypto` library. If the library version changes, previously encrypted values may not decrypt with a newer version. Pin `kp-crypto.version` and do not upgrade without testing round-trips. |
| `snakeyaml` comment stripping | Known limitation | The wizard strips YAML comments on rewrite. Sample files are not touched by the wizard; only the deployed `linkcentral.yaml` is rewritten. Operators who hand-edited the config with inline comments will lose those comments on wizard re-run. Document this. |
| `System.console()` in non-TTY environments | Risk | If `setupWizard.run()` is called in a non-TTY environment (Docker, SSH without TTY), `Scanner(System.in)` still works but passwords will echo. Consider adding a note in the README. |
| Upgrade path for existing deployments | Risk | Existing sites with env-var credentials must be migrated. The wizard + the backward-compatible post-processor (which ignores non-ENC values) provides a safe migration path. Coordinate with the deployment team. |

---

## Out of Scope

| Item | Reason |
|---|---|
| Password echo suppression (`System.console().readPassword()`) | Requires TTY context check and adds complexity. The current `Scanner` approach is safe in all environments. Can be a follow-up improvement. |
| Encrypting non-credential config values (DB host, port, etc.) | Not required by acceptance criteria. |
| Changes to `KP-Xmit-LinkDevice` or `KP-Xmit-VLink-2.0` | Explicitly excluded by the work item. |
| Key rotation / re-encryption workflow | `kp-crypto` uses embedded keys; rotation would require a library upgrade + full re-wizard. Out of scope for this ticket. |
| HSM or external vault integration (HashiCorp Vault, AWS Secrets Manager) | Future enhancement. The `EnvironmentPostProcessor` hook makes this easy to add later. |
| Masking decrypted values from Spring Boot Actuator `/env` endpoint | Should be considered as a follow-up security hardening task (Actuator exposes `Environment` properties if enabled). |
