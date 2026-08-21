# Troubleshooting Guide

Common issues when running the TDD Goal Loop prototype and their solutions.

---

## Build & Environment Issues

### Issue: `mvn: command not found`

**Symptom:**
```
'mvn' is not recognized as an internal or external command
```

**Cause:** Maven is not installed or not in system PATH

**Solutions:**

1. **Install Maven:**
   - Download from [maven.apache.org](https://maven.apache.org/download.cgi)
   - Extract to a directory (e.g., `C:\Program Files\Apache\maven`)
   - Add Maven's `bin` directory to system PATH
   - Restart terminal/IDE

2. **Verify installation:**
   ```bash
   mvn -version
   ```
   Should show Maven 3.6+ and Java 21

3. **Alternative: Use IDE's embedded Maven:**
   - IntelliJ IDEA: File → Settings → Build Tools → Maven → Use bundled Maven
   - VS Code: Install "Maven for Java" extension

---

### Issue: `JAVA_HOME not set` or wrong Java version

**Symptom:**
```
Error: JAVA_HOME is not defined correctly
```
or
```
Unsupported class file major version 65
```

**Cause:** Java 21 is not installed or JAVA_HOME points to wrong version

**Solutions:**

1. **Verify Java version:**
   ```bash
   java -version
   ```
   Should show `openjdk version "21.x.x"` or similar

2. **Install Java 21 if missing:**
   - Download from [Adoptium](https://adoptium.net/) (Eclipse Temurin 21)
   - Install and note installation path (e.g., `C:\Program Files\Java\jdk-21`)

3. **Set JAVA_HOME:**
   - **Windows:**
     ```powershell
     setx JAVA_HOME "C:\Program Files\Java\jdk-21"
     ```
   - **macOS/Linux:**
     ```bash
     export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
     ```
   - Restart terminal after setting

4. **Verify JAVA_HOME:**
   ```bash
   echo $JAVA_HOME
   ```
   Should point to Java 21 installation directory

---

### Issue: `mvn clean test` fails with compilation errors

**Symptom:**
```
[ERROR] Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin:3.13.0:compile
[ERROR] Compilation failure
```

**Cause:** Source/target mismatch or missing dependencies

**Solutions:**

1. **Check pom.xml Java version:**
   ```xml
   <properties>
       <java.version>21</java.version>
       <maven.compiler.source>21</maven.compiler.source>
       <maven.compiler.target>21</maven.compiler.target>
   </properties>
   ```

2. **Clean and rebuild:**
   ```bash
   mvn clean install -U
   ```

3. **Force dependency update:**
   ```bash
   mvn clean compile -U
   ```
   The `-U` flag forces Maven to update dependencies

4. **Check IDE sync:**
   - IntelliJ: Right-click `pom.xml` → Maven → Reload Project
   - VS Code: Ctrl+Shift+P → "Java: Clean Java Language Server Workspace"

---

## Agent & Workflow Issues

### Issue: `@tdd-goal-coordinator` agent not recognized

**Symptom:**
```
Agent "tdd-goal-coordinator" not found
```
or Claude Code doesn't autocomplete the agent name

**Cause:** Agent files not detected by Claude Code or wrong file location

**Solutions:**

1. **Verify agent files exist:**
   Check `.claude/agents/tdd-goal-coordinator.md` exists in project root

2. **Check file structure:**
   Agent files must be in `.claude/agents/` directory (note the leading dot)

3. **Reload VS Code window:**
   - Ctrl+Shift+P → "Developer: Reload Window"
   - This refreshes Claude's agent detection

4. **Verify YAML frontmatter:**
   Open `.claude/agents/tdd-goal-coordinator.md` and confirm it starts with:
   ```yaml
   ---
   name: tdd-goal-coordinator
   description: Orchestrates the TDD Goal Loop workflow...
   ---
   ```

5. **Check Claude Code version:**
   - Ensure VS Code Copilot extension is up to date
   - Extensions → Copilot → Check for updates

---

### Issue: Red-verifier reports "test passed when it should fail"

**Symptom:**
Red-verifier agent reports:
```
❌ Red verification FAILED: New test passed when it should fail
```

**Cause:** Production code already exists that makes the test pass (violates red phase)

**Solutions:**

1. **Check test implementation:**
   - Did the test-writer accidentally call existing production code?
   - Is the test asserting something trivial (e.g., `1 + 1 == 2`)?

2. **Revert production code:**
   - If code-writer ran before red-verifier, undo those changes
   - Ensure test-writer output is committed **before** code-writer runs

3. **Manual verification:**
   ```bash
   mvn test -Dtest=BasketQuoteControllerTest#shouldCalculateSubtotalForSingleItem
   ```
   The specific test should fail with a meaningful error

4. **Re-run workflow from test-writer:**
   - Delete the failing test
   - Invoke test-writer again to write a proper failing test
   - Confirm red before proceeding to code-writer

---

### Issue: Green-verifier reports "tests failed after code implementation"

**Symptom:**
Green-verifier reports:
```
❌ Green verification FAILED: Tests still failing after code implementation
```

**Cause:** Code-writer's implementation has bugs or doesn't fully satisfy the test

**Solutions:**

1. **Check test failure message:**
   ```bash
   mvn test
   ```
   Read the assertion failure to understand what's wrong

2. **Manual fix:**
   - Debug the production code (add print statements, use debugger)
   - Fix the implementation to pass the test
   - Commit the fix

3. **Re-run green-verifier:**
   - After manual fix, invoke green-verifier again
   - Confirm all tests pass before proceeding to next test

4. **Common bugs:**
   - **Off-by-one errors** in calculations
   - **Null pointer exceptions** (forgot null checks)
   - **Validation logic** not matching test expectations
   - **Type mismatches** (int vs long, cents vs dollars)

---

### Issue: Slice-verifier reports "acceptance criterion not fully covered"

**Symptom:**
Slice-verifier reports:
```
⚠️  Slice verification INCOMPLETE: Acceptance criterion not fully verified
```

**Cause:** Test plan didn't cover all aspects of the acceptance criterion

**Solutions:**

1. **Review acceptance criterion:**
   - Open [SPEC.md](../SPEC.md) and re-read the GIVEN/WHEN/THEN for the current slice
   - Check example requests and responses

2. **Identify missing test cases:**
   - Are edge cases covered? (zero items, negative values, large numbers)
   - Are error cases tested? (400 Bad Request scenarios)
   - Are success cases tested? (200 OK with correct response body)

3. **Add missing tests:**
   - Invoke test-writer for each missing test case
   - Follow Red-Green cycle for each new test
   - Re-run slice-verifier after all tests added

4. **Update expected-slices.md:**
   - If test plan was incomplete, update [lab/expected-slices.md](../lab/expected-slices.md)
   - Add the missing test cases to the documented plan

---

## Test Execution Issues

### Issue: `No tests were executed!`

**Symptom:**
```
[INFO] Tests run: 0, Failures: 0, Errors: 0, Skipped: 0
```

**Cause:** Test class not following JUnit 5 conventions or wrong package structure

**Solutions:**

1. **Check test class name:**
   - Must end with `Test` (e.g., `BasketQuoteControllerTest`)
   - Or be annotated with `@Test` methods

2. **Check package structure:**
   - Test package should mirror production package
   - `src/test/java/com/example/basketquote/` should match `src/main/java/com/example/basketquote/`

3. **Verify JUnit 5 annotations:**
   ```java
   import org.junit.jupiter.api.Test;  // JUnit 5, not JUnit 4
   
   @Test
   void shouldDoSomething() {
       // test code
   }
   ```

4. **Force test discovery:**
   ```bash
   mvn clean test
   ```

---

### Issue: `MockMvc` not autowired / `NullPointerException`

**Symptom:**
```
java.lang.NullPointerException: Cannot invoke "org.springframework.test.web.servlet.MockMvc.perform(...)"
```

**Cause:** Missing `@WebMvcTest` annotation or autowiring configuration

**Solutions:**

1. **Add @WebMvcTest to test class:**
   ```java
   @WebMvcTest(BasketQuoteController.class)
   class BasketQuoteControllerTest {
       @Autowired
       private MockMvc mockMvc;
       // ...
   }
   ```

2. **Mock service dependencies:**
   ```java
   @MockBean
   private BasketQuoteService service;
   ```

3. **Verify imports:**
   ```java
   import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
   import org.springframework.beans.factory.annotation.Autowired;
   import org.springframework.boot.test.mock.mockito.MockBean;
   ```

---

## Evidence & Documentation Issues

### Issue: `lab/evidence.md` is empty after running workflow

**Symptom:**
Evidence file exists but has no agent invocation records

**Cause:** Slice-verifier didn't update the file or file permissions issue

**Solutions:**

1. **Check file permissions:**
   - Ensure `lab/evidence.md` is writable
   - On Unix: `chmod 644 lab/evidence.md`

2. **Manual evidence capture:**
   - Copy agent outputs from Claude Code chat
   - Format according to [lab/evidence.md](../lab/evidence.md) structure:
     ```markdown
     ## Slice 1: Sum basket item totals
     
     ### Test-Writer Output
     Timestamp: 2024-01-15 10:23:45
     Test: shouldCalculateSubtotalForSingleItem
     Status: ✅ Test written
     
     ### Red-Verifier Output
     Timestamp: 2024-01-15 10:24:12
     Status: ❌ Test failed as expected
     ```

3. **Re-run slice-verifier:**
   - After manual evidence entry, invoke slice-verifier
   - It should append to the file, not overwrite

---

### Issue: Links in README.md don't work

**Symptom:**
Clicking links in [README.md](../README.md) shows "File not found"

**Cause:** Relative path mismatch or files not yet generated

**Solutions:**

1. **Verify file exists:**
   - Check `src/main/java/com/example/basketquote/BasketQuoteController.java` exists
   - If not, workflow hasn't generated production code yet

2. **Check relative paths:**
   - Links should be relative to repository root
   - Use `docs/demo-script.md`, not `/docs/demo-script.md` or `./docs/demo-script.md`

3. **View in VS Code:**
   - Links work in VS Code's Markdown preview
   - May not work in GitHub web view if files aren't committed

---

## Git & Version Control Issues

### Issue: `mvn test` passes locally but fails in CI

**Symptom:**
GitHub Actions (or other CI) reports test failures, but `mvn test` passes on local machine

**Cause:** Environment differences (Java version, dependencies, file paths)

**Solutions:**

1. **Check CI Java version:**
   - Ensure CI uses Java 21 (check `.github/workflows/` config)
   - Update workflow to:
     ```yaml
     - uses: actions/setup-java@v3
       with:
         java-version: '21'
     ```

2. **Check CI Maven version:**
   - Use same Maven version as local (3.9+ recommended)

3. **Check for hardcoded paths:**
   - Tests should use relative paths, not absolute
   - Use `Paths.get("src", "test", "resources", "...")` not `"C:\\Code\\..."`

4. **Run CI locally:**
   - Use [act](https://github.com/nektos/act) to run GitHub Actions locally
   - Reproduces CI environment on local machine

---

## Getting Further Help

If issues persist:

1. **Check agent logs:**
   - Review Claude Code chat history for error messages
   - Look for exceptions or warnings in agent outputs

2. **Review AGENTS.md workflow:**
   - Ensure agents are invoked in correct order
   - Verify each agent's exit condition before proceeding

3. **Compare with working example:**
   - Review [lab/evidence.md](../lab/evidence.md) for successful execution pattern
   - Check if your workflow matches the expected sequence

4. **Ask the team:**
   - Share your evidence trail with team members
   - Post in team chat or create a GitHub issue

5. **Debug mode:**
   - Run Maven with `-X` flag for verbose output:
     ```bash
     mvn clean test -X
     ```
   - Check for dependency resolution issues or plugin errors

---

## Prevention Tips

- **Run `mvn clean test` frequently** (after each agent invocation ideally)
- **Commit after each green phase** (makes rollback easy if something breaks)
- **Review evidence trail as you go** (catch issues early)
- **Don't skip red verification** (enforces TDD discipline)
- **Keep test plans simple** (3-7 tests per slice, not 20)
- **Read failure messages carefully** (they usually tell you what's wrong)
