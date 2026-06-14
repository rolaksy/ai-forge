# ADO 927532 - Config-Driven Field Customization Implementation Design

**Work Item**: XMGEN Modern - Config-Driven Field Customization for NLA - custom field support  
**Date**: February 10, 2026  
**Last Updated**: February 13, 2026  
**Status**: Design Phase  
**Design Version**: 2.0 (Simplified)

---

## Design Approach - Simplified Version

After discussion with the Technical Lead, the design has been **simplified** to focus on essential functionality:

### **Key Changes from Original Design**

| Aspect | Original Design | Simplified Design |
|--------|----------------|-------------------|
| **Field Naming** | `fieldPath` | `targetField` |
| **Enable Flag** | `overridable` | `enable` |
| **Expression** | Full JEXL with `item.` prefix and conditionals | Simple math operations (*, /, +, -) separated from source field |
| **Complexity** | Supports conditionals, string manipulation | Only basic math operations, clear separation of source and operation |
| **Use Case** | Complex transformations with business logic | Simple field calculations and adjustments |
| **Storage** | Embedded in link config | **Separate YAML file with ID reference** |

### **Configuration Structure**

#### **Main Configuration (linkdevice.yml)**
```yaml
version: 1
links:
  - id: gopfert_link_1
    type: converter
    customizations: custom_id_1  # Reference to customizations file
    configurations:
      delay: 10000
      trialMode: false
      kiwiplan:
        machineId: "1101"
        lineupSize: 5
    controllers:
      machine: "gopfert_controller_1"
```

#### **Customizations File (field-customizations.yml)**
```yaml
version: 1
customizations:
  - id: custom_id_1
    description: "Gopfert manufacturing tolerances and buffers"
    enabled: true
    rules:
      - targetField: "productSpecification.board.length"
        enable: true
        srcField: "productSpecification.board.length"
        expression: "*1.1"
        description: "Add 10% buffer"
      
      - targetField: "unitising.piecesRequired"
        enable: true
        srcField: "unitising.piecesRequired"
        expression: "+10"
        description: "Safety buffer"
  
  - id: custom_id_2
    description: "Alternative customization set"
    enabled: true
    rules:
      - targetField: "productSpecification.board.width"
        enable: true
        srcField: "productSpecification.board.width"
        expression: "*1.05"
        description: "5% tolerance"
```

### **Design Philosophy**

✅ **Simplicity**: Focus on common use cases (tolerances, buffers, calculations)  
✅ **Reusability**: Multiple links can share the same customization set  
✅ **Separation**: Customizations separate from main configuration  
✅ **Safety**: Limited expression scope reduces security concerns  
✅ **Clarity**: Clear separation between target field, source field, and operation  
✅ **Maintainability**: Easier to understand and debug  
✅ **Flexibility**: Expression can be empty for complex source expressions or contain simple operations

### **Field Usage Patterns**

The `srcField` and `expression` fields work together to create the final JEXL expression:

**Pattern 1: Simple Operation on Single Field**
```yaml
- targetField: "productSpecification.board.length"
  srcField: "productSpecification.board.length"  # The field to read from
  expression: "*1.1"                              # The operation to apply
  # Result: "productSpecification.board.length*1.1"
```

**Pattern 2: Complex Expression (No Operation)**
```yaml
- targetField: "productSpecification.totalDimension"
  srcField: "productSpecification.board.length + productSpecification.board.width"
  # expression field omitted when srcField contains complete expression
  # Result: "productSpecification.board.length + productSpecification.board.width"
```

**Pattern 3: Multiple Field Combination with Operation**
```yaml
- targetField: "productSpecification.averageDimension"
  srcField: "(productSpecification.board.length + productSpecification.board.width)"
  expression: "/2"
  # Result: "(productSpecification.board.length + productSpecification.board.width)/2"
```

**Supported Operations in `expression` field:**
- Multiplication: `*1.1`, `*1.05`, etc.
- Division: `/2`, `/100`, etc.
- Addition: `+10`, `+5`, etc.
- Subtraction: `-5`, `-10`, etc.  

---

