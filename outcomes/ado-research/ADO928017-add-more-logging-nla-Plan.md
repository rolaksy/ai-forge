# Work Item 928017: XMGEN Modern - Add More Logging to NLA
## Implementation Plan for Link Device Simulator

---

## 1. Executive Summary

**Work Item**: [928017](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/928017)  
**Title**: XMGEN Modern - Add more logging to NLA  
**Story Points**: 8  
**Status**: In Progress  
**Target Repositories**: Link Device Simulator (current), Link Device, Link Central

### User Story
> **As a** developer/support engineer  
> **I want** consistent, structured logs across NLA runtime paths (ingress/egress, encode/decode, orchestration, installer/auth touchpoints)  
> **So that** we can rapidly triage field issues, trace a message across services, and protocol

### Acceptance Criteria
1. ✅ Default production level is `info`; `debug/trace` is feature-flagged or sampling-controlled
2. ✅ **Handshake/connect/disconnect** events log at `info` level
3. ✅ **Encode/decode** steps log: start, end, duration; payload **shape** only (no raw payloads)
4. ✅ Introduce similar logging as what xmgen provided in the log file
5. ✅ Create a dedicated encode/decode logging file with log4j2 (for QA testing)

---

## 2. Current State Analysis

### 2.1 Existing Logging Infrastructure
- **Framework**: log4j2-spring.xml configuration
- **Current Level**: INFO (with STDOUT appender)
- **Log Files**:
  - Main: `${ROOT_DIR}/NLALogs/linkdevicesim/linkdevicesim.log.txt`
  - Error: `${ROOT_DIR}/NLALogs/linkdevicesim/linkdevicesim-error.log.txt`
- **Rotation**: 10MB size-based + daily time-based, 90-day retention

### 2.2 Key Code Areas Requiring Enhanced Logging

#### Protocol Layer
- **`Protocol<T>` interface**: Core encode/decode contract
- **`AbstractStringProtocol`**: Base implementation with minimal logging
  - Currently: Simple trace logging in decode, info in encode
  - Issue: No duration tracking, no structured logging
- **Protocol Implementations**: 50+ protocol mappers (Fosber, BHS, ACS, Bobst, etc.)

#### Service Layer
- **`@ServiceActivator` methods**: Entry points for message processing
- **TCP Connection Management**: `TcpConnectionManager.java`
- **Connection Health**: ACS Conveyor health tracking/reconnection handlers
- **API Service Classes**: Bridge to Link Simulator

#### Connection Lifecycle
- **TCP/UDP Servers**: Spring Integration based
- **Connection Events**: Start, stop, reconnect, health checks

---

## 3. Implementation Strategy

### 3.1 Logging Levels & Control

#### 3.1.1 Feature Flags (application.properties)
```properties
# Logging Control
logging.encode-decode.enabled=true
logging.encode-decode.level=info  # info | debug | trace
logging.connection.enabled=true
logging.connection.level=info
logging.performance.enabled=true
logging.performance.threshold-ms=100  # Log if operation exceeds threshold
```

#### 3.1.2 Log Levels Design
- **INFO**: Production-safe operational events
  - Connection lifecycle events
  - Encode/decode start/end with metadata
  - Performance metrics (duration)
  - Message type/protocol name only
- **DEBUG**: Detailed troubleshooting data
  - Payload structure/shape (field names, not values)
  - Protocol-specific details
  - Intermediate processing steps
- **TRACE**: Full diagnostic data (QA/DEV only)
  - Complete payload content (sanitized)
  - Detailed timing breakdowns

---

### 3.2 Log4j2 Configuration Changes

#### 3.2.1 New Appenders
Create dedicated appenders for different concerns:

