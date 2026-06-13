# Pane words autocomplete
# Provides words from terminal scrollback as completion candidates
# Works in tmux and Ghostty via capture-pane

_pane_words_get() {
    setopt LOCAL_OPTIONS NO_EXTENDED_GLOB

    local -a words
    words=("${(@f)$(capture-pane 2>/dev/null | grep -oE '[a-zA-Z0-9_./:~-]{2,}')}")

    # Output original words and path components
    {
        printf '%s\n' "${words[@]}"
        # For paths, also add individual components
        for w in "${words[@]}"; do
            if [[ $w == */* ]]; then
                printf '%s\n' "${(@s:/:)w}"
            fi
        done
    } | grep -E '.{2,}' | grep -E '[a-zA-Z0-9]' | sort -u
}

_pane_words_completer() {
    setopt LOCAL_OPTIONS NO_EXTENDED_GLOB

    local -a pane_words
    pane_words=("${(@f)$(_pane_words_get)}")
    [[ ${#pane_words} -eq 0 ]] && return 1

    # Exclude the current word being typed
    pane_words=(${pane_words:#$PREFIX})

    [[ ${#pane_words} -eq 0 ]] && return 1

    _wanted pane-words expl 'pane words' compadd -a pane_words
}

# Add to completer chain as fallback (after other completers)
zstyle ':completion:*' completer _expand_alias _complete _ignored _pane_words_completer

# Fzf widget for manual invocation (Ctrl+])
_pane_words_fzf() {
    setopt LOCAL_OPTIONS NO_EXTENDED_GLOB
    (( $+commands[fzf] )) || { zle -M "fzf not found"; return 1; }

    local prefix="${LBUFFER##* }"
    local selected
    selected=$(_pane_words_get | fzf --height=40% --reverse --query="$prefix")

    if [[ -n $selected ]]; then
        [[ -n $prefix ]] && LBUFFER="${LBUFFER%$prefix}"
        LBUFFER+="$selected"
    fi
    zle redisplay
}
zle -N _pane_words_fzf
bindkey '^]' _pane_words_fzf
