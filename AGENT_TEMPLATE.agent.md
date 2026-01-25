# AGENT_TEMPLATE — Guide for Creating Agent Documentation

## Purpose
This template provides a standardized structure and rules for writing agent documentation (`.agent.md` files) for software repositories. These docs help AI agents (like GitHub Copilot or custom agents) understand the codebase, architecture, and debugging points without needing to scan the entire repo. They focus on code-level insights, avoiding operational commands.

> **💡 Recommended Model**: Based on extensive testing and comparison, **Claude Sonnet 4.5** is the recommended AI model for generating documentation using this template. It demonstrated superior performance in accuracy, depth, security awareness, and troubleshooting detail across all evaluation criteria.

## Key Principles
- **Focus on Code and Architecture**: Emphasize classes, services, endpoints, data flow, and extension points. Avoid shell commands, build instructions, or user-facing tutorials.
- **Maximize Context for Agents**: Include file paths, class names, method signatures, dependencies, and relationships. Help the agent understand "what calls what" and "where to look" for debugging.
- **Tables for Clarity**: Use Markdown tables for endpoints, services, entities, etc., to make scanning easy. Always include columns that trace code flow (e.g., "Main Service Called").
- **Update Regularly**: Reflect code changes; remove outdated suggestions. Use "Last Updated" section to track doc evolution.
- **Agent-Centric**: Tailor for AI consumption—high-level over detailed, with pointers to key files/methods. Assume the agent can read code but needs a map.
- **No Secrets or Commands**: Never include credentials or executable commands.
- **Be Explicit**: Don't assume knowledge. Spell out relationships (e.g., "X calls Y which calls Z"). Include timezone info, profile behavior, error patterns.

## Accuracy Verification Checklist

Before finalizing documentation, verify these common error-prone areas:

### Critical to Verify (Always Check Code):
- [ ] **Scheduled job times** - Check all `@Scheduled` cron expressions and timezones
- [ ] **Configuration defaults** - Verify actual default values in code, not config files
- [ ] **API endpoint HTTP methods** - Confirm GET/POST/PUT/DELETE
- [ ] **Framework/library versions** - Check pom.xml, package.json, or equivalent
- [ ] **Profile behavior** - Verify which features are enabled/disabled per profile

### High-Value to Verify:
- [ ] **Database entity relationships** - Confirm foreign keys and join tables
- [ ] **Retry logic and timeouts** - Check actual numeric values in code
- [ ] **Cache configurations** - Verify TTL, size limits, and implementation
- [ ] **Error handling patterns** - Confirm exception types and handlers

### Mark as Uncertain:
If you cannot verify a specific value (font sizes, exact retry counts, etc.), either:
- Omit the specific number, OR
- Add annotation: `(value approximately X, verify in ServiceY.method())`

## Common Pitfalls to Avoid

Learn from common documentation errors:

### Scheduling & Timing:
❌ **Don't** assume schedule times without checking code
✅ **Do** search for `@Scheduled` and verify all cron expressions
❌ **Don't** forget timezone specifications
✅ **Do** include timezone in every scheduled task description

### Configuration:
❌ **Don't** list "defaults" from example config files (often environment-specific)
✅ **Do** verify defaults in code (@Value annotations, Config classes)
❌ **Don't** mix up "example value" with "default value"
✅ **Do** clearly mark: `(default: X)` vs `(example: Y)` vs `(required, no default)`

### HTTP Endpoints:
❌ **Don't** miss unusual patterns like GET-with-body
✅ **Do** flag any non-standard REST usage with ⚠️
❌ **Don't** forget to trace which service method is called
✅ **Do** always fill "Main Service Called" column

### Code Relationships:
❌ **Don't** say "calls ServiceX" without method name
✅ **Do** be specific: "calls `ServiceX.methodName(params)`"

### File Corruption:
❌ **Don't** include stray markup, truncated tables, or garbage at end
✅ **Do** validate final markdown renders correctly

## Standard Structure
Use this outline for consistency across repositories. Adapt sections as needed, but maintain the order and headings.

### 1. Summary
- Brief overview of the application, framework, responsibilities, and key dependencies.
- Example: "This document describes the [AppName] [Framework] application. It contains high-level architecture, configuration keys, HTTP endpoints, scheduling, troubleshooting, and extension points."

### 2. Last Updated
- [Date] - [Brief note on what was updated in the agent doc, e.g., "Added Main Service Called column to HTTP endpoints table for better debugging"]

### 3. Table of Contents
- Auto-generated or manual list of sections with anchors.

### 4. Project at-a-glance
- Bullet points: Framework, language, build tool, responsibilities, external dependencies.
- Example:
  - Framework: Spring Boot (uses Web, JPA, etc.).
  - Language: Java 17.
  - Responsibilities: [Core functions].

