# copy-that

Clipboard and scrollback tools that follow you anywhere — the same commands
work in tmux and Ghostty, on your own machine and over SSH.

The headline act is an alias:

```zsh
alias ph="capture-pane | pick-cmd | pbcopy"
```

Type `ph`, fzf-pick any command you've already run, and its full output lands
on your clipboard — no re-running it, no dragging a mouse selection across
pages of scrollback, no caring where your shell happens to be. The long-form
story is in [this blog post](https://junz.info/writing/ghostty-applescript-tmux/).

## The tools

### capture-pane

Dumps the terminal's scrollback (visible screen included) to stdout. Inside
tmux it defers to `tmux capture-pane -pS -`; in Ghostty it drives the
[AppleScript bridge](https://ghostty.org/docs/features/applescript). Anything
downstream just reads stdin and never learns which terminal it came from.

### pick-cmd

Splits a scrollback dump into command blocks (command, output, duration line),
presents them in fzf — newest first, multi-select, full-block preview — and
prints your picks to stdout.

Block boundaries are found by matching prompt markers. The defaults expect a
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

`min_time = 0` matters: the closing marker has to appear after *every*
command, or fast commands are silently dropped from the picker.

Different prompt? Set `PICK_CMD_PROMPT_START` and `PICK_CMD_PROMPT_END` to
regexes matched against the start of each line: the start regex should capture
the command text in group 1; the end regex marks the line that closes the
previous command's output.

### osc52

Reads stdin and copies it to your *local* system clipboard from anywhere —
over SSH, inside tmux, both at once — by emitting an
[OSC 52](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html) escape
sequence that the terminal emulator on your side of the connection interprets.
No X11 forwarding, no network clipboard.

Inside tmux you also need

```tmux
set -g allow-passthrough on
```

since tmux 3.3 turned passthrough off by default, and without it the sequence
is dropped silently.

The glue that makes `ph` portable is one line of zsh — any machine without a
real `pbcopy` grows one:

```zsh
(( $+commands[pbcopy] )) || alias pbcopy=osc52
```

## Install

Put the three scripts somewhere on your `PATH`:

```sh
git clone https://github.com/junzh0u/copy-that.git
ln -s "$PWD"/copy-that/capture-pane "$PWD"/copy-that/pick-cmd "$PWD"/copy-that/osc52 ~/bin/
```

Requirements: `zsh` (capture-pane), POSIX `sh` (osc52), Python 3 (stdlib only)
and [fzf](https://github.com/junegunn/fzf) (pick-cmd). The Ghostty capture
path is macOS-only; capturing otherwise requires tmux.

## License

[MIT](LICENSE)