```xml
<!-- Encode/Decode Operations Log -->
<RollingFile name="ENCODE_DECODE_APPENDER" 
             fileName="${ROOT_DIR}/NLALogs/linkdevicesim/encode-decode.log.txt"
             filePattern="${ARCHIVE_DIR}/encode-decode-%d{yyyy-MM-dd}-%i.log.gz">
    <PatternLayout pattern="${LOG_PATTERN}"/>
    <Policies>
        <TimeBasedTriggeringPolicy />
        <SizeBasedTriggeringPolicy size="10MB"/>
    </Policies>
    <DefaultRolloverStrategy max="30" compressionLevel="9">
        <Delete basePath="${ARCHIVE_DIR}" maxDepth="1">
            <IfFileName glob="encode-decode-*.log.gz" />
            <IfLastModified age="90d" />
        </Delete>
    </DefaultRolloverStrategy>
</RollingFile>

<!-- Connection Lifecycle Log -->
<RollingFile name="CONNECTION_APPENDER" 
             fileName="${ROOT_DIR}/NLALogs/linkdevicesim/connection.log.txt"
             filePattern="${ARCHIVE_DIR}/connection-%d{yyyy-MM-dd}-%i.log.gz">
    <PatternLayout pattern="${LOG_PATTERN}"/>
    <Policies>
        <TimeBasedTriggeringPolicy />
        <SizeBasedTriggeringPolicy size="5MB"/>
    </Policies>
    <DefaultRolloverStrategy max="20" compressionLevel="9"/>
</RollingFile>

<!-- Performance/Metrics Log -->
<RollingFile name="PERFORMANCE_APPENDER" 
             fileName="${ROOT_DIR}/NLALogs/linkdevicesim/performance.log.txt"
             filePattern="${ARCHIVE_DIR}/performance-%d{yyyy-MM-dd}-%i.log.gz">
    <PatternLayout pattern="${LOG_PATTERN}"/>
    <Policies>
        <TimeBasedTriggeringPolicy />
        <SizeBasedTriggeringPolicy size="10MB"/>
    </Policies>
    <DefaultRolloverStrategy max="30" compressionLevel="9"/>
</RollingFile>
```

#### 3.2.2 Logger Configuration
```xml
<Loggers>
    <!-- Encode/Decode Logger -->
    <Logger name="com.kiwiplan.protocol" level="INFO" additivity="false">
        <AppenderRef ref="STDOUT"/>
        <AppenderRef ref="ENCODE_DECODE_APPENDER"/>
        <AppenderRef ref="ERROR_APPENDER"/>
    </Logger>

    <!-- Connection Lifecycle Logger -->
    <Logger name="com.kiwiplan.tcp" level="INFO" additivity="false">
        <AppenderRef ref="STDOUT"/>
        <AppenderRef ref="CONNECTION_APPENDER"/>
        <AppenderRef ref="ERROR_APPENDER"/>
    </Logger>
    
    <Logger name="com.kiwiplan.udp" level="INFO" additivity="false">
        <AppenderRef ref="STDOUT"/>
        <AppenderRef ref="CONNECTION_APPENDER"/>
        <AppenderRef ref="ERROR_APPENDER"/>
    </Logger>

    <!-- Service Layer Logger -->
    <Logger name="com.kiwiplan.service" level="INFO" additivity="false">
        <AppenderRef ref="STDOUT"/>
        <AppenderRef ref="FILE_APPENDER"/>
        <AppenderRef ref="ERROR_APPENDER"/>
    </Logger>

    <!-- Performance Logger -->
    <Logger name="com.kiwiplan.performance" level="INFO" additivity="false">
        <AppenderRef ref="STDOUT"/>
        <AppenderRef ref="PERFORMANCE_APPENDER"/>
    </Logger>

    <!-- Root Logger -->
    <Root level="INFO">
        <AppenderRef ref="STDOUT"/>
        <AppenderRef ref="FILE_APPENDER"/>
        <AppenderRef ref="ERROR_APPENDER"/>
    </Root>
</Loggers>
```

---

### 3.3 Code Implementation Changes

#### 3.3.1 Protocol Layer Enhancements

##### A. Create Logging Utility Class
**New File**: `com.kiwiplan.util.ProtocolLogger.java`