### 5. Architecture and Data Flow
- Describe pipelines/workflows in numbered lists or bullets.
- Subsections for major flows (e.g., Request Processing, Data Synchronization, Authentication).
- Reference services/mediators by name with full paths.
- Use format: `Step → ServiceName.method() → NextServiceName.method()` to show call chains.
- Include timing info where relevant (e.g., "Scheduled at 06:30 UTC", "Cached for 10 minutes").
- Note external dependencies in flow (e.g., "Calls External API", "Writes to database `table_name`").

#### Flow Documentation Best Practices:

**Use numbered steps with explicit call chains:**
```
1. `ScheduledService.runTask()` triggers at 06:00 UTC
2. → calls `BusinessService.processRequest(params)`
3. → calls `DataService.fetch()` → queries DB
4. → calls `ExternalApiService.callApi(data)` → External API
5. → (if validation passes) calls `OutputService.sendResult(result)`
```

**Include timing and external dependencies:**
- Specify cron schedules with timezone
- Note API calls: `(calls External API - may take 2-5s)`
- Note database operations: `(writes to data_table)`
- Note retry behavior: `(retries 5x with 1s delay)`

**Show conditional branches (Critical for debugging):**

*Why: Agents debugging issues need to understand decision points. Without seeing branches, they assume linear flow and miss alternative paths where bugs often hide.*

```
6. If queue.isEmpty():
   → Generate new content (steps 3-5)
7. Else:
   → Use queued content from `QueueRepository`
```

### 5a. Data Invariants and Business Rules (if applicable)

Document critical assumptions, constraints, and business rules that agents must understand for debugging:

**Format:**
- **Invariant Name**: Clear description and where it's enforced in code
- Include what breaks if the invariant is violated

**Common Patterns to Document:**
- **Singleton entities**: "System expects exactly one config row with id=0 (enforced in `ConfigRepository.getConfig()`)"
- **Required sequences**: "Step A must complete before step B can execute (validated in `WorkflowService.validate()`)"
- **Data validation rules**: "Field X must be between Y and Z (enforced in `ValidationService.check()`)"
- **Rate limits and quotas**: "Max N API calls per hour (tracked in `RateLimitService`)"
- **Fallback behaviors**: "If primary source fails, system falls back to default (in `FallbackService.handle()`)"
- **State transitions**: "Entity can only move from state A→B→C, not A→C (enforced in `StateManager`)"

**Example:**
```
- **Config Row Singleton**: Exactly one row with id=0 in `config` table 
  - Enforced by: `ConfigRepository.getConfig()` 
  - If violated: Application fails to start or uses incorrect defaults

- **Input Length Limit**: Maximum 1000 characters for user input
  - Enforced by: `InputValidationService.validate()`
  - If violated: External API rejects the request with 400 error

- **Validation Fallback**: If validation check fails to parse, system logs warning and uses safe defaults
  - Implemented in: `ValidationService.check()`
  - Why: Prevents validation service outage from blocking all operations
```

*Why this matters: These invariants are often the root cause of "mysterious" bugs where the system behaves unexpectedly. Documenting them saves hours of debugging.*

### 6. Key Source Locations
- Bullet list of important files/packages with **full relative paths from repo root** and brief descriptions.
- Group by type (entry point, controllers, services, data layer, config, etc.).
- Include inline annotations explaining purpose (e.g., "main entry point", "handles X endpoint", "implements Y interface").
- Example format: `src/main/java/com/example/Application.java` (entry point, starts Spring context)

### 7. Quick Start (Developer)
- High-level steps only (e.g., "Build with Maven wrapper. Run with dev profile.").
- No commands.

### 8. Configuration and Secrets
- List important keys with descriptions, **default values** (if applicable), and impact/usage.
- Group by category (e.g., Database, External APIs, Caching, Security).
- Use this format:
  - **key.name** — Description (default: `value`, used by: `ServiceName.method()`).
- Note security practices explicitly (e.g., "Never commit", "Use env vars", "Rotate tokens").
- Include subsections for related config (e.g., "Notification services:", "Database connections:").

#### Security Notes (Required)

Document security-related findings in a dedicated subsection:

**Format:**
```
#### Security Audit Findings
⚠️ **Hardcoded Credentials Found**: List any secrets currently hardcoded in source
  - Location: `ServiceX.java:45` contains hardcoded API key
  - Risk: High - credentials exposed in version control
  - Recommendation: Move to environment variables

🌐 **Unauthenticated Endpoints**: Public endpoints without authentication
  - `/api/admin/delete` - No auth check (should require admin role)
  - Risk: Medium - unauthorized access possible

⚠️ **Weak Configurations**: Security anti-patterns detected
  - CORS allows all origins (`allowedOrigins: *`)
  - Risk: Low - but should restrict to known domains
```

