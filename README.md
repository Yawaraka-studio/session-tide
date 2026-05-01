# session-tide

[日本語](README.ja.md)

Lightweight scheduled health checks for Claude Code and Codex CLI on macOS.

`session-tide` uses `launchd` to run tiny session-preparation requests at 07:00, 12:00, 17:00, and 22:00. It is designed to align lightweight AI CLI checks with your daily work rhythm.

This is not intended for bulk automated usage, heavy prompts, or rate-limit bypassing. The intended use is session preparation, connectivity checks, environment health checks, and logging.

## Design

- Sends a short prompt and asks the CLI to reply with only `OK`.
- Runs Claude Code non-interactively with tools disabled.
- Runs Codex CLI non-interactively with a read-only sandbox and no approvals.
- Continues to the next CLI even if one command fails.
- Uses `caffeinate` to prevent sleep only while the check is running.
- Writes logs to `~/Library/Logs/session-tide/session-tide.log`.

## Files

- `scripts/session-tide.zsh`
  - Main runner.
- `launchd/studio.yawaraka.session-tide.plist.template`
  - `launchd` plist template.
- `scripts/install.zsh`
  - Generates and registers the `launchd` plist for the current checkout path.
- `scripts/uninstall.zsh`
  - Unregisters the installed `launchd` plist.

## Install

```zsh
./scripts/install.zsh
```

## Manual Test

```zsh
./scripts/session-tide.zsh
tail -n 80 "$HOME/Library/Logs/session-tide/session-tide.log"
```

## Model Selection

By default, `session-tide` uses each CLI's default model and effort level. You can optionally choose lighter models and lower effort levels with environment variables.

For one manual run:

```zsh
SESSION_TIDE_CLAUDE_MODEL=haiku SESSION_TIDE_CLAUDE_EFFORT=low SESSION_TIDE_CODEX_MODEL=<codex-model> SESSION_TIDE_CODEX_EFFORT=low ./scripts/session-tide.zsh
```

For scheduled `launchd` runs, create `~/.config/session-tide/config`:

```zsh
mkdir -p "$HOME/.config/session-tide"
$EDITOR "$HOME/.config/session-tide/config"
```

Example:

```zsh
SESSION_TIDE_CLAUDE_MODEL=haiku
SESSION_TIDE_CLAUDE_EFFORT=low
SESSION_TIDE_CODEX_MODEL=<codex-model>
SESSION_TIDE_CODEX_EFFORT=low
```

Use model names and effort levels accepted by your installed `claude` and `codex` CLIs.

Log entries include a `reason` field:

- `ok`: completed successfully
- `usage_limit`: usage, quota, or rate-limit related
- `auth`: login, authentication, API key, token, or credential related
- `network`: DNS, connection, timeout, offline, or host related
- `permission`: permission or approval related
- `timeout`: stopped by `session-tide`'s command timeout
- `command_not_found`: CLI command was not found
- `unknown`: any other failure

## Check Status

```zsh
launchctl print gui/$(id -u)/studio.yawaraka.session-tide
```

## Uninstall

```zsh
./scripts/uninstall.zsh
```

## License

MIT

## Sleep Behavior

If your Mac is asleep, `launchd` may not run the job at the scheduled time. If needed, combine this with macOS power scheduling.

Example:

```zsh
sudo pmset repeat wakeorpoweron MTWRFSU 06:58:00
```

If you need multiple exact wake times, Calendar events, Shortcuts, or another scheduling tool may be more practical.