```java
package com.kiwiplan.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class ProtocolLogger {
    private static final Logger log = LoggerFactory.getLogger("com.kiwiplan.protocol");
    private static final Logger perfLog = LoggerFactory.getLogger("com.kiwiplan.performance");
    
    // Log encode/decode with duration
    public void logEncode(String protocolName, String messageType, long durationMs) {
        log.info("ENCODE [{}] messageType={} duration={}ms", 
                 protocolName, messageType, durationMs);
        if (durationMs > getThreshold()) {
            perfLog.warn("ENCODE_SLOW [{}] messageType={} duration={}ms exceeded threshold", 
                         protocolName, messageType, durationMs);
        }
    }
    
    public void logDecode(String protocolName, String messageType, long durationMs, int payloadSize) {
        log.info("DECODE [{}] messageType={} duration={}ms payloadSize={} bytes", 
                 protocolName, messageType, durationMs, payloadSize);
        if (durationMs > getThreshold()) {
            perfLog.warn("DECODE_SLOW [{}] messageType={} duration={}ms exceeded threshold", 
                         protocolName, messageType, durationMs);
        }
    }
    
    public void logPayloadShape(String operation, String protocolName, Object payload) {
        if (log.isDebugEnabled()) {
            String shape = extractPayloadShape(payload);
            log.debug("{} [{}] payload_shape: {}", operation, protocolName, shape);
        }
    }
    
    private String extractPayloadShape(Object payload) {
        // Extract field names and types only, no values
        // Implementation: Use reflection or Jackson to get structure
        return "{ field1: String, field2: Integer, ... }";
    }
    
    private long getThreshold() {
        return 100; // ms - configurable from application.properties
    }
}
```

##### B. Update AbstractStringProtocol
**File**: `com.kiwiplan.protocol.AbstractStringProtocol`

```java
// Add logging wrapper methods
public ResponsePayload decode(String inboundRequest) {
    long startTime = System.currentTimeMillis();
    
    log.info("DECODE_START protocol={} payloadSize={} bytes", 
             getProtocolName(), inboundRequest.length());
    
    if (log.isTraceEnabled()) {
        log.trace("DECODE_START payload: {}", inboundRequest);
    }
    
    if (StringUtils.isBlank(inboundRequest)) {
        throw new IllegalArgumentException("Invalid Request Payload.");
    }
    
    try {
        ResponsePayload result = constructDto(inboundRequest);
        long duration = System.currentTimeMillis() - startTime;
        
        log.info("DECODE_END protocol={} messageType={} duration={}ms", 
                 getProtocolName(), result.getClass().getSimpleName(), duration);
        
        if (log.isDebugEnabled()) {
            logPayloadShape("DECODE", result);
        }
        
        return result;
    } catch (Exception e) {
        long duration = System.currentTimeMillis() - startTime;
        log.error("DECODE_ERROR protocol={} duration={}ms error={}", 
                  getProtocolName(), duration, e.getMessage(), e);
        throw e;
    }
}

public String encode(RequestPayload outboundDto) {
    long startTime = System.currentTimeMillis();
    
    log.info("ENCODE_START protocol={} messageType={}", 
             getProtocolName(), outboundDto.getClass().getSimpleName());
    
    if (log.isDebugEnabled()) {
        logPayloadShape("ENCODE", outboundDto);
    }
    
    if (Objects.isNull(outboundDto)) {
        throw new IllegalArgumentException("Invalid Response Payload Class.");
    }
    
    try {
        String result = getDtoFromData(outboundDto);
        long duration = System.currentTimeMillis() - startTime;
        
        log.info("ENCODE_END protocol={} messageType={} duration={}ms payloadSize={} bytes", 
                 getProtocolName(), outboundDto.getClass().getSimpleName(), 
                 duration, result.length());
        
        if (log.isTraceEnabled()) {
            log.trace("ENCODE_END payload: {}", result);
        }
        
        return result;
    } catch (Exception e) {
        long duration = System.currentTimeMillis() - startTime;
        log.error("ENCODE_ERROR protocol={} duration={}ms error={}", 
                  getProtocolName(), duration, e.getMessage(), e);
        throw e;
    }
}

private void logPayloadShape(String operation, Object payload) {
    // Extract and log structure without sensitive data
    String shape = PayloadShapeExtractor.extract(payload);
    log.debug("{} payload_shape: {}", operation, shape);
}

private String getProtocolName() {
    return protocolName + " " + protocolVersion;
}
```

#### 3.3.2 Connection Lifecycle Logging

