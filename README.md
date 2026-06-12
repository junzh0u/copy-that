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

The backstory — how this replaced living in tmux — is in
[this post](https://junz.info/writing/ghostty-applescript-tmux/).

## capture-pane

Dumps the terminal's scrollback, visible screen included, to stdout. Uses
`tmux capture-pane -pS -` inside tmux and the
[AppleScript bridge](https://ghostty.org/docs/features/applescript) in
Ghostty.

## pick-cmd

Splits a scrollback dump (stdin or file argument) into command blocks —
command, output, duration — and presents them in fzf: newest first,
multi-select, full-block preview. Picked blocks print to stdout.

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
command's output). Both are matched at the start of each line.

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

## Install

Put the three scripts on your `PATH`:

```sh
git clone https://github.com/junzh0u/copy-that.git
ln -s "$PWD"/copy-that/capture-pane "$PWD"/copy-that/pick-cmd "$PWD"/copy-that/osc52 ~/bin/
```

Requirements: `zsh` (capture-pane), POSIX `sh` (osc52), Python 3 (stdlib
only) and [fzf](https://github.com/junegunn/fzf) (pick-cmd). Capturing needs
tmux, or Ghostty on macOS.

## License

[MIT](LICENSE)
