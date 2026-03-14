# Xcode Test Command

Build, install, and test iOS apps on the simulator using XcodeBuildMCP. Captures screenshots, logs, and verifies app behavior.

## Prerequisites

- Xcode installed with command-line tools
- XcodeBuildMCP server connected
- Valid Xcode project or workspace
- At least one iOS Simulator available

## Main Tasks

### 0. Verify XcodeBuildMCP is Installed

**First, check if XcodeBuildMCP tools are available.**

Try calling:
```
mcp__xcodebuildmcp__list_simulators({})
```

**If the tool is not found or errors:**

Tell the user:
```markdown
**XcodeBuildMCP not installed**

Please install the XcodeBuildMCP server first:

\`\`\`bash
claude mcp add XcodeBuildMCP -- npx xcodebuildmcp@latest
\`\`\`

Then restart Claude Code and run `/test-xcode` again.
```

**Do NOT proceed** until XcodeBuildMCP is confirmed working.

### 1. Discover Project and Scheme

**Find available projects:**
```
mcp__xcodebuildmcp__discover_projs({})
```

**List schemes for the project:**
```
mcp__xcodebuildmcp__list_schemes({ project_path: "/path/to/Project.xcodeproj" })
```

**If argument provided:**
- Use the specified scheme name
- Or "current" to use the default/last-used scheme

### 2. Boot Simulator

**List available simulators:**
```
mcp__xcodebuildmcp__list_simulators({})
```

**Boot preferred simulator (iPhone 15 Pro recommended):**
```
mcp__xcodebuildmcp__boot_simulator({ simulator_id: "[uuid]" })
```

**Wait for simulator to be ready** before proceeding.

### 3. Build the App

**Build for iOS Simulator:**
```
mcp__xcodebuildmcp__build_ios_sim_app({
  project_path: "/path/to/Project.xcodeproj",
  scheme: "[scheme_name]"
})
```

**Handle build failures:**
- Capture build errors
- Report to user with specific error details

**On success:** Note the built app path for installation.

### 4. Install and Launch

**Install app on simulator:**
```
mcp__xcodebuildmcp__install_app_on_simulator({
  app_path: "/path/to/built/App.app",
  simulator_id: "[uuid]"
})
```

**Launch the app:**
```
mcp__xcodebuildmcp__launch_app_on_simulator({
  bundle_id: "[app.bundle.id]",
  simulator_id: "[uuid]"
})
```

**Start capturing logs:**
```
mcp__xcodebuildmcp__capture_sim_logs({
  simulator_id: "[uuid]",
  bundle_id: "[app.bundle.id]"
})
```

### 5. Test Key Screens

For each key screen in the app:

**Take screenshot:**
```
mcp__xcodebuildmcp__take_screenshot({
  simulator_id: "[uuid]",
  filename: "screen-[name].png"
})
```

**Review screenshot for:**
- UI elements rendered correctly
- No error messages visible
- Expected content displayed
- Layout looks correct

**Check logs for errors:**
```
mcp__xcodebuildmcp__get_sim_logs({ simulator_id: "[uuid]" })
```

Look for: Crashes, Exceptions, Error-level log messages, Failed network requests.

### 6. Human Verification (When Required)

Pause for human input when testing touches:

| Flow Type | What to Ask |
|-----------|-------------|
| Sign in with Apple | "Please complete Sign in with Apple on the simulator" |
| Push notifications | "Send a test push and confirm it appears" |
| In-app purchases | "Complete a sandbox purchase" |
| Camera/Photos | "Grant permissions and verify camera works" |
| Location | "Allow location access and verify map updates" |

### 7. Handle Failures

When a test fails:

1. **Document the failure:** Take screenshot, capture logs, note repro steps
2. **Ask user how to proceed:**
   - Fix now — debug and fix
   - Create todo — add for later
   - Skip — continue testing other screens

### 8. Test Summary

After all tests complete, present summary:

```markdown
## Xcode Test Results

**Project:** [project name]
**Scheme:** [scheme name]
**Simulator:** [simulator name]

### Build: Pass/Fail

### Screens Tested: [count]

| Screen | Status | Notes |
|--------|--------|-------|
| Launch | Pass | |
| Home | Pass | |

### Console Errors: [count]
### Human Verifications: [count]
### Failures: [count]
### Result: [PASS / FAIL / PARTIAL]
```

### 9. Cleanup

**Stop log capture:**
```
mcp__xcodebuildmcp__stop_log_capture({ simulator_id: "[uuid]" })
```

**Optionally shut down simulator:**
```
mcp__xcodebuildmcp__shutdown_simulator({ simulator_id: "[uuid]" })
```

## Quick Usage

```bash
# Test with default scheme
/test-xcode

# Test specific scheme
/test-xcode MyApp-Debug

# Test after making changes
/test-xcode current
```