##### A. Update TcpConnectionManager
**File**: `com.kiwiplan.tcp.client.TcpConnectionManager`

```java
// Enhance existing methods with structured logging
public void disconnect() {
    try {
        log.info("TCP_DISCONNECT_START factory={}", 
                 connectionFactory.getClass().getSimpleName());
        long startTime = System.currentTimeMillis();
        
        connectionFactory.stop();
        
        long duration = System.currentTimeMillis() - startTime;
        log.info("TCP_DISCONNECT_SUCCESS duration={}ms", duration);
    } catch (Exception e) {
        log.error("TCP_DISCONNECT_ERROR error={}", e.getMessage(), e);
        throw new TcpConnectionException("Failed to disconnect: " + e.getMessage(), e);
    }
}

public void reconnect() {
    try {
        log.info("TCP_RECONNECT_START factory={}", 
                 connectionFactory.getClass().getSimpleName());
        long startTime = System.currentTimeMillis();
        
        connectionFactory.start();
        
        long duration = System.currentTimeMillis() - startTime;
        log.info("TCP_RECONNECT_SUCCESS duration={}ms", duration);
    } catch (Exception e) {
        log.error("TCP_RECONNECT_ERROR error={}", e.getMessage(), e);
        throw new TcpConnectionException("Failed to reconnect: " + e.getMessage(), e);
    }
}
```

##### B. Add Connection Event Listener
**New File**: `com.kiwiplan.tcp.ConnectionEventLogger.java`

```java
package com.kiwiplan.tcp;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.integration.ip.tcp.connection.TcpConnectionEvent;
import org.springframework.integration.ip.tcp.connection.TcpConnectionOpenEvent;
import org.springframework.integration.ip.tcp.connection.TcpConnectionCloseEvent;
import org.springframework.integration.ip.tcp.connection.TcpConnectionExceptionEvent;
import org.springframework.stereotype.Component;

@Component
public class ConnectionEventLogger {
    
    private static final Logger log = LoggerFactory.getLogger("com.kiwiplan.tcp");
    
    @EventListener
    public void handleConnectionOpen(TcpConnectionOpenEvent event) {
        log.info("TCP_CONNECTION_OPENED connectionId={} host={} port={}", 
                 event.getConnectionId(), 
                 event.getConnectionFactoryName(),
                 extractPort(event));
    }
    
    @EventListener
    public void handleConnectionClose(TcpConnectionCloseEvent event) {
        log.info("TCP_CONNECTION_CLOSED connectionId={} host={} port={}", 
                 event.getConnectionId(),
                 event.getConnectionFactoryName(),
                 extractPort(event));
    }
    
    @EventListener
    public void handleConnectionException(TcpConnectionExceptionEvent event) {
        log.error("TCP_CONNECTION_EXCEPTION connectionId={} error={}", 
                  event.getConnectionId(),
                  event.getCause().getMessage(),
                  event.getCause());
    }
    
    private int extractPort(TcpConnectionEvent event) {
        // Extract port from connection factory
        return 0; // Implementation detail
    }
}
```

#### 3.3.3 Service Layer Enhancements

##### Update Service Classes (Example: FosberLinkV4225tService)
**File**: `com.kiwiplan.service.fosber.dryend.FosberLinkV4225tService`

```java
@Override
@ServiceActivator(inputChannel = "tcpRequestChannel")
public String processRequest(String request) {
    long startTime = System.currentTimeMillis();
    String requestId = generateRequestId(); // UUID or sequence
    
    log.info("REQUEST_START requestId={} payloadSize={} bytes", 
             requestId, request.length());
    
    try {
        if (StringUtils.isBlank(request)) {
            throw new BadRequestException("Invalid Data", request);
        }

        ResponsePayload requestDto = protocol.decode(request);
        String messageType = requestDto.getClass().getSimpleName();
        
        log.info("REQUEST_DECODED requestId={} messageType={}", requestId, messageType);
        
        // Process based on message type
        String response = processMessage(requestDto, requestId);
        
        long duration = System.currentTimeMillis() - startTime;
        log.info("REQUEST_END requestId={} messageType={} duration={}ms responseSize={} bytes", 
                 requestId, messageType, duration, response.length());
        
        return response;
        
    } catch (RuntimeException e) {
        long duration = System.currentTimeMillis() - startTime;
        log.error("REQUEST_ERROR requestId={} duration={}ms error={}", 
                  requestId, duration, e.getMessage(), e);
        return getSystemErrorRes();
    }
}

private String processMessage(ResponsePayload requestDto, String requestId) {
    // Existing message routing logic with per-operation logging
    if (requestDto instanceof AppendJobReqDto) {
        log.debug("REQUEST_TYPE requestId={} operation=addLineupItem", requestId);
        return addLineupItem(requestDto);
    } 
    // ... other message types
}
```