**Use these symbols consistently:**
- 🔒 **Secret** - Never commit (API keys, passwords, tokens)
- ⚠️ **Security Risk** - Issues found in current codebase
- 🔐 **Auth Required** - Endpoint requires authentication
- 🌐 **Public Endpoint** - No authentication (explicit callout)
- 🔄 **Rotate Regularly** - Credentials needing rotation policy

### 9. Environment-Specific Configurations
- Profiles (dev, prod) with purposes.

### 10. Profiles and Scheduling
- How profiles affect behavior (e.g., scheduling enabled/disabled).

### 11. HTTP Endpoints

**Required Columns:**
| Endpoint | Method | Controller | Input type | Output type | Main Service Called | Description |

**Enhanced Version (Recommended):**
| Endpoint | Method | Controller | Input | Output | Main Service Called | Auth | Description & Notes |

**"Auth" column values:**
- 🔐 Required (specify mechanism: JWT, API Key, etc.)
- 🌐 Public (no auth)
- ⚠️ Weak/None (should have auth but doesn't)

**"Description & Notes" should include:**
- Primary purpose
- Any non-standard behavior (⚠️ GET with body)
- Common error scenarios ("Returns 404 if resource not found")
- Rate limits if applicable

**Guidelines:**
- **Main Service Called** is critical for debugging: list the primary service method(s) invoked by this endpoint.
- Include inline warnings (⚠️) for non-standard usage (e.g., GET with body, authentication bypass).
- Specify input/output fully (e.g., "Path variable: `id` (UUID)", "JSON body (`ObjectType`)", "Binary (`byte[]`) Content-Type `image/png`").
- Add notes on authentication, rate limits, or special behavior if relevant.

### 12. [Domain-Specific Flow] (e.g., Posting Flow, Authentication Flow)
- Describe integration/API usage with external systems.
- Show data transformations (e.g., "DTO → Entity → API Request").
- Table for key entities: Entity | Location | Purpose | Key Fields | Relationships.
- **Relationships** column should note foreign keys, joins, or references (e.g., "`UserEntity` has-many `OrderEntity`").
- Include API contract details (e.g., "External API expects `user_id`, `action`, `access_token`").

### 13. Database
- Dialect, defaults, switching notes.

### 14. Docker
- Presence of files, high-level purpose.

### 15. Testing
- Location and purpose.

### 16. Developer Notes and Extension Points
- Table for key services: Service | Location | Purpose | Key Methods (with signatures).
- **Key Methods** should include parameter types and return types where useful (e.g., `getUser(Long id): User`).
- Architecture notes in bullets:
  - Describe patterns (e.g., "Uses mediator pattern for X", "Follows repository pattern").
  - Note dependencies between layers (e.g., "Controllers → Services → Repositories").
  - Highlight extension points (e.g., "To add new notification channel, implement `NotifierServiceI`").
  - Document critical flows (e.g., "Auth flow: Filter → TokenService → UserRepository").

### 16a. Common Patterns and Idioms
- Document framework-specific patterns used in the codebase.
- Examples:
  - **Dependency Injection**: "Uses Spring `@Autowired` for service injection".
  - **Error Handling**: "Controllers use `@ExceptionHandler` for global error handling".
  - **Async Processing**: "Jobs run via `@Scheduled` or message queues".
  - **Caching**: "Uses `@Cacheable` on `ServiceX.method()`".
- Note any custom patterns or conventions (e.g., "All DTOs end with `Object` suffix").

### 17. Troubleshooting
- Common issues with causes/solutions (code-focused).
- Use this format:
  - **Issue**: [Brief description or error message]
    - **Cause**: [Root cause]
    - **Solution**: [Steps to resolve, referencing specific classes/config]
- Include examples:
  - **Issue**: `NullPointerException in ServiceX.method()`
    - **Cause**: Missing config key `service.x.url`
    - **Solution**: Set `service.x.url` in `application.properties` or via env var `SERVICE_X_URL`.
- Reference log locations, error codes, or stack trace patterns to watch for.

### 18. Where to Look for Logs
- Log sources (stdout, files, external systems like Splunk/ELK).
- Key messages to search for (e.g., "ERROR", "Failed to connect", specific exception types).
- List classes that emit important logs (e.g., "Search for logs from `ServiceX`, `ControllerY`").
- Note log levels and what they indicate (e.g., "WARN = retryable failure, ERROR = critical").
- Include example log patterns if helpful (e.g., "Look for `HTTP 500` followed by stack trace in `ServiceX`").

### 19. Next Steps and Suggestions
- Pending improvements (e.g., refactor endpoints, add tests).

### 20. Contact / Maintainers
- Ownership info.

## Rules for Content Creation
- **Scan the Repo**: Use tools to list files, read key classes, and understand flow. Infer from code, not assumptions.
- **Trace Dependencies**: For each service, note what it calls and what calls it. Map the dependency graph.
- **Prioritize Relevance**: Include only what's useful for debugging/implementation. Omit irrelevant details.
- **Use Consistent Naming**: Match class/package names exactly as they appear in code.
- **Provide Examples**: When describing config keys, endpoints, or methods, include example values or usage patterns.
- **Handle Changes**: When code updates, update the doc (e.g., new endpoints, removed suggestions). Update "Last Updated" section.
- **Version Control**: Commit with descriptive messages (e.g., "Update agent doc: add new /api/v2 endpoints").
- **Documentation Length**: Write as much or as little as needed to thoroughly document the system. Scale by project complexity:
  - Simple API (few endpoints, no scheduling): Brief but complete
  - Standard microservice: Moderate detail with all key flows
  - Complex system (multiple flows, integrations): Comprehensive coverage
  - **Prioritization**: Focus on core debugging value (architecture flows, endpoints, config, troubleshooting) over nice-to-have details
  - **Quality over brevity**: Better to have thorough, accurate content than incomplete summaries
- **Markdown Best Practices**: Use headers, tables, code blocks sparingly (for class/method names), links to sections.
- **Cross-Reference**: Link related sections (e.g., "See [HTTP endpoints](#http-endpoints) for API details").

## Handling Larger Ecosystems (e.g., Microservices)
For repositories with multiple services (microservices, monorepo with modules, or distributed systems), extend the doc to cover the ecosystem. Create one primary agent doc per service/repo, plus an overarching "Ecosystem Overview" section or a separate `ECOSYSTEM.agent.md` file.

### Ecosystem-Specific Additions
- **Add to Summary**: Mention the ecosystem role (e.g., "This is the [ServiceName] microservice in the [EcosystemName] platform.").
- **New Section: Ecosystem Architecture**
  - High-level diagram or description of services and interactions.
  - Communication protocols (e.g., REST, gRPC, message queues).
  - Shared components (e.g., common libraries, databases).
- **Update HTTP Endpoints Table**: Include inter-service APIs if applicable.
- **New Section: Service Dependencies**
  - Table: Dependency | Type (e.g., API, DB) | Purpose.
  - Example:
    | Dependency | Type | Purpose |
    |------------|------|---------|
    | UserService | REST API | Authenticate users |
    | SharedDB | MySQL | Store common data |
- **Cross-Service Debugging**: Note logs/endpoints for related services.
- **Next Steps**: Include ecosystem-wide improvements (e.g., "Standardize API versioning across services").

### Rules for Multi-Service Docs
- **Per-Service Focus**: Each doc covers one service's internals; link to others.
- **Shared Sections**: If repos share config/DB, reference centrally.
- **Scanning Multiple Repos**: To gather ecosystem info, scan each repo separately. Use semantic_search for high-level concepts (e.g., "microservice communication"), grep_search for specific patterns (e.g., API calls to other services), and read_file for key config files. Infer dependencies from imports, annotations (e.g., @FeignClient), or config keys. For cross-repo links, note repo URLs or shared libraries.
- **Consistency**: Use the same structure across services for easy navigation.
- **Versioning**: Note service versions and compatibility.

### Example for Microservices
- **Primary Doc**: Covers the current service as per template.
- **Ecosystem Doc**: Separate file with service map, data flow across services, and troubleshooting for inter-service issues.

## Example Adaptation
For a new repo (e.g., a Node.js API):
- Change framework to Express.js.
- Update endpoints table for REST routes.
- Add sections for middleware, database (MongoDB), etc.
- Remove irrelevant parts (e.g., if no scheduling, omit that section).

## Validation
- After writing, check for completeness: Can an agent understand the app's structure and debug issues from this doc?
- Run linters or peer review for clarity.

## Self-Validation Checklist

Before finalizing this agent documentation, answer:

### Completeness:
- [ ] Can an agent find the entry point to the application?
- [ ] Can an agent trace a request from endpoint → controller → service → database?
- [ ] Can an agent understand when scheduled jobs run and what they do?
- [ ] Can an agent locate where configuration values are used?

### Accuracy:
- [ ] Did I verify scheduling times against actual code?
- [ ] Did I verify framework/library versions?
- [ ] Did I mark any unverified specifics as "(verify in code)"?
- [ ] Did I avoid including operational commands?

### Debugging Value:
- [ ] Does troubleshooting section cover common failure modes?
- [ ] Does each endpoint show which service method it calls?
- [ ] Are data invariants and business rules documented?
- [ ] Are security issues explicitly called out?

### Readability:
- [ ] Do tables render correctly in markdown preview?
- [ ] Are file paths relative to repo root?
- [ ] Are code elements wrapped in backticks?
- [ ] Is there no garbage or truncation at file end?

---
This template ensures agent docs are useful, maintainable, and standardized. Use it as a starting point for new repositories.
