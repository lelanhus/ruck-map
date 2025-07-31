# Claude Code Tools Available

Claude Code has access to a set of powerful tools that help it understand and modify your codebase:

| Tool | Description | Permission Required |
| --- | --- | --- |
| **Bash** | Executes shell commands in your environment | Yes |
| **Edit** | Makes targeted edits to specific files | Yes |
| **Glob** | Finds files based on pattern matching | No |
| **Grep** | Searches for patterns in file contents | No |
| **LS** | Lists files and directories | No |
| **MultiEdit** | Performs multiple edits on a single file atomically | Yes |
| **NotebookEdit** | Modifies Jupyter notebook cells | Yes |
| **NotebookRead** | Reads and displays Jupyter notebook contents | No |
| **Read** | Reads the contents of files | No |
| **Task** | Runs a sub-agent to handle complex, multi-step tasks | No |
| **TodoWrite** | Creates and manages structured task lists | No |
| **WebFetch** | Fetches content from a specified URL | Yes |
| **WebSearch** | Performs web searches with domain filtering | Yes |
| **Write** | Creates or overwrites files | Yes |

Permission rules can be configured using `/allowed-tools` or in permission settings.

## Extending tools with hooks

You can run custom commands before or after any tool executes using Claude Code hooks.

For example, you could automatically run a Python formatter after Claude modifies Python files, or prevent modifications to production configuration files by blocking Write operations to certain paths.

---

*Source: https://docs.anthropic.com/en/docs/claude-code/settings#tools-available-to-claude*