---

### 3.4 Payload Shape Extraction Utility

**New File**: `com.kiwiplan.util.PayloadShapeExtractor.java`

```java
package com.kiwiplan.util;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Map;

public class PayloadShapeExtractor {
    
    private static final Logger log = LoggerFactory.getLogger(PayloadShapeExtractor.class);
    
    public static String extract(Object payload) {
        if (payload == null) {
            return "null";
        }
        
        try {
            Map<String, String> shape = new HashMap<>();
            Class<?> clazz = payload.getClass();
            
            for (Field field : clazz.getDeclaredFields()) {
                field.setAccessible(true);
                String fieldName = field.getName();
                String fieldType = field.getType().getSimpleName();
                
                Object value = field.get(payload);
                String valueInfo = value == null ? "null" : 
                                   (value instanceof String ? "String[" + ((String)value).length() + "]" :
                                    value instanceof Collection ? "Collection[" + ((Collection<?>)value).size() + "]" :
                                    fieldType);
                
                shape.put(fieldName, valueInfo);
            }
            
            return new ObjectMapper().writeValueAsString(shape);
        } catch (Exception e) {
            log.warn("Failed to extract payload shape: {}", e.getMessage());
            return payload.getClass().getSimpleName();
        }
    }
}
```

---

## 4. Implementation Phases

### Phase 1: Infrastructure Setup (2 hours)
- [ ] Update log4j2-spring.xml with new appenders
- [ ] Add feature flag properties to application.properties
- [ ] Create `ProtocolLogger` utility class
- [ ] Create `PayloadShapeExtractor` utility class

### Phase 2: Protocol Layer Enhancement (4 hours)
- [ ] Update `AbstractStringProtocol` with enhanced logging
- [ ] Add timing instrumentation to encode/decode
- [ ] Implement payload shape logging (DEBUG level)
- [ ] Add performance threshold warnings

### Phase 3: Connection Lifecycle Logging (2 hours)
- [ ] Create `ConnectionEventLogger` component
- [ ] Update `TcpConnectionManager` with structured logs
- [ ] Add UDP connection logging (if applicable)
- [ ] Test connection events (open, close, error)

### Phase 4: Service Layer Enhancement (3 hours)
- [ ] Add request ID generation/tracking
- [ ] Update key service classes with enhanced logging
- [ ] Add operation-level timing
- [ ] Implement message type identification logging

### Phase 5: Testing & Validation (3 hours)
- [ ] Unit tests for logging utilities
- [ ] Integration tests with actual protocols
- [ ] Verify log file creation and rotation
- [ ] Performance impact testing
- [ ] QA testing with encode-decode log file

### Phase 6: Documentation & Deployment (1 hour)
- [ ] Update README with logging configuration
- [ ] Document log file locations and formats
- [ ] Create troubleshooting guide
- [ ] Update deployment scripts if needed

**Total Estimated Effort**: 15 hours (aligns with 8 story points)

---

## 5. Log Output Examples

### 5.1 Encode/Decode Operations
```
2026-03-04 10:15:23 INFO  AbstractStringProtocol - DECODE_START protocol=Fosber v4.2.25t payloadSize=256 bytes
2026-03-04 10:15:23 DEBUG AbstractStringProtocol - DECODE payload_shape: {msgNo:String[4], msgType:String[2], jobDetail:Object}
2026-03-04 10:15:23 INFO  AbstractStringProtocol - DECODE_END protocol=Fosber v4.2.25t messageType=AppendJobReqDto duration=45ms

2026-03-04 10:15:24 INFO  AbstractStringProtocol - ENCODE_START protocol=Fosber v4.2.25t messageType=AppendJobResponseDto
2026-03-04 10:15:24 INFO  AbstractStringProtocol - ENCODE_END protocol=Fosber v4.2.25t messageType=AppendJobResponseDto duration=12ms payloadSize=128 bytes
```

