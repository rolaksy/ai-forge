## 🚀 Implementation Summary

**Date:** 29 May 2026 | **Author:** Laks Yalamati | **PR:** [PR #42785 — Implement encryption and decryption for sensitive configuration values](https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-LinkCentral/pullrequest/42785)

### 📋 What Was Implemented

1. An `ENC(...)` encryption pattern backed by the existing `kp-crypto` library (`PublicKeyUtils`) was introduced so sensitive credentials in `linkcentral.yaml` are no longer stored as plain text or resolved from plain-text environment variables.
2. A Spring `EnvironmentPostProcessor` (`EncryptedPropertyDecryptionPostProcessor`) was added to decrypt all `ENC(...)` values transparently before any Spring bean is created — requiring zero changes to existing `@Value` or `@ConfigurationProperties` bindings.
3. A CLI encryption utility (`ConfigValueEncrypt`) and a companion deployment shell script (`config-encrypt.sh`) were added so technicians can produce `ENC(...)` values for any credential with a single command.
4. All three sample `linkcentral.yaml` configuration files were updated to replace plain-text credentials and environment-variable references (`${KIWI_DB_USER}`, `${KIWI_DB_PASS}`, `${KIWI_KS_PASS}`, `remuser`, `secr8`) with `ENC(PLACEHOLDER)` markers and instructional inline comments.

### 🔨 Changes Made

**File:** `pom.xml`  
**Change:** Added `com.kiwiplan.inf:kp-crypto:3.0.0` dependency with `<kp-crypto.version>3.0.0</kp-crypto.version>` property. Switched spring-boot-maven-plugin repackaged JAR layout to `ZIP` (PropertiesLauncher), enabling alternate main class invocation via `java -Dloader.main=...` directly from the production JAR.

---

**File:** `src/main/java/com/kiwiplan/link/linkcentral/config/EncryptedPropertyDecryptionPostProcessor.java`  
**Method:** `postProcessEnvironment()`  
**Change:** New `EnvironmentPostProcessor` implementation. Iterates all Spring `PropertySource` entries at startup, detects values matching the `ENC(...)` pattern, Base64-decodes and decrypts them using `PublicKeyUtils.decryptToString()`, then inserts the plain-text results as a highest-priority `MapPropertySource` named `decryptedProperties`. Non-encrypted values pass through unchanged.

```java
@Override
public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
    Map<String, Object> decrypted = new HashMap<>();
    MutablePropertySources propertySources = environment.getPropertySources();

    for (PropertySource<?> source : propertySources) {
        // ... iterate source entries, detect ENC(...) values, decrypt and collect
    }

    if (!decrypted.isEmpty()) {
        propertySources.addFirst(new MapPropertySource(DECRYPTED_SOURCE_NAME, decrypted));
    }
}
```

---

**File:** `src/main/java/com/kiwiplan/link/linkcentral/LinkCentralApplication.java`  
**Method:** `main()`  
**Change:** Registered `EncryptedPropertyDecryptionPostProcessor` as an `EnvironmentPostProcessorApplicationListener` on the `SpringApplicationBuilder` so it executes before the application context is refreshed.

---

**File:** `src/main/java/com/kiwiplan/link/linkcentral/util/ConfigValueEncrypt.java`  
**Method:** `main()` / `encrypt()`  
**Change:** New standalone CLI utility. Accepts a single plain-text argument, calls `PublicKeyUtils.encryptString()`, Base64-encodes the result, and prints it wrapped as `ENC(<base64>)`. Designed to be invoked as an alternate main class directly from `linkcentral.jar`.

---

**File:** `src/main/resources/config-encrypt.sh`  
**Change:** New deployment shell script. Validates prerequisites (`JAVA_HOME` set, `linkcentral.jar` present in script directory), then delegates to `ConfigValueEncrypt` via `java -Dloader.main=com.kiwiplan.link.linkcentral.util.ConfigValueEncrypt -jar linkcentral.jar <plaintext>`.

---

**Files:** `src/main/resources/sample/linkcentral.yaml-opal-bhs`, `linkcentral.yaml-para`, `linkcentral.yaml-gopfert-stora`  
**Change:** Replaced plain-text env var references and hard-coded credentials (`remuser`, `secr8`) with `ENC(PLACEHOLDER)` markers on `spring.datasource.username`, `spring.datasource.password`, `server.ssl.key-store-password`, `kiwiplan.comms.username`, and `kiwiplan.comms.password`. Added inline comments directing technicians to use `deploy/config-encrypt.sh <value>` to generate real encrypted values.

### 💡 How It Works

- **Encryption flow:** `config-encrypt.sh <plaintext>` invokes `ConfigValueEncrypt`, which calls `PublicKeyUtils.encryptString()` (RSA+DES, non-deterministic). The encrypted bytes are Base64-encoded and returned as `ENC(<base64>)`. The technician pastes this value into `linkcentral.yaml`.
- **Decryption at startup:** `EncryptedPropertyDecryptionPostProcessor` runs in Spring's environment post-processing phase — before any bean is instantiated. It scans all property sources for `ENC(...)` values, decrypts them using `PublicKeyUtils.decryptToString()`, and injects plain-text results as the highest-priority property source. All existing `@Value`/`@ConfigurationProperties` bindings receive the decrypted value without modification.
- **Backward compatibility:** The `ENC(...)` detection is opt-in. Any property value that does not match the pattern passes through unchanged, so deployments still using plain-text or environment variables continue to work.
- **Alternate main via ZIP layout:** The `<layout>ZIP</layout>` configuration in the Maven plugin switches the repackaged JAR to use `PropertiesLauncher`, which supports `java -Dloader.main=<class>` invocations. This allows `ConfigValueEncrypt` to be shipped inside the same production JAR with no additional packaging step.

### 📁 Key Files

| File | Change |
|---|---|
| `pom.xml` | Added `kp-crypto:3.0.0` dependency; switched JAR layout to ZIP (PropertiesLauncher) |
| `config/EncryptedPropertyDecryptionPostProcessor.java` | New `EnvironmentPostProcessor` — decrypts all `ENC(...)` properties before bean creation |
| `LinkCentralApplication.java` | Registered `EncryptedPropertyDecryptionPostProcessor` as application listener |
| `util/ConfigValueEncrypt.java` | New CLI encryption utility — outputs `ENC(...)` values for YAML configuration |
| `resources/config-encrypt.sh` | New deployment shell script wrapping `ConfigValueEncrypt` for technician use |
| `sample/linkcentral.yaml-opal-bhs` | Replaced plain-text/env-var credentials with `ENC(PLACEHOLDER)` markers |
| `sample/linkcentral.yaml-para` | Replaced plain-text/env-var credentials with `ENC(PLACEHOLDER)` markers |
| `sample/linkcentral.yaml-gopfert-stora` | Replaced plain-text/env-var credentials with `ENC(PLACEHOLDER)` markers |
| `config/EncryptedPropertyDecryptionPostProcessorTest.java` | New unit tests for post-processor (isEncrypted, extractBase64, decrypt round-trip) |
| `util/ConfigValueEncryptTest.java` | New unit tests for encrypt utility (round-trip, non-determinism, special characters) |
