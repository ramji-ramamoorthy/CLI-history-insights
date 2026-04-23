#!/bin/bash
# ─────────────────────────────────────────────
#  shell-lens — Command History Analyzer
# ─────────────────────────────────────────────

set -euo pipefail

# ── Colors ──────────────────────────────────
BOLD=$(tput bold)
RESET=$(tput sgr0)
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
RED=$(tput setaf 1)

# ── Defaults ─────────────────────────────────
TOP_N=10
TODAY_ONLY=false
EXPORT_FILE=""
HISTORY_FILE=""

# ── Helpers ──────────────────────────────────
info()    { echo "${CYAN}${BOLD}==> ${RESET}${BOLD}$*${RESET}"; }
success() { echo "${GREEN}${BOLD} ✔  $*${RESET}"; }
warn()    { echo "${YELLOW}${BOLD} !  $*${RESET}"; }
error()   { echo "${RED}${BOLD} ✘  $*${RESET}" >&2; exit 1; }
header()  { echo ""; echo "${MAGENTA}${BOLD}$*${RESET}"; echo "${MAGENTA}$(printf '─%.0s' {1..40})${RESET}"; }

# ── Detect history file ───────────────────────
detect_history() {
    if [[ -n "$HISTORY_FILE" ]]; then
        [[ -f "$HISTORY_FILE" ]] || error "History file not found: $HISTORY_FILE"
        return
    fi

    local shell
    shell=$(basename "$SHELL")

    case "$shell" in
        zsh)  HISTORY_FILE="$HOME/.zsh_history" ;;
        bash) HISTORY_FILE="$HOME/.bash_history" ;;
        fish) HISTORY_FILE="$HOME/.local/share/fish/fish_history" ;;
        *)    error "Unsupported shell: $shell. Use --file to specify history file." ;;
    esac

    [[ -f "$HISTORY_FILE" ]] || error "History file not found: $HISTORY_FILE"
}

# ── Parse history into plain commands ─────────
parse_history() {
    # zsh history has timestamps like `: 1234567890:0;command`
    # bash history is plain text
    # fish history has yaml-like format
    local shell
    shell=$(basename "$SHELL")

    case "$shell" in
        zsh)
            # Strip zsh extended history timestamps
            sed 's/^: [0-9]*:[0-9]*;//' "$HISTORY_FILE"
            ;;
        fish)
            grep "^- cmd:" "$HISTORY_FILE" | sed 's/^- cmd: //'
            ;;
        *)
            cat "$HISTORY_FILE"
            ;;
    esac
}

# ── Filter to today only ──────────────────────
filter_today() {
    local shell
    shell=$(basename "$SHELL")

    if [[ "$shell" == "zsh" ]]; then
        local today_ts
        today_ts=$(date -d "today 00:00:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$(date '+%Y-%m-%d') 00:00:00" +%s)
        # Parse zsh extended history with timestamps
        awk -F';' -v ts="$today_ts" '
            /^: [0-9]+:[0-9]+;/ {
                split($0, a, ":");
                if (a[2]+0 >= ts+0) {
                    sub(/^: [0-9]+:[0-9]+;/, ""); print
                }
            }
        ' "$HISTORY_FILE"
    else
        warn "--today is most accurate with zsh extended history. Showing full history."
        parse_history
    fi
}

# ── Analyses ──────────────────────────────────
top_commands() {
    header "Top $TOP_N Most Used Commands"
    local cmds
    cmds=$(get_commands)

    echo "$cmds" \
        | awk '{print $1}' \
        | sort | uniq -c | sort -rn \
        | head -n "$TOP_N" \
        | awk '{printf "  %s%-4s%s  %s\n", "'"$BOLD"'", $1, "'"$RESET"'", $2}'
}

top_directories() {
    header "Most cd'd Directories"
    local cmds
    cmds=$(get_commands)

    local cd_cmds
    cd_cmds=$(echo "$cmds" | grep -E '^cd ' || true)

    if [[ -z "$cd_cmds" ]]; then
        echo "  No cd commands found in history."
    else
        echo "$cd_cmds" \
            | awk '{print $2}' \
            | sed "s|~|$HOME|g" \
            | sort | uniq -c | sort -rn \
            | head -n "$TOP_N" \
            | awk '{printf "  %s%-4s%s  %s\n", "'"$BOLD"'", $1, "'"$RESET"'", $2}'

        local total
        total=$(echo "$cd_cmds" | wc -l)
        echo ""
        echo "  Total cd calls: ${BOLD}${total}${RESET}"
    fi
}