### 5.2 Connection Events
```
2026-03-04 10:10:00 INFO  ConnectionEventLogger - TCP_CONNECTION_OPENED connectionId=tcp-client-1 host=localhost port=8080
2026-03-04 10:45:00 INFO  TcpConnectionManager - TCP_DISCONNECT_START factory=TcpNetClientConnectionFactory
2026-03-04 10:45:00 INFO  TcpConnectionManager - TCP_DISCONNECT_SUCCESS duration=150ms
2026-03-04 10:45:01 INFO  TcpConnectionManager - TCP_RECONNECT_START factory=TcpNetClientConnectionFactory
2026-03-04 10:45:02 INFO  TcpConnectionManager - TCP_RECONNECT_SUCCESS duration=850ms
2026-03-04 10:45:02 INFO  ConnectionEventLogger - TCP_CONNECTION_OPENED connectionId=tcp-client-2 host=localhost port=8080
```

### 5.3 Service Request Processing
```
2026-03-04 10:15:22 INFO  FosberLinkV4225tService - REQUEST_START requestId=req-12345 payloadSize=256 bytes
2026-03-04 10:15:23 INFO  FosberLinkV4225tService - REQUEST_DECODED requestId=req-12345 messageType=AppendJobReqDto
2026-03-04 10:15:23 DEBUG FosberLinkV4225tService - REQUEST_TYPE requestId=req-12345 operation=addLineupItem
2026-03-04 10:15:24 INFO  FosberLinkV4225tService - REQUEST_END requestId=req-12345 messageType=AppendJobReqDto duration=1850ms responseSize=128 bytes
```

### 5.4 Performance Warnings
```
2026-03-04 10:15:25 WARN  ProtocolLogger - DECODE_SLOW protocol=Fosber v4.2.25t messageType=LineupListReqDto duration=250ms exceeded threshold
```

---

## 6. Testing Strategy

### 6.1 Unit Tests
- Test `ProtocolLogger` methods
- Test `PayloadShapeExtractor` with various DTOs
- Test timing accuracy
- Test log level filtering

### 6.2 Integration Tests
- Test encode/decode logging with real protocols
- Test connection event logging
- Test log file creation and appenders
- Test performance impact (should be < 5% overhead)

### 6.3 QA Testing Scenarios
1. **Normal Operation**: Verify INFO logs capture all key events
2. **Debug Mode**: Enable DEBUG and verify payload shapes logged
3. **Error Conditions**: Verify error logging with stack traces
4. **Performance**: Process 1000 messages and verify timing logs
5. **Log Rotation**: Verify files rotate at 10MB and daily
6. **Multiple Protocols**: Test with different protocol implementations

---

## 7. Configuration Management

### 7.1 Development Environment
```properties
logging.level.com.kiwiplan.protocol=DEBUG
logging.level.com.kiwiplan.tcp=DEBUG
logging.level.com.kiwiplan.service=DEBUG
logging.performance.threshold-ms=50
```

### 7.2 QA Environment
```properties
logging.level.com.kiwiplan.protocol=DEBUG
logging.level.com.kiwiplan.tcp=INFO
logging.level.com.kiwiplan.service=INFO
logging.performance.threshold-ms=100
```

### 7.3 Production Environment
```properties
logging.level.com.kiwiplan.protocol=INFO
logging.level.com.kiwiplan.tcp=INFO
logging.level.com.kiwiplan.service=INFO
logging.performance.threshold-ms=200
```

---

## 8. Performance Considerations

### 8.1 Expected Impact
- **Baseline overhead**: < 5% for INFO level logging
- **DEBUG level**: 5-10% overhead (development/QA only)
- **TRACE level**: 10-20% overhead (troubleshooting only)

### 8.2 Mitigation Strategies
1. Use parameterized logging (SLF4J)
2. Lazy evaluation with `isDebugEnabled()` checks
3. Async appenders for high-volume scenarios
4. Configurable performance thresholds
5. Sampling for trace-level logging

