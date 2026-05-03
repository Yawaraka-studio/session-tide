#!/bin/zsh
set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"

readonly PROMPT='Session setup. Reply with "OK" only. No file edits, command execution, or external network access.'
readonly CONFIG_FILE="$HOME/.config/session-tide/config"
readonly LOG_DIR="$HOME/Library/Logs/session-tide"
readonly LOG_FILE="$LOG_DIR/session-tide.log"
readonly WORK_DIR="$HOME/Projects/AI Reminder"
readonly COMMAND_TIMEOUT_SECONDS=120
readonly CAFFEINATE_SECONDS=180

mkdir -p "$LOG_DIR"

log() {
  print -r -- "[$(date '+%Y-%m-%d %H:%M:%S %z')] $*" >> "$LOG_FILE"
}

network_available() {
  if command -v scutil >/dev/null 2>&1; then
    scutil -r api.anthropic.com 2>/dev/null | grep -Eq '^Reachable([[:space:]]|$)' && return 0
    scutil -r api.openai.com 2>/dev/null | grep -Eq '^Reachable([[:space:]]|$)' && return 0
    return 1
  fi

  return 0
}

load_config() {
  [[ -f "$CONFIG_FILE" ]] || return 0

  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue

    key="${line%%=*}"
    value="${line#*=}"

    case "$key" in
      SESSION_TIDE_CLAUDE_MODEL)
        SESSION_TIDE_CLAUDE_MODEL="$value"
        ;;
      SESSION_TIDE_CLAUDE_EFFORT)
        SESSION_TIDE_CLAUDE_EFFORT="$value"
        ;;
      SESSION_TIDE_CODEX_MODEL)
        SESSION_TIDE_CODEX_MODEL="$value"
        ;;
      SESSION_TIDE_CODEX_EFFORT)
        SESSION_TIDE_CODEX_EFFORT="$value"
        ;;
      *)
        log "config: ignored key=$key"
        ;;
    esac
  done < "$CONFIG_FILE"
}

classify_output() {
  local output="$1"
  local exit_status="$2"

  if (( exit_status == 0 )); then
    print -r -- "ok"
  elif (( exit_status == 124 )); then
    print -r -- "timeout"
  elif print -r -- "$output" | grep -Eiq 'usage limit|rate limit|quota|limit reached|too many requests|429|weekly limit|5.?hour|hit your limit|resets .* at'; then
    print -r -- "usage_limit"
  elif print -r -- "$output" | grep -Eiq 'auth|authentication|authorize|login|not logged in|api key|token|credential|unauthorized|forbidden|401|403'; then
    print -r -- "auth"
  elif print -r -- "$output" | grep -Eiq 'network|could not resolve|dns|connection|timed out|timeout|offline|host'; then
    print -r -- "network"
  elif print -r -- "$output" | grep -Eiq 'permission denied|operation not permitted|not allowed|approval|required permission'; then
    print -r -- "permission"
  else
    print -r -- "unknown"
  fi
}

log_output_block() {
  local name="$1"
  local output="$2"

  if [[ -z "$output" ]]; then
    log "$name: output empty"
    return
  fi

  log "$name: output begin"
  while IFS= read -r line; do
    log "$name: | $line"
  done <<< "$output"
  log "$name: output end"
}

run_with_timeout() {
  local name="$1"
  local stdin_input="$2"
  shift 2

  log "$name: start"

  local output_file
  output_file="$(mktemp "${TMPDIR:-/tmp}/session-tide.${name}.XXXXXX")"

  {
    if [[ -n "$stdin_input" ]]; then
      print -r -- "$stdin_input" | "$@"
    else
      "$@" < /dev/null
    fi
  } > "$output_file" 2>&1 &

  local pid=$!
  local elapsed=0

  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= COMMAND_TIMEOUT_SECONDS )); then
      kill "$pid" 2>/dev/null || true
      sleep 2
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      local output
      output="$(cat "$output_file" 2>/dev/null || true)"
      log "$name: failed status=124 reason=timeout elapsed=${COMMAND_TIMEOUT_SECONDS}s"
      log_output_block "$name" "$output"
      rm -f "$output_file"
      return 124
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$pid"
  local exit_status=$?
  local output
  output="$(cat "$output_file" 2>/dev/null || true)"
  rm -f "$output_file"

  local reason
  reason="$(classify_output "$output" "$exit_status")"

  if (( exit_status == 0 )); then
    log "$name: success reason=$reason elapsed=${elapsed}s"
  else
    log "$name: failed status=$exit_status reason=$reason elapsed=${elapsed}s"
  fi

  log_output_block "$name" "$output"

  return "$exit_status"
}

run_claude() {
  local claude_bin
  claude_bin="$(command -v claude 2>/dev/null || true)"

  if [[ -z "$claude_bin" ]]; then
    log "claude: skipped reason=command_not_found"
    return 127
  fi

  local model_args=()
  if [[ -n "${SESSION_TIDE_CLAUDE_MODEL:-}" ]]; then
    model_args=(--model "$SESSION_TIDE_CLAUDE_MODEL")
    log "claude: model=$SESSION_TIDE_CLAUDE_MODEL"
  else
    log "claude: model=cli_default"
  fi

  local effort_args=()
  if [[ -n "${SESSION_TIDE_CLAUDE_EFFORT:-}" ]]; then
    effort_args=(--effort "$SESSION_TIDE_CLAUDE_EFFORT")
    log "claude: effort=$SESSION_TIDE_CLAUDE_EFFORT"
  else
    log "claude: effort=cli_default"
  fi

  run_with_timeout "claude" "$PROMPT" \
    "$claude_bin" \
    --print \
    --output-format text \
    --permission-mode dontAsk \
    --disable-slash-commands \
    "${model_args[@]}" \
    "${effort_args[@]}" \
    --tools ""
}

run_codex() {
  local codex_bin
  codex_bin="$(command -v codex 2>/dev/null || true)"

  if [[ -z "$codex_bin" ]]; then
    log "codex: skipped reason=command_not_found"
    return 127
  fi

  local model_args=()
  if [[ -n "${SESSION_TIDE_CODEX_MODEL:-}" ]]; then
    model_args=(-m "$SESSION_TIDE_CODEX_MODEL")
    log "codex: model=$SESSION_TIDE_CODEX_MODEL"
  else
    log "codex: model=cli_default"
  fi

  local effort_args=()
  if [[ -n "${SESSION_TIDE_CODEX_EFFORT:-}" ]]; then
    effort_args=(-c "model_reasoning_effort=\"$SESSION_TIDE_CODEX_EFFORT\"")
    log "codex: effort=$SESSION_TIDE_CODEX_EFFORT"
  else
    log "codex: effort=cli_default"
  fi

  run_with_timeout "codex" "" \
    "$codex_bin" \
    --ask-for-approval never \
    exec \
    "${model_args[@]}" \
    "${effort_args[@]}" \
    --skip-git-repo-check \
    --sandbox read-only \
    --cd "$WORK_DIR" \
    "$PROMPT"
}

main() {
  log "session-tide: begin"
  load_config

  if ! network_available; then
    log "session-tide: skipped reason=network detail=api_hosts_unreachable"
    log "session-tide: end"
    return 0
  fi

  caffeinate -dimsu -t "$CAFFEINATE_SECONDS" &
  local caffeinate_pid=$!

  run_claude || true
  run_codex || true

  kill "$caffeinate_pid" 2>/dev/null || true
  wait "$caffeinate_pid" 2>/dev/null || true

  log "session-tide: end"
}

main "$@"