weird_patterns() {
    header "Patterns & Insights"
    local cmds
    cmds=$(get_commands)

    # sudo usage
    local sudo_count
    sudo_count=$(echo "$cmds" | grep -cE '^sudo ' || true)
    echo "  ${BOLD}sudo usage:${RESET}       $sudo_count times"

    # Most used sudo subcommand
    local top_sudo
    top_sudo=$(echo "$cmds" | grep -E '^sudo ' | awk '{print $2}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2, "("$1"x)"}' || true)
    [[ -n "$top_sudo" ]] && echo "  ${BOLD}Top sudo cmd:${RESET}     $top_sudo"

    # git usage
    local git_count
    git_count=$(echo "$cmds" | grep -cE '^git ' || true)
    echo "  ${BOLD}git calls:${RESET}        $git_count times"

    # Most used git subcommand
    local top_git
    top_git=$(echo "$cmds" | grep -E '^git ' | awk '{print $2}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2, "("$1"x)"}' || true)
    [[ -n "$top_git" ]] && echo "  ${BOLD}Top git cmd:${RESET}      $top_git"

    # Clear screen spam
    local clear_count
    clear_count=$(echo "$cmds" | grep -cE '^(clear|cls)$' || true)
    echo "  ${BOLD}clear calls:${RESET}      $clear_count times"

    # Longest command
    local longest
    longest=$(echo "$cmds" | awk '{ print length, $0 }' | sort -rn | head -1 | cut -d' ' -f2-)
    echo "  ${BOLD}Longest command:${RESET}  ${longest:0:60}..."

    # Total unique commands
    local unique_count
    unique_count=$(echo "$cmds" | awk '{print $1}' | sort -u | wc -l)
    echo "  ${BOLD}Unique commands:${RESET}  $unique_count"

    # Total commands analyzed
    local total
    total=$(echo "$cmds" | wc -l)
    echo "  ${BOLD}Total analyzed:${RESET}   $total"
}

# ── Get commands (respects --today) ───────────
get_commands() {
    if [[ "$TODAY_ONLY" == true ]]; then
        filter_today
    else
        parse_history
    fi
}

# ── Export ────────────────────────────────────
do_export() {
    local outfile="$EXPORT_FILE"
    {
        echo "shell-lens report — $(date)"
        echo "History file: $HISTORY_FILE"
        echo ""
        top_commands
        echo ""
        top_directories
        echo ""
        weird_patterns
    } | sed 's/\x1b\[[0-9;]*m//g' > "$outfile"   # strip colors for file
    success "Report saved to: $outfile"
}

# ── Usage ─────────────────────────────────────
usage() {
    echo ""
    echo "${BOLD}shell-lens${RESET} — Command History Analyzer"
    echo ""
    echo "${BOLD}Usage:${RESET}"
    echo "  $0 [options]"
    echo ""
    echo "${BOLD}Options:${RESET}"
    echo "  --top N         Show top N commands (default: 10)"
    echo "  --today         Only analyze today's commands (zsh recommended)"
    echo "  --export FILE   Export report to a file"
    echo "  --file FILE     Use a custom history file"
    echo "  --help          Show this help message"
    echo ""
    echo "${BOLD}Examples:${RESET}"
    echo "  $0"
    echo "  $0 --top 20"
    echo "  $0 --today"
    echo "  $0 --top 5 --export report.txt"
    echo ""
}

# ── Arg parsing ───────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --top)
            [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]] || error "--top requires a number"
            TOP_N="$2"; shift 2 ;;
        --today)
            TODAY_ONLY=true; shift ;;
        --export)
            [[ -n "${2:-}" ]] || error "--export requires a filename"
            EXPORT_FILE="$2"; shift 2 ;;
        --file)
            [[ -n "${2:-}" ]] || error "--file requires a path"
            HISTORY_FILE="$2"; shift 2 ;;
        --help|-h)
            usage; exit 0 ;;
        *)
            error "Unknown option: $1. Use --help for usage." ;;
    esac
done

# ── Main ──────────────────────────────────────
detect_history

echo ""
info "shell-lens | Analyzing: $HISTORY_FILE"
[[ "$TODAY_ONLY" == true ]] && warn "Filtering to today's commands only"

top_commands
top_directories
weird_patterns
echo ""
success "Analysis complete."
echo ""

[[ -n "$EXPORT_FILE" ]] && do_export