---

## 9. Rollout Plan

### 9.1 Development Branch
- Implement all changes
- Run full test suite
- Performance benchmarking

### 9.2 QA Environment
- Deploy with DEBUG level enabled
- Dedicated encode-decode log file testing
- Validate log rotation and archival
- Stress testing with realistic message volumes

### 9.3 Staging/Pre-Production
- Deploy with INFO level
- Monitor performance metrics
- Validate production-like log volumes

### 9.4 Production
- Deploy with INFO level
- Monitor for 24 hours
- Review log files for anomalies
- Adjust thresholds if needed

---

## 10. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Performance degradation | Medium | Benchmark before/after, use async appenders |
| Disk space consumption | Medium | Aggressive rotation/compression, 90-day retention |
| Log noise in production | Low | INFO level by default, feature flags for DEBUG |
| Sensitive data exposure | High | Payload shape only, no raw values in INFO/DEBUG |
| Breaking existing functionality | Low | Non-invasive changes, comprehensive testing |

---

## 11. Success Metrics

### 11.1 Functional
- ✅ All acceptance criteria met
- ✅ All protocols support enhanced logging
- ✅ Connection events logged consistently
- ✅ Dedicated encode-decode log file created

### 11.2 Non-Functional
- ✅ Performance overhead < 5% (INFO level)
- ✅ Test coverage maintained (>80% line, >70% branch)
- ✅ No new errors or exceptions
- ✅ Log files rotate and compress correctly

### 11.3 Operational
- ✅ Support engineers can troubleshoot issues faster
- ✅ Message tracing across services enabled
- ✅ Performance bottlenecks identifiable
- ✅ QA can validate protocol integrations easily

---

## 12. Related Work

### 12.1 Link Device Repository
- Apply same logging patterns
- Ensure consistent log format
- Correlate request IDs across services

### 12.2 Link Central Repository
- Apply same logging patterns
- End-to-end message tracing
- Unified log aggregation strategy

---

## 13. Open Questions & Decisions

1. **Request ID Propagation**: How to correlate logs across Link Device → Link Device Simulator → Link Central?
   - **Decision Needed**: Use MDC (Mapped Diagnostic Context) or message headers?

2. **Log Aggregation**: Will logs be centralized (ELK, Splunk)?
   - **Decision Needed**: Log format (JSON vs. plain text)?

3. **Sampling Strategy**: For TRACE level in production?
   - **Decision Needed**: Sampling rate (1%, 5%, 10%)?

4. **Backward Compatibility**: Do we need to maintain old log format?
   - **Decision Needed**: Breaking change acceptable?

---

## 14. Appendices

### A. Log File Structure
```
${ROOT_DIR}/NLALogs/linkdevicesim/
├── linkdevicesim.log.txt              # Main application log
├── linkdevicesim-error.log.txt        # Error log (WARN+)
├── encode-decode.log.txt              # Protocol encode/decode (NEW)
├── connection.log.txt                 # Connection lifecycle (NEW)
├── performance.log.txt                # Performance metrics (NEW)
└── archive/
    ├── linkdevicesim-2026-03-03-1.log.gz
    ├── encode-decode-2026-03-03-1.log.gz
    └── ...
```

### B. Key Classes Modified
1. `com.kiwiplan.protocol.AbstractStringProtocol`
2. `com.kiwiplan.tcp.client.TcpConnectionManager`
3. `com.kiwiplan.service.fosber.dryend.FosberLinkV4225tService` (example)
4. `src/main/resources/log4j2-spring.xml`

### C. New Classes Created
1. `com.kiwiplan.util.ProtocolLogger`
2. `com.kiwiplan.util.PayloadShapeExtractor`
3. `com.kiwiplan.tcp.ConnectionEventLogger`

---

## 15. Sign-off

**Developer**: Laks Yalamati  
**Reviewer**: [To be assigned]  
**QA**: [To be assigned]  
**Approval**: Pending review

---

**Document Version**: 1.0  
**Last Updated**: 2026-03-04  
**Status**: Draft - Awaiting Review