## Table of Contents
1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Data Flow Analysis](#data-flow-analysis)
4. [Configuration Structure](#configuration-structure)
5. [Implementation Details](#implementation-details)
6. [Integration Points](#integration-points)
7. [Dependencies](#dependencies)
8. [File Structure](#file-structure)
9. [Testing Strategy](#testing-strategy)
10. [Complete Example](#complete-example)
11. [Security & Validation](#security--validation)
12. [Benefits](#benefits)

---

## Overview

This design document outlines the implementation of config-driven field customization using JEXL expressions for the LinkDevice application. The solution allows customers to define custom field transformations via YAML configuration without requiring code changes.

**Key Principle**: Single interception point after data comes from Link Central, before values are passed to the mapper or sent to the controller.

---

## Requirements

Based on ADO 927532, the solution must provide:

1. **Field Customization via JEXL Expressions**
   - Config-driven field modifications
   - Support for conditional logic
   - Access to full LineupItemDto context

2. **Single Interception Point**
   - After data comes from Link Central
   - Before values are passed to the mapper or sent to the controller

3. **Fallback Behavior**
   - When a value is not found in config: Return the original unmodified value
   - On expression evaluation error: Return the original unmodified value
   - On any processing error: Return the original unmodified value

4. **Field Metadata**
   - Each field marked as `overridable: true/false`
   - Field path specification (JSONPath-style)
   - Optional description for documentation

---

## Data Flow Analysis

### Current Data Flow

```
LinkCentral API (REST)
  ↓
  returns LineupDto containing List<LineupItemDto>
  ↓
GeneralLinkService.getLineup()
  ↓
  List<LineupItemDto> returned
  ↓
  ⚡ [FIELD CUSTOMIZATION HAPPENS HERE] ⚡
  ↓
Mapper (e.g., GopfertPlantFloorMachineMapper)
  ↓
  LineupItemDto → Protocol-specific DTO (e.g., LineupItemAddReqDto)
  ↓
ControllerService
  ↓
  Protocol DTO → Encoded Message
  ↓
Controller Communication (TCP/File)
```

### Key Classes Involved

1. **GeneralLinkService** (`linkdevice-app/src/main/java/com/kiwiplan/linkdevice/link/GeneralLinkService.java`)
   - Contains `getLineup()` method (line ~128)
   - Returns `List<LineupItemDto>` from Link Central API
   - **Primary integration point**

2. **LineupItemDto** (`linkdevice-app/src/main/java/com/kiwiplan/linkdevice/dto/linkcentral/lineup/LineupItemDto.java`)
   - Main data structure from Link Central
   - Contains nested objects: ProductSpecificationDto, UnitisingDto, BoardDto, etc.
   - Fields to be customized

3. **LinkConfiguration** (`linkdevice-app/src/main/java/com/kiwiplan/linkdevice/config/link/converter/LinkConfiguration.java`)
   - Link configuration container
   - Will hold new `FieldCustomizationConfig`

4. **LinkConfigurations** (`linkdevice-app/src/main/java/com/kiwiplan/linkdevice/config/link/LinkConfigurations.java`)
   - Configuration properties for a link
   - Will be extended with `fieldCustomization` property

---

## Configuration Structure

### YAML Configuration Schema

#### **Main Link Configuration File**

```yaml
version: 1
links:
  - id: gopfert_link_1
    type: converter
    customizations: custom_id_1  # ← Reference to customizations by ID
    configurations:
      delay: 10000
      trialMode: false
      kiwiplan:
        machineId: "1101"
        lineupSize: 5
    controllers:
      machine: "gopfert_controller_1"
  
  - id: gopfert_link_2
    type: converter
    customizations: custom_id_1  # ← Same customizations reused
    configurations:
      delay: 10000
      trialMode: false
      kiwiplan:
        machineId: "1102"
        lineupSize: 5
    controllers:
      machine: "gopfert_controller_2"

controllers:
  - id: gopfert_controller_1
    description: "Gopfert Machine 1"
    protocolName: gopfert_plant_floor_machine
    protocolVersion: "1.0"
    configurations:
      hostname: "192.168.1.100"
      port: 5000
```

#### **Separate Field Customizations File (field-customizations.yml)**

```yaml
version: 1
customizations:
  # Customization Set 1: Manufacturing tolerances
  - id: custom_id_1
    description: "Standard Gopfert manufacturing tolerances and safety buffers"
    enabled: true
    rules:
      # Rule 1: Add 10% buffer to board length
      - targetField: "productSpecification.board.length"
        enable: true
        srcField: "productSpecification.board.length * 1.1"
        description: "Add 10% manufacturing tolerance to length"
      
      # Rule 2: Add 5% buffer to board width
      - targetField: "productSpecification.board.width"
        enable: true
        srcField: "productSpecification.board.width * 1.05"
        description: "Add 5% manufacturing tolerance to width"
      
      # Rule 3: Add fixed buffer to p (Root of Customizations File)

```java
package com.kiwiplan.linkdevice.config.link;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.util.ArrayList;
import java.util.List;

/**
 * Root configuration for field-customizations.yml file.
 * Contains a list of customization sets that can be referenced by ID.
 */
@JsonIgnoreProperties(ignoreUnknown = false)
public class FieldCustomizationConfig {
    
    @JsonProperty("version")
    private int version = 1;
    
    @Valid
    @NotNull(message = "Customizations list cannot be null")
    @JsonProperty("customizations")
    private List<CustomizationSet> customizations = new ArrayList<>();
    
    public FieldCustomizationConfig() {
        // Default constructor
    }
    
    public int getVersion() {
        return version;
    }
    
    public void setVersion(int version) {
        this.version = version;
    }
    
    public List<CustomizationSet> getCustomizations() {
        return customizations;
    }
    
    public void setCustomizations(List<CustomizationSet> customizations) {
        this.customizations = customizations;
    }
    
    /**
     * Find a customization set by ID
     */
    public CustomizationSet findById(String id) {
        return customizations.stream()
                .filter(c -> c.getId().equals(id))
                .findFirst()
                .orElse(null);
    }
    
    @Override
    public String toString() {
        return "FieldCustomizationConfig{" +
                "version=" + version +
                ", customizations=" + customizations +
                '}';
    }
}
```

#### 2. CustomizationSet.java

```java
package com.kiwiplan.linkdevice.config.link;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.ArrayList;
import java.util.List;

/**
 * A named set of field customization rules.
 * Can be referenced by multiple links via its ID.
 */
@JsonIgnoreProperties(ignoreUnknown = false)
public class CustomizationSet {
    
    @NotBlank(message = "Customization ID is required")
    @JsonProperty("id")
    private String id;
    
    @JsonProperty("description")
    private String description;
    
    @JsonProperty("enabled")
    private boolean enabled = true;
    
    @Valid
    @NotNull(message = "Rules list cannot be null")
    @JsonProperty("rules")
    private List<FieldCustomizationRule> rules = new ArrayList<>();
    
    public CustomizationSet() {
        // Default constructor
    }
    
    public String getId() {
        return id;
    }
    
    public void setId(String id) {
        this.id = id;
    }
    
    public String getDescription() {
        return description;
    }
    
    public void setDescription(String description) {
        this.description = description;
    }
    
    public boolean isEnabled() {
        return enabled;
    }
    
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }
    
    public List<FieldCustomizationRule> getRules() {
        return rules;
    }
    
    public void setRules(List<FieldCustomizationRule> rules) {
        this.rules = rules;
    }
    
    @Override
    public String toString() {
        return "CustomizationSet{" +
                "id='" + id + '\'' +
                ", description='" + description + '\'' +
                ", enabled=" + enabled +
                ", rules=" + rules +
                '}';
    }
}
```

#### 3
import java.util.ArrayList;
import java.util.List;

/**
 * Configuration for field customization feature.
 * Allows JEXL-based field transformations on LineupItemDto objects
 * after receiving data from Link Central and before passing to mappers/controllers.
 */
@JsonIgnoreProperties(ignoreUnknown = false)
public class FieldCustomizationConfig {
    
    @JsonProperty("enabled")
    private boolean enabled = false;
    
    @Valid
    @NotNull(message = "Field customization rules list cannot be null")
    @JsonProperty("rules")
    private List<FieldCustomizationRule> rules = new ArrayList<>();
    
    public FieldCustomizationConfig() {
        // Default constructor
    }
    
    public boolean isEnabled() {
        return enabled;
    }
    
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }
    
    public List<FieldCustomizationRule> getRules() {
        return rules;
    }
    
    public void setRules(List<FieldCustomizationRule> rules) {
        this.rules = rules;
    }
    
    @Override
    public String toString() {
        return "FieldCustomizationConfig{" +
                "enabled=" + enabled +
                ", rules=" + rules +
                '}';
    }
}
```

#### 2. FieldCustomizationRule.java

```java
package com.kiwiplan.linkdevice.config.link;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;

/**
 * Individual field customization rule (Simplified Design).
 * Defines a target field to override, a source field path, and a simple math operation.
 * Supports basic operations: *, /, +, -
 * 
 * Example:
 *   targetField: "productSpecification.board.length"
 *   srcField: "productSpecification.board.length"
 *   expression: "*1.1"
 */
@JsonIgnoreProperties(ignoreUnknown = false)
public class FieldCustomizationRule {
    
    @NotBlank(message = "Target field is required and cannot be blank")
    @JsonProperty("targetField")
    private String targetField;
    
    @JsonProperty("enable")
    private boolean enable = true;
    
    @NotBlank(message = "Source field is required and cannot be blank")
    @JsonProperty("srcField")
    private String srcField;
    
    // Optional - can be empty for complex expressions in srcField
    @JsonProperty("expression")
    private String expression;
    
    @JsonProperty("description")
    private String description;
    
    public FieldCustomizationRule() {
        // Default constructor
    }
    
    public String getTargetField() {
        return targetField;
    }
    
    public void setTargetField(String targetField) {
        this.targetField = targetField;
    }
    
    public boolean isEnable() {
        return enable;
    }
    
    public void setEnable(boolean enable) {
        this.enable = enable;
    }
    
    public String getSrcField() {
        return srcField;
    }
    
    public void setSrcField(String srcField) {
        this.srcField = srcField;
    }
    
    public String getExpression() {
        return expression;
    }
    
    public void setExpression(String expression) {
        this.expression = expression;
    }
    
    public String getDescription() {
        return description;
    }
    
    public void setDescription(String description) {
        this.description = description;
    }
    
    @Override
    public String toString() {
        return "FieldCustomizationRule{" +
                "targetField='" + targetField + '\'' +
                ", enable=" + enable +
                ", srcField='" + srcField + '\'' +
                ", expression='" + expression + '\'' +
                ", description='" + description + '\'' +
                '}';
    }
}
```

#### 3. Modify LinkConfigurations.java

```java
package com.kiwiplan.linkdevice.config.link;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonMerge;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonSetter;
import com.fasterxml.jackson.annotation.Nulls;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

@JsonIgnoreProperties(ignoreUnknown = false)
public class LinkConfigurations {
    
    @NotNull(message = "Kiwiplan configuration is required")
    @Valid
    @JsonMerge
    @JsonProperty("kiwiplan")
    @JsonSetter(nulls = Nulls.SKIP)
    private KiwiplanConfig kiwiplanConfig;
    
    private boolean trialMode;
    
    @Min(value = 0, message = "Delay must be non-negative (milliseconds)")
    private int delay = 30000;
    
    // N
    
    public LinkConfigurations() {
        this.kiwiplanConfig = new KiwiplanConfig();
    }
    
    public KiwiplanConfig getKiwiplanConfig() {
        return kiwiplanConfig;
    }
    
    public void setKiwiplanConfig(KiwiplanConfig kiwiplanConfig) {
        this.kiwiplanConfig = kiwiplanConfig;
    }
    
    public boolean isTrialMode() {
        return trialMode;
    }
    
    public void setTrialMode(boolean trialMode) {
        this.trialMode = trialMode;
    }
    
    public int getDelay() {
        return delay;
    }
    
    public void setDelay(int delay) {
        this.delay = delay;
    }
    
    @Override
    public String toString() {
        return "LinkConfigurations{" +
                "kiwiplanConfig=" + kiwiplanConfig +
                ", trialMode=" + trialMode +
                ", delay=" + delay +
                '}';
    }
}
```

#### 4. Modify LinkConfiguration.java (Add customizations field)

```java
package com.kiwiplan.linkdevice.config.link.converter;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.kiwiplan.linkdevice.config.link.AbstractLinkConfiguration;
import com.kiwiplan.linkdevice.config.link.LinkConfigurations;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

@JsonIgnoreProperties(ignoreUnknown = false)
public class LinkConfiguration extends AbstractLinkConfiguration {
    
    @NotNull(message = "Link configurations are required")
    @Valid
    @JsonProperty("configurations")
    private LinkConfigurations configurations;
    
    // NEW FIELD - Reference to customizations by ID
    @JsonProperty("customizations")
    private String customizations;
    
    public LinkConfiguration() {
        this.configurations = new LinkConfigurations();
    }
    
    public LinkConfigurations getConfigurations() {
        return configurations;
    }
    
    public void setConfigurations(LinkConfigurations configurations) {
        this.configurations = configurations;
    }
    
    // NEW GETTER/SETTER
    public String getCustomizations() {
        return customizations;
    }
    
    public void setCustomizations(String customizations) {
        this.customizations = customizations;
    }
    
    @Override
    public String toString() {
        return "LinkConfiguration{" +
                "id='" + getId() + '\'' +
                ", type='" + getType() + '\'' +
                ", customizations='" + customizations + '\'' +
                ", configurations=" + configurations
    

```

#### 3. Modify LinkConfigurations.java

```java
package com.kiwiplan.linkdevice.config.link;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonMerge;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonSetter;
import com.fasterxml.jackson.annotation.Nulls;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

@JsonIgnoreProperties(ignoreUnknown = false)
public class LinkConfigurations {
    
    @NotNull(message = "Kiwiplan configuration is required")
    @Valid
    @JsonMerge
    @JsonProperty("kiwiplan")
    @JsonSetter(nulls = Nulls.SKIP)
    private KiwiplanConfig kiwiplanConfig;
    
    private boolean trialMode;
    
    @Min(value = 0, message = "Delay must be non-negative (milliseconds)")
    private int delay = 30000;
    
    // NEW FIELD - Field Customization
    @Valid
    @JsonMerge
    @JsonProperty("fieldCustomization")
    @JsonSetter(nulls = Nulls.SKIP)
    private FieldCustomizationConfig fieldCustomization;
    
    public LinkConfigurations() {
        this.kiwiplanConfig = new KiwiplanConfig();
    }
    
    public KiwiplanConfig getKiwiplanConfig() {
        return kiwiplanConfig;
    }
    
    public void setKiwiplanConfig(KiwiplanConfig kiwiplanConfig) {
        this.kiwiplanConfig = kiwiplanConfig;
    }
    
    public boolean isTrialMode() {
        return trialMode;
    }
    
    public void setTrialMode(boolean trialMode) {
        this.trialMode = trialMode;
    }
    
    public int getDelay() {
        return delay;
    }
    
    public void setDelay(int delay) {
        this.delay = delay;
    }
    
    // NEW GETTER/SETTER
    public FieldCustomizationConfig getFieldCustomization() {
        return fieldCustomization;
    }
    
    public void setFieldCustomization(FieldCustomizationConfig fieldCustomization) {
        this.fieldCustomization = fieldCustomization;
    }
    
    @Override
    public String toString() {
        return "LinkConfigurations{" +
                "kiwiplanConfig=" + kiwiplanConfig +
                ", trialMode=" + trialMode +
                ", delay=" + delay +
                ", fieldCustomization=" + fieldCustomization +
                '}';
    }
}
```

---

## Implementation Details

### FieldCustomizationLoader.java (New Component)

```java
package com.kiwiplan.linkdevice.service.expression;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import com.kiwiplan.linkdevice.config.link.FieldCustomizationConfig;
import com.kiwiplan.linkdevice.config.link.CustomizationSet;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.io.InputStream;

/**
 * Loader for field customizations from separate YAML file.
 * Loads field-customizations.yml at startup and caches customization sets.
 */
@Component
public class FieldCustomizationLoader {
    
    private static final Logger log = LoggerFactory.getLogger(FieldCustomizationLoader.class);
    private static final String CUSTOMIZATIONS_FILE = "classpath:field-customizations.yml";
    
    private final ResourceLoader resourceLoader;
    private final ObjectMapper yamlMapper;
    private FieldCustomizationConfig customizationConfig;
    
    public FieldCustomizationLoader(ResourceLoader resourceLoader) {
        this.resourceLoader = resourceLoader;
        this.yamlMapper = new ObjectMapper(new YAMLFactory());
    }
    
    @PostConstruct
    public void loadCustomizations() {
        try {
            Resource resource = resourceLoader.getResource(CUSTOMIZATIONS_FILE);
            
            if (!resource.exists()) {
                log.info("No field-customizations.yml found. Field customization disabled.");
                customizationConfig = new FieldCustomizationConfig();
                return;
            }
            
            log.info("Loading field customizations from: {}", CUSTOMIZATIONS_FILE);
            
            try (InputStream is = resource.getInputStream()) {
                customizationConfig = yamlMapper.readValue(is, FieldCustomizationConfig.class);
                log.info("Loaded {} customization sets", customizationConfig.getCustomizations().size());
                
                // Log each customization set
                for (CustomizationSet set : customizationConfig.getCustomizations()) {
                    log.debug("  - {} (enabled={}, rules={}): {}", 
                        set.getId(), 
                        set.isEnabled(), 
                        set.getRules().size(),
                        set.getDescription());
                }
            }
            
        } catch (IOException e) {
            log.error("Failed to load field customizations: {}", e.getMessage(), e);
            customizationConfig = new FieldCustomizationConfig();
        }
    }
    
    /**
     * Get a customization set by ID
     * @param id The customization ID
     * @return CustomizationSet or null if not found
     */
    public CustomizationSet getCustomizationSet(String id) {
        if (customizationConfig == null || id == null) {
            return null;
        }
        
        CustomizationSet set = customizationConfig.findById(id);
        
        if (set == null) {
            log.warn("Customization set not found: {}", id);
        }
        
        return set;
    }
    
    /**
     * Check if a customization set exists and is enabled
     */
    public boolean isCustomizationEnabled(String id) {
        CustomizationSet set = getCustomizationSet(id);
        return set != null && set.isEnabled();
    }
}
```

### FieldCustomizationService.java

```java
package com.kiwiplan.linkdevice.service.expression;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kiwiplan.linkdevice.config.link.FieldCustomizationRule;
import org.apache.commons.jexl3.JexlBuilder;
import org.apache.commons.jexl3.JexlContext;
import org.apache.commons.jexl3.JexlEngine;
import org.apache.commons.jexl3.JexlExpression;
import org.apache.commons.jexl3.MapContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.List; (Simplified Design).
 * 
 * This service processes LineupItemDto objects and applies configured field transformations
 * after data is received from Link Central and before it's passed to mappers/controllers.
 * 
 * Key Features:
 * - Simple JEXL expressions with basic math operations (+, -, *, /)
 * - Nested field path support (dot notation)
 * - Safe fallback: returns original value on any error
 * - Respects enable flag on rules
 * 
 * Design:
 * - targetField: The field to override
 * - srcField: The source field path to read from
 * - expression: The simple math operation to apply (e.g., "*1.1", "+10", "/2")
 * 
 * @see com.kiwiplan.linkdevice.config.link.FieldCustomizationConfig
 * @see com.kiwiplan.linkdevice.config.link.FieldCustomizationRule
 */
@Component
public class FieldCustomizationService {
    
    private static final Logger log = LoggerFactory.getLogger(FieldCustomizationService.class);
    
    private final JexlEngine jexlEngine;
    private final ObjectMapper objectMapper;
    
    public FieldCustomizationService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
        
        // Initialize JEXL engine with caching and strict mode
        this.jexlEngine = new JexlBuilder()
                .cache(512)          // Cache up to 512 compiled expressions
                .strict(true)        // Strict variable resolution
                .silent(false)       // Don't silent errors, we want to handle them
                .create();
    }
    
    /**
     * Apply field customization rules to a lineup item.
     * 
     * If a value is not found in config or expression fails, returns original unmodified value.
     * This is the main entry point for field customization.
     * 
     * @param item The lineup item to customize
     * @param rules The list of customization rules to apply
     * @param <T> The type of the item (typically LineupItemDto)
     * @return Modified item if successful, original item on any error
     */
    public <T> T applyCustomizations(T item, List<FieldCustomizationRule> rules) {
        
        if (rules == null || rules.isEmpty()) {
            log.trace("No field customization rules to apply");
            return item;
        }
        
        if (item == null) {
            log.warn("Cannot apply customizations to null item");
            return item;
        }
        
        try {
            log.debug("Applying {} field customization rules", rules.size());
            
            // Convert to Map for easier manipulation of nested fields
            Map<String, Object> itemMap = objectMapper.convertValue(
                item, 
                new TypeReference<Map<String, Object>>() {}
            );
            
            int appliedCount = 0;
            int skippedCount = 0;
            
            // Apply each rule sequentially
            for (FieldCustomizationRule rule : rules) {
                if (rule.isEnable()) {
                    boolean applied = applyRule(itemMap, rule);
                    if (applied) {
                        appliedCount++;
                    } else {
                        skippedCount++;
                    }
                } else {
                    log.trace("Skipping disabled rule for field: {}", rule.getTargetField());
                    skippedCount++;
                }
            }
            
            log.debug("Field customization complete: {} applied, {} skipped", appliedCount, skippedCount);
            
            // Convert back to target type
            return objectMapper.convertValue(itemMap, (Class<T>) item.getClass());
            
        } catch (Exception e) {
            log.error("Error applying field customizations: {}. Returning original unmodified item.", e.getMessage(), e);
            // Return original unmodified value on error (as per requirement)
            return item;
        }
    }
    
    /**
     * Apply a single customization rule to the item.
     * Uses simplified design: targetField gets value from srcField expression.
     * 
     * @param itemMap The item represented as a Map
     * @param rule The rule to apply
     * @return true if rule was applied, false if skipped/failed
     */
    private boolean applyRule(Map<String, Object> itemMap, FieldCustomizationRule rule) {
        try {
            log.trace("Applying rule: {} = {} {} [{}]", 
                rule.getTargetField(), 
                rule.getSrcField(),
                rule.getExpression(),
                rule.getDescription() != null ? rule.getDescription() : "no description");
            
            // Get original value for logging
            Object oldValue = getFieldValue(itemMap, rule.getTargetField());
            
            // Create JEXL context with direct access to fields
            JexlContext context = new MapContext();
            
            // Populate context with all fields from itemMap for easy access
            populateContext(context, itemMap);
            
            // Combine srcField + expression to create the full expression
            // Example 1 (simple math): srcField="productSpecification.board.length" + expression="*1.1"
            //           Result: "productSpecification.board.length*1.1"
            // Example 2 (complex): srcField="productSpecification.board.length + productSpecification.board.width" + expression=""
            //           Result: "productSpecification.board.length + productSpecification.board.width"
            String fullExpression = rule.getSrcField() + (rule.getExpression() != null ? rule.getExpression() : "");
            log.trace("Evaluating expression: {}", fullExpression);
            
            // Evaluate the combined expression
            JexlExpression expression = jexlEngine.createExpression(fullExpression);
            Object result = expression.evaluate(context);
            
            // Apply result to target field
            if (result != null) {
                setFieldValue(itemMap, rule.getTargetField(), result);
                
                log.info("Applied customization: {} = {} (was: {}) [{}]", 
                    rule.getTargetField(), 
                    result, 
                    oldValue,
                    rule.getDescription() != null ? rule.getDescription() : "no description"
                );
                
                return true;
            } else {
                log.debug("Expression evaluated to null for field {}, keeping original value", 
                    rule.getTargetField());
                return false;
            }
            
        } catch (Exception e) {
            log.warn("Failed to apply rule for field {}: {}. Keeping original value.", 
                rule.getTargetField(), e.getMessage());
            // On error, original value is preserved (as per requirement)
            return false;
        }
    }
    
    /**
     * Populate JEXL context with fields from the item map.
     * This allows direct field access in expressions without "item." prefix.
     * For nested fields, use dot notation: productSpecification.board.length
     */
    private void populateContext(JexlContext context, Map<String, Object> itemMap) {
        populateContextRecursive(context, "", itemMap);
    }
    
    private void populateContextRecursive(JexlContext context, String prefix, Map<String, Object> map) {
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            String key = prefix.isEmpty() ? entry.getKey() : prefix + "." + entry.getKey();
            Object value = entry.getValue();
            
            // Add to context
            context.set(key, value);
            
            // If value is a nested map, recurse
            if (value instanceof Map) {
                @SuppressWarnings("unchecked")
                Map<String, Object> nestedMap = (Map<String, Object>) value;
                populateContextRecursive(context, key, nestedMap);
            }n e) {
            log.warn("Failed to apply rule for field {}: {}. Keeping original value.", 
                rule.getFieldPath(), e.getMessage());
            // On error, original value is preserved (as per requirement)
            return false;
        }
    }
    
    /**
     * Set nested field value using dot notation.
     * Example: "productSpecification.board.length" -> sets length in nested board object
     * 
     * @param map The map to modify
     * @param fieldPath Dot-separated path to field
     * @param value The value to set
     */
    private void setFieldValue(Map<String, Object> map, String fieldPath, Object value) {
        String[] parts = fieldPath.split("\\.");
        Map<String, Object> current = map;
        
        // Navigate to the parent of the target field
        for (int i = 0; i < parts.length - 1; i++) {
            Object next = current.get(parts[i]);
            
            if (!(next instanceof Map)) {
                // Create nested map if doesn't exist
                Map<String, Object> newMap = new HashMap<>();
                current.put(parts[i], newMap);
                current = newMap;
            } else {
                @SuppressWarnings("unchecked")
                Map<String, Object> nextMap = (Map<String, Object>) next;
                current = nextMap;
            }
        }
        
        // Set the final field value
        current.put(parts[parts.length - 1], value);
    }
    
    /**
     * Get nested field value using dot notation.
     * 
     * @param map The map to read from
     * @param fieldPath Dot-separated path to field
     * @return The field value, or null if not found
     */
    private Object getFieldValue(Map<String, Object> map, String fieldPath) {
        String[] parts = fieldPath.split("\\.");
        Object current = map;
        
        for (String part : parts) {
            if (current instanceof Map) {
                @SuppressWarnings("unchecked")
                Map<String, Object> currentMap = (Map<String, Object>) current;
                current = currentMap.get(part);
            } else {
                return null;
            }
        }
        
        return current;
    }
}
```

---

## Integration Points

### Modify GeneralLinkService.java

The single integration point is in the `getLineup()` method (line ~128):

```java
package com.kiwiplan.linkdevice.link;

// ... existing imports ...
import com.kiwiplan.linkdevice.service.expression.FieldCustomizationService;
import com.kiwiplan.linkdevice.service.expression.FieldCustomizationLoader;
import com.kiwiplan.linkdevice.config.link.CustomizationSet;
import java.util.stream.Collectors;

public class GeneralLinkService extends LinkService {

    private final Logger log = LoggerFactory.getLogger(GeneralLinkService.class);

    protected final GeneralControllerService controllerService;
    protected final CircularFifoQueue<LineupDto> lineupUpdateRequestQueue;

    private final LinkCentralClient linkcentralClient;
    private final ReentrantLock reentrantLock;
    private final SchedulerService schedulerService;
    private final NitriteRepo nitriteRepo;
    
    // NEW DEPENDENCIES
    private final FieldCustomizationService fieldCustomizationService;
    private final FieldCustomizationLoader fieldCustomizationLoader;

    public GeneralLinkService(AbstractLinkConfiguration linkConfig, 
                              LinkCentralClient linkcentralClient,
                              SchedulerService schedulerService, 
                              GeneralControllerService controllerService, 
                              NitriteRepo nitriteRepo,
                              FieldCustomizationService fieldCustomizationService,
                              FieldCustomizationLoader fieldCustomizationLoader) {  // NEW PARAMETER

        super(linkConfig);

        this.linkcentralClient = linkcentralClient;
        this.schedulerService = schedulerService;
        this.controllerService = controllerService;
        this.reentrantLock = new ReentrantLock(true);
        this.lineupUpdateRequestQueue = new CircularFifoQueue<>(1);
        this.nitriteRepo = nitriteRepo;
        this.fieldCustomizationService = fieldCustomizationService;
        this.fieldCustomizationLoader = fieldCustomizationLoader;  // NEW ASSIGNMENT
        
        this.schedulerService.setDelay(getLinkConfig().getConfigurations().getDelay())
                .setId(getId())
                .addTask(this::scheduledTasks);
    }

    // ... other methods ...

    /**
     * Get lineup items from Kiwiplan/Link Central.
     * This method fetches data from the API and applies field customizations if configured.
     * 
     * @return List of LineupItemDto objects (potentially customized)
     * @throws LinkRequestFailedException if API call fails or returns invalid data
     */
    private List<LineupItemDto> getLineup() {
        
        log.info("Pulling Lineup From Kiwiplan API.");

        String machineId = getLinkConfig().getConfigurations().getKiwiplanConfig().getMachineId();
        int runListSize = getLinkConfig().getConfigurations().getKiwiplanConfig().getLineupSize();

        // Fetch data from Link Central API
        LineupDto lineupDto = linkcentralClient.getLineupEntries(machineId, runListSize, LineupDto.class);
        
        if (Objects.isNull(lineupDto.getConverterJobs())) {
            throw new LinkRequestFailedException("Invalid Payload Received from Kiwiplan.");
        }

        log.info("Lineup Received from Kiwiplan: {}", lineupDto);

        // Get lineup items
        List<LineupItemDto> lineupItems = lineupDto.getConverterJobs();
        
        // ⚡ SINGLE INTERCEPTION POINT: After Link Central, Before Mapper/Controller
        // Apply field customizations if configured
        String customizationId = getLinkConfig().getCustomizations();
        
        if (customizationId != null && !customizationId.isBlank()) {
            log.info("Link references customization set: {}", customizationId);
            
            CustomizationSet customizationSet = fieldCustomizationLoader.getCustomizationSet(customizationId);
            
            if (customizationSet != null && customizationSet.isEnabled()) {
                log.info("Applying field customizations to {} lineup items using set: {} [{}]", 
                    lineupItems.size(), 
                    customizationId,
                    customizationSet.getDescription());
                
                try {
                    lineupItems = lineupItems.stream()
                        .map(item -> fieldCustomizationService.applyCustomizations(
                            item, 
                            customizationSet.getRules()
                        ))
                        .collect(Collectors.toList());
                        
                    log.info("Field customizations applied successfully");
                    
                } catch (Exception e) {
                    log.error("Error during field customization processing: {}. Using original lineup items.", 
                        e.getMessage(), e);
                    // On error, use original lineup items (fail-safe behavior)
                }
            } else {
                log.warn("Customization set '{}' is not found or disabled", customizationId);
            }
        } else {
            log.debug("No field customization configured for this link");
        }

        return lineupItems;
    }

    // ... rest of the class ...
}
```

### Update LinkServiceFactory.java

Update all factory methods to inject both new services:

```java
package com.kiwiplan.linkdevice.link;

import com.kiwiplan.linkdevice.service.expression.FieldCustomizationService;
import com.kiwiplan.linkdevice.service.expression.FieldCustomizationLoader;
// ... other imports ...

@Component
public class LinkServiceFactory {

    private final ApplicationContext applicationContext;

    public LinkServiceFactory(ApplicationContext applicationContext) {
        this.applicationContext = applicationContext;
    }

    // ... other methods ...

    private GeneralLinkService getDownloadOnlyConverterLinkService(
            LinkConfiguration config, 
            GeneralControllerService controllerService) {

        LinkCentralClient linkCentralClient = applicationContext.getBean(LinkCentralClient.class);
        SchedulerService schedulerService = applicationContext.getBean(SchedulerService.class);
        NitriteRepo nitriteRepo = applicationContext.getBean(NitriteRepo.class);
        FieldCustomizationService fieldCustomizationService = 
            applicationContext.getBean(FieldCustomizationService.class);
        FieldCustomizationLoader fieldCustomizationLoader = 
            applicationContext.getBean(FieldCustomizationLoader.class);  // NEW

        return new DownloadOnlyConverterLinkService(
            config, 
            linkCentralClient, 
            schedulerService, 
            controllerService, 
            nitriteRepo,
            fieldCustomizationService,
            fieldCustomizationLoader  // NEW PARAMETER
        );
    }

    private GeneralLinkService getConverterLinkService(
            LinkConfiguration config, 
            GeneralControllerService controllerService) {

        LinkCentralClient linkCentralClient = applicationContext.getBean(LinkCentralClient.class);
        SchedulerService schedulerService = applicationContext.getBean(SchedulerService.class);
        NitriteRepo nitriteRepo = applicationContext.getBean(NitriteRepo.class);
        FieldCustomizationService fieldCustomizationService = 
            applicationContext.getBean(FieldCustomizationService.class);
        FieldCustomizationLoader fieldCustomizationLoader = 
            applicationContext.getBean(FieldCustomizationLoader.class);  // NEW

        return new GeneralLinkService(
            config, 
            linkCentralClient, 
            schedulerService, 
            controllerService, 
            nitriteRepo,
            fieldCustomizationService,
            fieldCustomizationLoader  // NEW PARAMETER
        );
    }

    private GeneralLinkService getConveyorLinkService(
            LinkConfiguration config, 
            GeneralControllerService controllerService) {
            
        LinkCentralClient linkCentralClient = applicationContext.getBean(LinkCentralClient.class);
        SchedulerService schedulerService = applicationContext.getBean(SchedulerService.class);
        NitriteRepo nitriteRepo = applicationContext.getBean(NitriteRepo.class);
        FieldCustomizationService fieldCustomizationService = 
            applicationContext.getBean(FieldCustomizationService.class);
        FieldCustomizationLoader fieldCustomizationLoader = 
            applicationContext.getBean(FieldCustomizationLoader.class);  // NEW

        return new ConveyorLinkService(
            config, 
            linkCentralClient, 
            schedulerService, 
            controllerService, 
            nitriteRepo,
            fieldCustomizationService,
            fieldCustomizationLoader  // NEW PARAMETER
        );
    }
}
```

### Update DownloadOnlyConverterLinkService.java

```java
package com.kiwiplan.linkdevice.link;

import com.kiwiplan.linkdevice.service.expression.FieldCustomizationService;
import com.kiwiplan.linkdevice.service.expression.FieldCustomizationLoader;
// ... other imports ...

public class DownloadOnlyConverterLinkService extends GeneralLinkService {
    
    private static final Logger log = LoggerFactory.getLogger(DownloadOnlyConverterLinkService.class);

    public DownloadOnlyConverterLinkService(
            AbstractLinkConfiguration linkConfig, 
            LinkCentralClient linkCentralClient,
            SchedulerService schedulerService, 
            GeneralControllerService controllerService, 
            NitriteRepo nitriteRepo,
            FieldCustomizationService fieldCustomizationService,
            FieldCustomizationLoader fieldCustomizationLoader) {  // NEW PARAMETER
            
        super(linkConfig, linkCentralClient, schedulerService, controllerService, 
              nitriteRepo, fieldCustomizationService, fieldCustomizationLoader);  // PASS TO PARENT
    }

    // ... rest of class ...
}
```

### Update ConveyorLinkService.java

```java
package com.kiwiplan.linkdevice.link;

import com.kiwiplan.linkdevice.service.expression.FieldCustomizationService;
import com.kiwiplan.linkdevice.service.expression.FieldCustomizationLoader;
// ... other imports ...

public class ConveyorLinkService extends GeneralLinkService {
    
    public static final Logger log = LoggerFactory.getLogger(ConveyorLinkService.class);

    private LinkCentralClient linkCentralClient;

    public ConveyorLinkService(
            LinkConfiguration linkConfig, 
            LinkCentralClient linkcentralClient, 
            SchedulerService schedulerService, 
            GeneralControllerService controllerService, 
            NitriteRepo nitriteRepo,
            FieldCustomizationService fieldCustomizationService,
            FieldCustomizationLoader fieldCustomizationLoader) {  // NEW PARAMETER
            
        super(linkConfig, linkcentralClient, schedulerService, controllerService, 
              nitriteRepo, fieldCustomizationService, fieldCustomizationLoader);  // PASS TO PARENT
        this.linkCentralClient = linkcentralClient;
    }

    // ... rest of class ...
}
```

### Update CorrugatorLinkService.java

```java
package com.kiwiplan.linkdevice.link;

import com.kiwiplan.linkdevice.service.expression.FieldCustomizationService;
import com.kiwiplan.linkdevice.service.expression.FieldCustomizationLoader;
// ... other imports ...

public class CorrugatorLinkService extends LinkService {

    private final Logger log = LoggerFactory.getLogger(CorrugatorLinkService.class);

    protected final GeneralControllerService controllerService;
    protected final CircularFifoQueue<LineupDto> lineupUpdateRequestQueue;

    private final LinkCentralClient linkcentralClient;
    private final ReentrantLock reentrantLock;
    private final SchedulerService schedulerService;
    private final NitriteRepo nitriteRepo;
    private final FieldCustomizationService fieldCustomizationService;
    private final FieldCustomizationLoader fieldCustomizationLoader;  // NEW

    public CorrugatorLinkService(
            AbstractLinkConfiguration linkConfig, 
            LinkCentralClient linkcentralClient,
            SchedulerService schedulerService, 
            GeneralControllerService controllerService, 
            NitriteRepo nitriteRepo,
            FieldCustomizationService fieldCustomizationService,
            FieldCustomizationLoader fieldCustomizationLoader) {  // NEW PARAMETER

        super(linkConfig);

        this.linkcentralClient = linkcentralClient;
        this.schedulerService = schedulerService;
        this.controllerService = controllerService;
        this.reentrantLock = new ReentrantLock(true);
        this.lineupUpdateRequestQueue = new CircularFifoQueue<>(1);
        this.nitriteRepo = nitriteRepo;
        this.fieldCustomizationService = fieldCustomizationService;
        this.fieldCustomizationLoader = fieldCustomizationLoader;  // NEW ASSIGNMENT
        
        this.schedulerService.setDelay(getLinkConfig().getConfigurations().getDelay())
                .setId(getId())
                .addTask(this::scheduledTasks);
    }

    // ... rest of class (add field customization in getLineup if exists) ...
}
```

---

## Dependencies

### Maven Dependency

Add to `linkdevice-app/pom.xml`:

```xml
<dependencies>
    <!-- Existing dependencies ... -->
    
    <!-- Apache Commons JEXL for expression evaluation -->
    <dependency>
        <groupId>org.apache.commons</groupId>
        <artifactId>commons-jexl3</artifactId>
        <version>3.3</version>
    </dependency>
</dependencies>
```

### Version Information

- **Apache Commons JEXL**: 3.3 (latest stable as of 2024)
- **Java Version**: 17 (as per project configuration)
- **Spring Boot**: Parent POM managed version

---

## File Structure

### New Files to Create

```
linkdevice-app/src/main/java/com/kiwiplan/linkdevice/
├── config/
│   └── link/
│       ├── FieldCustomizationConfig.java          (NEW)
│       └── FieldCustomizationRule.java            (NEW)
└── service/
    └── expression/
        └── FieldCustomizationService.java         (NEW)
```

### Files to Modify

```
linkdevice-app/src/main/java/com/kiwiplan/linkdevice/
├── config/
│   └── link/
│       └── LinkConfigurations.java                (MODIFY)
├── link/
│   ├── GeneralLinkService.java                    (MODIFY)
│   ├── DownloadOnlyConverterLinkService.java      (MODIFY)
│   ├── ConveyorLinkService.java                   (MODIFY)
│   ├── CorrugatorLinkService.java                 (MODIFY - if applicable)
│   └── LinkServiceFactory.java                    (MODIFY)
└── pom.xml                                        (MODIFY - add JEXL dependency)
```

### Test Files to Create

```
linkdevice-app/src/test/java/com/kiwiplan/linkdevice/
├── service/
│   └── expression/
│       ├── FieldCustomizationServiceTest.java     (NEW)
│       └── FieldCustomizationLoaderTest.java      (NEW)
└── config/
    └── link/
        ├── FieldCustomizationConfigTest.java      (NEW)
        └── CustomizationSetTest.java              (NEW)

linkdevice-app/src/test/resources/
└── test-field-customizations.yml                  (NEW - Test data)
```

---

## Testing Strategy

### Unit Tests

#### 1. FieldCustomizationServiceTest.java

```java
package com.kiwiplan.linkdevice.service.expression;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.kiwiplan.linkdevice.config.link.FieldCustomizationRule;
import com.kiwiplan.linkdevice.dto.linkcentral.lineup.LineupItemDto;
import com.kiwiplan.linkdevice.dto.linkcentral.lineup.ProductSpecificationDto;
import com.kiwiplan.linkdevice.dto.linkcentral.lineup.BoardDto;
import com.kiwiplan.linkdevice.dto.linkcentral.lineup.UnitisingDto;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class FieldCustomizationServiceTest {

    private FieldCustomizationService service;
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        service = new FieldCustomizationService(objectMapper);
    }

    @Test
    @DisplayName("Should apply simple numeric field customization")
    void testSimpleNumericFieldCustomization() {
        // Given
        LineupItemDto item = createTestItem();
        item.getProductSpecification().getBoard().setLength(100.0);
        
        FieldCustomizationRule rule = new FieldCustomizationRule();
        rule.setTargetField("productSpecification.board.length");
        rule.setSrcField("productSpecification.board.length * 1.1");
        rule.setEnable(true);
        rule.setDescription("Add 10% buffer");
        
        List<FieldCustomizationRule> rules = List.of(rule);
        
        // When
        LineupItemDto result = service.applyCustomizations(item, rules);
        
        // Then
        assertNotNull(result);
        assertEquals(110.0, result.getProductSpecification().getBoard().getLength(), 0.01);
    }

    @Test
    @DisplayName("Should apply addition operation")
    void testAdditionOperation() {
        // Given
        LineupItemDto item = createTestItem();
        item.getUnitising().setPiecesRequired(100);
        
        FieldCustomizationRule rule = new FieldCustomizationRule();
        rule.setTargetField("unitising.piecesRequired");
        rule.setSrcField("unitising.piecesRequired + 10");
        rule.setEnable(true);
        
        List<FieldCustomizationRule> rules = List.of(rule);
        
        // When
        LineupItemDto result = service.applyCustomizations(item, rules);
        
        // Then
        assertEquals(110, result.getUnitising().getPiecesRequired());
    }

    @Test
    @DisplayName("Should calculate derived field from multiple sources")
    void testDerivedFieldCalculation() {
        // Given
        LineupItemDto item = createTestItem();
        item.getProductSpecification().getBoard().setLength(100.0);
        item.getProductSpecification().getBoard().setWidth(50.0);
        
        FieldCustomizationRule rule = new FieldCustomizationRule();
        rule.setTargetField("productSpecification.totalDimension");
        rule.setSrcField("productSpecification.board.length + productSpecification.board.width");
        rule.setEnable(true);
        
        List<FieldCustomizationRule> rules = List.of(rule);
        
        // When
        LineupItemDto result = service.applyCustomizations(item, rules);
        
        // Then
        // Note: This creates a new field in the map
        assertNotNull(result);
    }

    @Test
    @DisplayName("Should return original value when expression fails")
    void testReturnsOriginalValueOnExpressionError() {
        // Given
        LineupItemDto item = createTestItem();
        item.getProductSpecification().getBoard().setLength(100.0);
        
        FieldCustomizationRule rule = new FieldCustomizationRule();
        rule.setTargetField("productSpecification.board.length");
        rule.setSrcField("nonExistentField");
        rule.setExpression("*2"); // Invalid field
        rule.setEnable(true);
        
        List<FieldCustomizationRule> rules = List.of(rule);
        
        // When
        LineupItemDto result = service.applyCustomizations(item, rules);
        
        // Then
        assertEquals(100.0, result.getProductSpecification().getBoard().getLength(), 0.01);
    }

    @Test
    @DisplayName("Should skip disabled rules")
    void testSkipsDisabledRules() {
        // Given
        LineupItemDto item = createTestItem();
        item.getProductSpecification().getBoard().setLength(100.0);
        
        FieldCustomizationRule rule = new FieldCustomizationRule();
        rule.setTargetField("productSpecification.board.length");
        rule.setSrcField("productSpecification.board.length");
        rule.setExpression("*2");
        rule.setEnable(false); // Rule is disabled
        
        List<FieldCustomizationRule> rules = List.of(rule);
        
        // When
        LineupItemDto result = service.applyCustomizations(item, rules);
        
        // Then
        assertEquals(100.0, result.getProductSpecification().getBoard().getLength(), 0.01);
    }

    @Test
    @DisplayName("Should apply multiple rules in sequence")
    void testMultipleRulesInSequence() {
        // Given
        LineupItemDto item = createTestItem();
        item.getProductSpecification().getBoard().setLength(100.0);
        item.getProductSpecification().getBoard().setWidth(50.0);
        
        FieldCustomizationRule rule1 = new FieldCustomizationRule();
        rule1.setTargetField("productSpecification.board.length");
        rule1.setSrcField("productSpecification.board.length");
        rule1.setExpression("*1.1");
        rule1.setEnable(true);
        
        FieldCustomizationRule rule2 = new FieldCustomizationRule();
        rule2.setTargetField("productSpecification.board.width");
        rule2.setSrcField("productSpecification.board.width");
        rule2.setExpression("*1.2");
        rule2.setEnable(true);
        
        List<FieldCustomizationRule> rules = List.of(rule1, rule2);
        
        // When
        LineupItemDto result = service.applyCustomizations(item, rules);
        
        // Then
        assertEquals(110.0, result.getProductSpecification().getBoard().getLength(), 0.01);
        assertEquals(60.0, result.getProductSpecification().getBoard().getWidth(), 0.01);
    }

    @Test
    @DisplayName("Should handle null items gracefully")
    void testHandlesNullItemsGracefully() {
        // Given
        List<FieldCustomizationRule> rules = new ArrayList<>();
        
        // When
        LineupItemDto result = service.applyCustomizations(null, rules);
        
        // Then
        assertNull(result);
    }

    @Test
    @DisplayName("Should handle empty rules list")
    void testHandlesEmptyRulesList() {
        // Given
        LineupItemDto item = createTestItem();
        List<FieldCustomizationRule> rules = new ArrayList<>();
        
        // When
        LineupItemDto result = service.applyCustomizations(item, rules);
        
        // Then
        assertNotNull(result);
        assertEquals(item, result);
    }

    @Test
    @DisplayName("Should handle null rules list")
    void testHandlesNullRulesList() {
        // Given
        LineupItemDto item = createTestItem();
        
        // When
        LineupItemDto result = service.applyCustomizations(item, null);
        
        // Then
        assertNotNull(result);
        assertEquals(item, result);
    }

    private LineupItemDto createTestItem() {
        LineupItemDto item = new LineupItemDto();
        item.setOrderNumber("ORDER-001");
        item.setJobNumber(1);
        item.setCustomerName("TEST_CUSTOMER");
        
        ProductSpecificationDto productSpec = new ProductSpecificationDto();
        BoardDto board = new BoardDto();
        board.setLength(100.0);
        board.setWidth(50.0);
        productSpec.setBoard(board);
        item.setProductSpecification(productSpec);
        
        UnitisingDto unitising = new UnitisingDto();
        unitising.setPiecesRequired(100);
        item.setUnitising(unitising);
        
        return item;
    }
}
```

#### 2. Integration Test

```java
package com.kiwiplan.linkdevice.link;

import com.kiwiplan.linkdevice.config.link.FieldCustomizationConfig;
import com.kiwiplan.linkdevice.config.link.FieldCustomizationRule;
import com.kiwiplan.linkdevice.config.link.converter.LinkConfiguration;
import com.kiwiplan.linkdevice.dto.linkcentral.lineup.LineupItemDto;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@TestPropertySource(locations = "classpath:test-application.yml")
class FieldCustomizationIntegrationTest {

    @Autowired
    private LinkServiceFactory linkServiceFactory;

    @Test
    void testFieldCustomizationInLinkService() {
        // Test will be implemented based on actual test infrastructure
        // This demonstrates the integration pattern
        
        // Given: A link configuration with field customization
        LinkConfiguration config = new LinkConfiguration();
        // ... set up config ...
        
        FieldCustomizationConfig customization = new FieldCustomizationConfig();
        customization.setEnabled(true);
        
        FieldCustomizationRule rule = new FieldCustomizationRule();
        rule.setTargetField("productSpecification.board.length");
        rule.setSrcField("productSpecification.board.length * 1.1");
        rule.setEnable(true);
        
        customization.setRules(List.of(rule));
        config.getConfigurations().setFieldCustomization(customization);
        
        // When: Link service processes lineup items
        // Then: Field customizations should be applied
        
        assertNotNull(config.getConfigurations().getFieldCustomization());
        assertTrue(config.getConfigurations().getFieldCustomization().isEnabled());
    }
}
```

### Configuration Testings.yml
version: 1
customizations:
  - id: test_custom_1
    description: "Test customizations"
    enabled: true
    rules:
      - targetField: "productSpecification.board.length"
        enable: true
        srcField: "productSpecification.board.length * 1.1"
        description: "Test customization"
  
  - id: test_custom_2
    description: "Disabled test set"
    enabled: false
    rules:
      - targetField: "unitising.piecesRequired"
        enable: true
        srcField: "unitising.piecesRequired"
        expression: "+5"
        description: "Test buffer"
```

```yaml
# test-linkdevice.yml (partial)
version: 1
links:
  - id: test_link
    type: converter
    customizations: test_custom_1  # Reference to test set
    configurations:
      trialMode: false
      delay: 10000
      kiwiplan:
        machineId: "TEST"
        lineupSize: 5
        rules:
          - targetField: "productSpecification.board.length"
            enable: true
            srcField: "productSpecification.board.length"
            expression: "*1.1"
            description: "Test customization"
    controllers:
      machine: "test_controller"
```

### File Structure

```
linkdevice-app/src/main/resources/
├── linkdevice.yml                    # Main configuration
└── field-customizations.yml          # Separate customizations file
```

### Sample Configuration File

#### linkdevice.yml (Main Configuration)

- [ ] Field customization can be enabled/disabled via config
- [ ] Simple numeric transformations work correctly
- [ ] Conditional expressions with customer name work
- [ ] Invalid expressions return original values
- [ ] Non-overridable rules are skipped
- [ ] Multiple rules apply in sequence
- [ ] Nested field paths work correctly
#### linkdevice.yml (Main Configuration)

```yaml
version: 1

# Links Configuration
links:
  # Gopfert Converting Link 1
  - id: gopfert_converter_link_1
    description: "Gopfert Machine 1"
    type: converter
    customizations: gopfert_standard  # ← Reference to customization set
    environment: production
    configurations:
      delay: 10000
      trialMode: false
      kiwiplan:
        machineId: "1101"
        lineupSize: 5
    controllers:
      machine: "gopfert_controller_1"
  
  # Gopfert Converting Link 2 (reuses same customizations)
  - id: gopfert_converter_link_2
    description: "Gopfert Machine 2"
    type: converter
    customizations: gopfert_standard  # ← Same customization set
    environment: production
    configurations:
      delay: 10000
      trialMode: false
      kiwiplan:
        machineId: "1102"
        lineupSize: 5
    controllers:
      machine: "gopfert_controller_2"
  
  # High Precision Link (different customizations)
  - id: gopfert_high_precision
    description: "High Precision Machine"
    type: converter
    customizations: high_precision  # ← Different customization set
    environment: production
    configurations:
      delay: 10000
      trialMode: false
      kiwiplan:
        machineId: "1103"
        lineupSize: 5
    controllers:
      machine: "gopfert_controller_3"

# Controllers Configuration
controllers:
  - id: gopfert_controller_1
    description: "Gopfert Plant Floor Machine Controller 1"
    protocolName: gopfert_plant_floor_machine
    protocolVersion: "1.0"
    configurations:
      hostname: "192.168.1.100"
      port: 5000
      trialMode: false
      timeout: 5000
  
  - id: gopfert_controller_2
    description: "Gopfert Plant Floor Machine Controller 2"
    protocolName: gopfert_plant_floor_machine
    protocolVersion: "1.0"
    configurations:
      hostname: "192.168.1.101"
      port: 5000
  
  - id: gopfert_controller_3
    description: "High Precision Controller"
    protocolName: gopfert_plant_floor_machine
    protocolVersion: "1.0"
    configurations:
      hostname: "192.168.1.102"
      port: 5000
```

#### field-customizations.yml (Separate Customizations File)

```yaml
version: 1

# Customization Sets
customizations:
  # Standard Gopfert Customizations
  - id: gopfert_standard
    description: "Standard Gopfert manufacturing tolerances and safety buffers"
    enabled: true
    rules:
      # Manufacturing Tolerance - Length
      - targetField: "productSpecification.board.length"
        enable: true
        srcField: "productSpecification.board.length"
        expression: "*1.05"
        description: "Add 5% manufacturing tolerance to board length"
      
      # Manufacturing Tolerance - Width
      - targetField: "productSpecification.board.width"
        enable: true
        srcField: "productSpecification.board.width"
        expression: "*1.05"
        description: "Add 5% manufacturing tolerance to board width"
      
      # Safety Buffer for Pieces
      - targetField: "unitising.piecesRequired"
        enable: true
        srcField: "unitising.piecesRequired"
        expression: "+10"
        description: "Add 10 pieces safety buffer"
      
      # Derived Field - Total Dimension (complex expression, no operation)
      - targetField: "productSpecification.totalDimension"
        enable: true
        srcField: "productSpecification.board.length + productSpecification.board.width"
        description: "Calculate combined dimension for validation (expression field omitted for complex calculations)"
      
      # Waste Adjustment
      - targetField: "unitising.piecesRequired"
        enable: true
        srcField: "unitising.piecesRequired"
        expression: "*1.02"
        description: "Add 2% waste allowance"
  
  # High Precision Customizations
  - id: high_precision
    description: "High precision customization with higher buffers"
    enabled: true
    rules:
      - targetField: "productSpecification.board.length"
        enable: true
        srcField: "productSpecification.board.length"
        expression: "*1.08"
        description: "Add 8% buffer for high precision requirements"
      
      - targetField: "productSpecification.board.width"
        enable: true
        srcField: "productSpecification.board.width"
        expression: "*1.08"
        description: "Add 8% buffer for high precision requirements"
      
      - targetField: "unitising.piecesRequired"
        enable: true
        srcField: "unitising.piecesRequired"
        expression: "+20"
        description: "Add 20 pieces safety buffer for high precision"
  
  # Conservative Settings (can be used for testing)
  - id: conservative
    description: "Very conservative settings for critical jobs"
    enabled: true
    rules:
      - targetField: "productSpecification.board.length"
        enable: true
        srcField: "productSpecification.board.length"
        expression: "*1.15"
        description: "Add 15% buffer"
      
      - targetField: "unitising.piecesRequired"
        enable: true
        srcField: "unitising.piecesRequired"
        expression: "+50"
        description: "Add 50 pieces buffer"
  
  # Disabled Example
  - id: experimental
    description: "Experimental customizations (currently disabled)"
    enabled: false
    rules:
      - targetField: "unitising.bundles"
        enable: true
        srcField: "unitising.bundles"
        expression: "*2"
        description: "Experimental bundle calculation"
  - id: gopfert_controller_1
    description: "Gopfert Plant Floor Machine Controller"
    protocolName: gopfert_plant_floor_machine
    protocolVersion: "1.0"
    
    configurations:
      hostname: "192.168.1.100"
      port: 5000
      trialMode: false
      timeout: 5000
```

### Expected Behavior

Given a LineupItemDto from Link Central:
```json
{
  "orderNumber": "12345",
  "customerName": "ACME_CORP",
  "productSpecification": {
    "board": {
      "length": 1000.0,
      "width": 500.0
    }
  },
  "unitising": {
    "piecesRequired": 100
  }
}
```

After field customization (with the rules above):
```json
{
  "orderNumber": "12345",
  "customerName": "ACME_CORP",
  "productSpecification": {
    "board": {
      "length": 1050.0,         // 1000 * 1.05 (5% tolerance)
      "width": 525.0            // 500 * 1.05 (5% tolerance)
    },
    "totalDimension": 1575.0    // 1050 + 525 (calculated)
  },
  "unitising": {
    "piecesRequired": 112       // ((100 + 10) * 1.02) = 112 (safety buffer + waste)
  }
}
```

---

## Security & Validation

### JEXL Expression Security

1. **Strict Mode**: JEXL engine runs in strict mode, preventing access to undefined variables
2. **No Method Execution**: By default, JEXL only allows property access, not arbitrary method calls
3. **Safe Expressions**: All expressions evaluated in sandboxed context
4. **Error Isolation**: Expression errors don't propagate, original values preserved

### Configuration Validation

1. **Jakarta Bean Validation**: All configuration fields validated on load
2. **Required Fields**: `fieldPath` and `expression` are mandatory
3. **Type Validation**: Field types validated during deserialization
4. **Syntax Validation**: JEXL expressions can be pre-validated on config load

### Recommended Enhancements

For production systems, consider:

```java
// Add to FieldCustomizationService constructor
JexlSandbox sandbox = new JexlSandbox(false);
sandbox.white("com.kiwiplan.linkdevice.dto"); // Only allow DTO access
this.jexlEngine = new JexlBuilder()
    .sandbox(sandbox)
    .cache(512)
    .strict(true)
    .silent(false)
    .create();
```

---

## Benefits

### For Customers
✅ **No Code Changes**: Field customizations via configuration only  
✅ **Rapid Deployment**: Changes applied via config update, no redeployment  
✅ **Simple Expressions**: Easy-to-understand math operations (+, -, *, /)  
✅ **Safe Fallback**: Always returns original values on error  

### For Development
✅ **Single Point of Integration**: Only one interception point to maintain  
✅ **Clear Separation**: Customization logic separate from core business logic  
✅ **Easy Testing**: Service can be unit tested independently  
✅ **Audit Trail**: Full logging of applied customizations  
✅ **Reduced Complexity**: Simple expressions = fewer edge cases  

### For Operations
✅ **Configuration-Driven**: Changes don't require code deployment  
✅ **Per-Link Configuration**: Different rules for different links  
✅ **Gradual Rollout**: Can enable/disable per link or per rule  
✅ **Troubleshooting**: Clear logs show original and modified values  
✅ **Lower Risk**: Limited expression scope = predictable behavior  

---

## Implementation Checklist

### Configuration Setup
- [ ] Add JEXL dependency to `pom.xml`
- [ ] Create `FieldCustomizationConfig.java` (root config class)
- [ ] Create `CustomizationSet.java` (set of rules with ID)
- [ ] Create `FieldCustomizationRule.java` (individual rule)
- [ ] Modify `LinkConfiguration.java` to add `customizations` field
- [ ] Create `field-customizations.yml` in `src/main/resources/`
- [ ] Update main `linkdevice.yml` with `customizations:` references

### Service Implementation
- [ ] Create `FieldCustomizationLoader.java` (loads from file at startup)
- [ ] Create `FieldCustomizationService.java` (applies rules)
- [ ] Update `GeneralLinkService.java` constructor (add both dependencies)
- [ ] Update `GeneralLinkService.getLineup()` method (add field customization logic)
- [ ] Update `LinkServiceFactory.java` to inject both services
- [ ] Update `DownloadOnlyConverterLinkService.java` constructor
- [ ] Update `ConveyorLinkService.java` constructor
- [ ] Update `CorrugatorLinkService.java` constructor (if applicable)

### Testing
- [ ] Create unit tests for `FieldCustomizationService`
- [ ] Create unit tests for `FieldCustomizationLoader`
- [ ] Create configuration parsing tests
- [ ] Create `test-field-customizations.yml` test data
- [ ] Create integration test with real lineup data
- [ ] Test with disabled customization sets
- [ ] Test with missing customization IDs
- [ ] Test with invalid expressions

### Documentation
- [ ] Update README with field customization feature
- [ ] Create sample `field-customizations.yml` files
- [ ] Document configuration structure
- [ ] Document supported operations (+, -, *, /)
- [ ] Update ADO work item with design document

### Validation & Deployment
- [ ] Test reusability (multiple links with same customization ID)
- [ ] Test with real Gopfert controller
- [ ] Verify performance impact (should be minimal)
- [ ] Test hot-reload/restart behavior
- [ ] Create customer documentation
- [ ] Plan phased rollout to customer sites

---

## Next Steps

1. **Review & Approval**: Share this design with the team for review
2. **Implementation**: Create branch and implement changes
3. **Testing**: Execute comprehensive testing strategy
4. **Documentation**: Update user-facing documentation
5. **Deployment**: Plan phased rollout to customer sites

---

## References

- **ADO Work Item**: [#927532](https://dev.azure.com/advantive-devops/0e254f90-a87c-479e-abde-680deb67b476/_workitems/edit/927532)
- **Apache JEXL Documentation**: https://commons.apache.org/proper/commons-jexl/
- **Spring Boot Bean Validation**: https://spring.io/guides/gs/validating-form-input/

---

**Document Version**: 1.0  
**Last Updated**: February 10, 2026  
**Author**: Development Team  
