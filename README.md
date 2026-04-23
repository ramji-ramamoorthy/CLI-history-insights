 # shell-lens

A command-line history analyzer that tells you exactly how you use your terminal — top commands, most visited directories, sudo habits, git patterns, and more.

---

## Features

- Auto-detects bash, zsh, and fish history files
- Top N most used commands (configurable)
- Most `cd`'d directories
- Insights: sudo usage, git habits, clear spam, longest command, unique command count
- `--today` flag to scope analysis to today only
- `--export` to save a clean report to a file
- Colored terminal output

---

## Usage

```bash
chmod +x shell-lens.sh
./shell-lens.sh [options]
```

### Options

| Flag | Description |
|------|-------------|
| `--top N` | Show top N commands (default: 10) |
| `--today` | Only analyze today's commands |
| `--export FILE` | Export report to a file (no colors) |
| `--file FILE` | Use a custom history file |
| `--help` | Show help message |

### Examples

```bash
./shell-lens.sh
./shell-lens.sh --top 20
./shell-lens.sh --today
./shell-lens.sh --top 5 --export report.txt
./shell-lens.sh --file ~/.my_custom_history
```

---

## Output Preview

```
==> shell-lens | Analyzing: /home/user/.zsh_history

─── Top 10 Most Used Commands ───────────────────
  142   git
  98    cd
  76    nvim
  54    sudo
  43    ls
  ...

─── Most cd'd Directories ───────────────────────
  23    ~/projects/dotfiles
  18    ~/projects/shell-lens
  12    /etc
  ...

─── Patterns & Insights ─────────────────────────
  sudo usage:       54 times
  Top sudo cmd:     pacman (31x)
  git calls:        142 times
  Top git cmd:      commit (47x)
  clear calls:      29 times
  Longest command:  ffmpeg -i input.mp4 -vf scale=1280:720 ...
  Unique commands:  87
  Total analyzed:   2,341

 ✔  Analysis complete.
```

---

## Notes

- `--today` is most accurate with zsh extended history (enabled by default on most Arch setups)
- To enable zsh extended history, add this to your `.zshrc`:
  ```bash
  setopt EXTENDED_HISTORY
  HISTFILE=~/.zsh_history
  HISTSIZE=10000
  SAVEHIST=10000
  ```
- Fish shell support reads from `~/.local/share/fish/fish_history`
- Exported reports have ANSI color codes stripped automatically

---

## License

MIT
