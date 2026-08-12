# gitup inline conflict resolver

A zsh helper that updates a feature branch from a main branch and provides an inline merge conflict resolver during rebase.

## install

Add this to your `.zshrc`:

if [[ -f "$HOME/.config/gitup/gitup.zsh" ]]; then
  source "$HOME/.config/gitup/gitup.zsh"
fi

## commands

- `gitup [main-branch]`
- `grpm` (alias for `gitup main`)

## conflict keys

- `l`: accept left (current branch)
- `r`: accept right (main branch)
- `b`: accept both
- `e`: open editor and write custom merged result
- `q`: quit resolver
