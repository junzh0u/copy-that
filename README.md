# copy-that

Clipboard and scrollback tools that follow you anywhere — the same commands
work in tmux and Ghostty, on your own machine and over SSH.

The headline act is an alias:

```zsh
alias copy-that="capture-pane | pick-cmd | pbcopy"
```

Type `copy-that`, fzf-pick any command you've already run, and its full
output lands on your clipboard — even when your clipboard is three SSH hops
away. Alias it to something shorter; mine is two letters.

[![demo](https://asciinema.org/a/giRxMmOWGMK5oPgy.svg)](https://asciinema.org/a/giRxMmOWGMK5oPgy)

The deep dive — how each stage hides a difference between terminals and
hosts — is in [this post](https://junz.info/writing/copy-that/); the
backstory of leaving tmux is in
[this one](https://junz.info/writing/ghostty-applescript-tmux/).

## capture-pane

Dumps the terminal's scrollback, visible screen included, to stdout. Uses
`tmux capture-pane -pS -` inside tmux and the
[AppleScript bridge](https://ghostty.org/docs/features/applescript) in
Ghostty.

## pick-cmd

Splits a scrollback dump (stdin or file argument) into command blocks —
command, output, duration — and presents them in fzf: newest first,
multi-select, full-block preview. Picked blocks print to stdout.
(`pick-cmd --list` skips fzf and prints just the parsed command lines —
handy for checking markers.)

Boundaries are matched with prompt markers. The defaults expect a
[starship](https://starship.rs/) prompt where every command line starts with
`❯` and the next prompt opens with a `󱞩` duration line:

```toml
[character]
success_symbol = '[❯](bold green)'
error_symbol = '[❯](bold red)'

[cmd_duration]
format = '󱞩 [$duration]($style) '
min_time = 0
```

`min_time = 0` is required: the closing marker must follow *every* command,
or fast commands are silently dropped from the picker.

Different prompt? Set `PICK_CMD_PROMPT_START` (regex; group 1 captures the
command text) and `PICK_CMD_PROMPT_END` (regex; marks the line that closes a
command's output). Both are matched at the start of each line. If no line
reliably closes every command's output, set `PICK_CMD_PROMPT_END=''` —
blocks then end at the next command line instead. Or skip the regex-writing
entirely and let `copy-that-init` (below) work them out.

## osc52

Copies stdin to your local system clipboard from anywhere — over SSH, inside
tmux, both at once — via an
[OSC 52](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html) escape
sequence: your terminal emulator does the clipboard write, so no X11
forwarding is involved. Inside tmux, passthrough must be enabled (it's off by
default since tmux 3.3 and fails silently):

```tmux
set -g allow-passthrough on
```

To make the `copy-that` alias work unchanged on machines without a real
`pbcopy`, polyfill it:

```zsh
(( $+commands[pbcopy] )) || alias pbcopy=osc52
```

## copy-that-init

Don't want to write the marker regexes yourself? `copy-that-init` infers them
from your actual terminal: it captures a scrollback sample, checks whether the
current markers already parse it, and only then asks an LLM CLI to propose new
ones — each proposal is validated by running the real parser on your sample
and confirmed by you, and the result is printed as ready-to-paste `export`
lines.

```sh
copy-that-init                   # capture the live terminal (tmux or Ghostty)
copy-that-init --file dump.txt   # or use a saved scrollback
```

It shells out to whatever LLM CLI you already have — `claude -p`, `codex exec`,
and `llm` are auto-detected, in that order; set `COPY_THAT_LLM` for anything
else that reads a prompt on stdin (e.g. `COPY_THAT_LLM='ollama run llama3.2'`
for fully local inference).
No API keys are handled, and nothing is sent until it shows you the exact
sample and you say yes — scrollback can contain secrets, so read it first.

## pane-words.zsh

A zsh library (sourced, not run) that feeds the scrollback back into tab
completion: any word already on screen — filenames, hashes, hostnames, flags,
path components — becomes a completion candidate, captured via `capture-pane`
so it works in tmux and Ghostty alike. It also binds `Ctrl+]` to an fzf
picker over the same words for when you'd rather fuzzy-search than tab.

```zsh
source /path/to/copy-that/pane-words.zsh
```

Note it sets the completer chain wholesale
(`_expand_alias _complete _ignored _pane_words_completer`, so pane words only
kick in when nothing else matches). If you already customize
`zstyle ':completion:*' completer`, append `_pane_words_completer` to your
own chain instead of sourcing the zstyle line as-is.

## Install

Symlink the scripts somewhere on your `PATH` — e.g. `~/.local/bin`:

```sh
git clone https://github.com/junzh0u/copy-that.git
mkdir -p ~/.local/bin
ln -s "$PWD"/copy-that/capture-pane "$PWD"/copy-that/pick-cmd \
      "$PWD"/copy-that/osc52 "$PWD"/copy-that/copy-that-init ~/.local/bin/
```

(`~/.local/bin` isn't on `PATH` everywhere — add
`export PATH="$HOME/.local/bin:$PATH"` to your shell rc if it isn't.)

`pane-words.zsh` isn't a command — `source` it from your `.zshrc` instead
(see above).

Requirements: `zsh` (capture-pane, pane-words.zsh), POSIX `sh` (osc52),
Python 3 — stdlib only — for pick-cmd and copy-that-init,
[fzf](https://github.com/junegunn/fzf) for pick-cmd and the pane-words
`Ctrl+]` widget, and an LLM CLI only if you use copy-that-init. Capturing
needs tmux, or Ghostty on macOS.

## License

[MIT](LICENSE)
