_gitup_pick_conflict_block() {
  emulate -L zsh

  local left_text="$1"
  local right_text="$2"
  local file_path="$3"
  local block_index="$4"
  local choice

  while true; do
    echo
    echo "Conflict in ${file_path} (block ${block_index})"
    echo "----------------------------------------"
    echo "LEFT (current branch):"
    [[ -n "$left_text" ]] && printf '%s\n' "$left_text" || echo "(empty)"
    echo "----------------------------------------"
    echo "RIGHT (${GITUP_MAIN_BRANCH:-main}):"
    [[ -n "$right_text" ]] && printf '%s\n' "$right_text" || echo "(empty)"
    echo "----------------------------------------"
    echo "Keys: [l]eft [r]ight [b]oth [e]dit [q]uit"
    printf "Choice: "
    IFS= read -r -k 1 choice
    echo

    case "$choice" in
      l|L)
        REPLY="$left_text"
        return 0
        ;;
      r|R)
        REPLY="$right_text"
        return 0
        ;;
      b|B)
        if [[ -n "$left_text" && -n "$right_text" ]]; then
          REPLY="${left_text}\n${right_text}"
        else
          REPLY="${left_text}${right_text}"
        fi
        return 0
        ;;
      e|E)
        local tmp
        tmp=$(mktemp -t gitup_conflict_XXXX) || return 1
        {
          echo "# Edit merged result below. Remove comment lines before saving."
          echo "# Left section"
          printf '%s\n' "$left_text"
          echo "# Right section"
          printf '%s\n' "$right_text"
        } > "$tmp"
        "${VISUAL:-${EDITOR:-vi}}" "$tmp"
        REPLY="$(grep -v '^#' "$tmp")"
        rm -f "$tmp"
        return 0
        ;;
      q|Q)
        return 1
        ;;
      *)
        echo "Invalid key: ${choice}"
        ;;
    esac
  done
}

_gitup_resolve_conflicted_file() {
  emulate -L zsh

  local file_path="$1"
  local content
  content="$(cat "$file_path")" || return 1

  local -a lines out left right
  lines=("${(@f)content}")
  out=()
  local i=1
  local block_index=0

  while (( i <= ${#lines} )); do
    if [[ "${lines[i]}" == '<<<<<<< '* ]]; then
      ((block_index++))
      left=()
      right=()
      ((i++))
      while (( i <= ${#lines} )) && [[ "${lines[i]}" != '=======' ]]; do
        left+=("${lines[i]}")
        ((i++))
      done
      if (( i > ${#lines} )); then
        echo "Malformed conflict marker in ${file_path}"
        return 1
      fi
      ((i++))
      while (( i <= ${#lines} )) && [[ "${lines[i]}" != '>>>>>>> '* ]]; do
        right+=("${lines[i]}")
        ((i++))
      done
      if (( i > ${#lines} )); then
        echo "Malformed conflict marker in ${file_path}"
        return 1
      fi

      local left_text right_text resolved
      left_text="${(j:\n:)left}"
      right_text="${(j:\n:)right}"
      _gitup_pick_conflict_block "$left_text" "$right_text" "$file_path" "$block_index" || return 1
      resolved="$REPLY"
      if [[ -n "$resolved" ]]; then
        local -a resolved_lines
        resolved_lines=("${(@f)resolved}")
        out+=("${resolved_lines[@]}")
      fi
      ((i++))
    else
      out+=("${lines[i]}")
      ((i++))
    fi
  done

  printf '%s\n' "${out[@]}" > "$file_path"
  git add -- "$file_path"
}

_gitup_conflict_resolver() {
  emulate -L zsh

  local -a conflicted_files
  conflicted_files=("${(@f)$(git diff --name-only --diff-filter=U)}")
  (( ${#conflicted_files} > 0 )) || return 0

  echo "Launching inline conflict resolver..."
  local file_path
  for file_path in "${conflicted_files[@]}"; do
    [[ -n "$file_path" ]] || continue
    _gitup_resolve_conflicted_file "$file_path" || return 1
  done
}

gitup() {
  emulate -L zsh

  local main_branch="${1:-main}"
  local current_branch
  current_branch=$(git symbolic-ref --quiet --short HEAD) || {
    echo "Not on a branch. Checkout a branch first."
    return 1
  }

  if [[ "$current_branch" == "$main_branch" ]]; then
    echo "Already on ${main_branch}. Checkout your feature branch first."
    return 1
  fi

  echo "Switching to ${main_branch}..."
  git checkout "$main_branch" || return 1

  echo "Pulling latest ${main_branch}..."
  git pull --ff-only || {
    echo "Pull failed. Returning to ${current_branch}."
    git checkout "$current_branch" >/dev/null 2>&1
    return 1
  }

  echo "Switching back to ${current_branch}..."
  git checkout "$current_branch" || return 1

  echo "Starting rebase onto ${main_branch}..."
  GITUP_MAIN_BRANCH="$main_branch"
  git rebase "$main_branch" || {
    while true; do
      local -a conflicted_files
      conflicted_files=("${(@f)$(git diff --name-only --diff-filter=U)}")
      if (( ${#conflicted_files} == 0 )); then
        echo "Rebase stopped without merge conflicts. Resolve manually: git status"
        return 1
      fi

      _gitup_conflict_resolver || {
        echo "Conflict resolver canceled. Resume manually with: git rebase --continue"
        return 1
      }

      git rebase --continue && break
      echo "Still conflicted or rebase needs more edits; continuing resolver..."
    done
  }
}

alias grpm='gitup main'
