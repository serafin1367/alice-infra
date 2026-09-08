#!/usr/bin/env bash

# Existing checkouts keep their configured origin. Never replace a directory's data.
ensure_repository() {
  local repository="$1" url="$2" branch="$3"
  if [[ -e "$repository/.git" ]]; then
    git -C "$repository" rev-parse --git-dir >/dev/null
    return
  fi
  if [[ -e "$repository" ]]; then
    if [[ ! -d "$repository" ]] || [[ -n "$(find "$repository" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      echo "Katalog istnieje, ale nie jest pustym repozytorium Git: $repository. Nie nadpisuje danych." >&2
      return 1
    fi
  fi
  if [[ -z "$url" ]]; then
    echo "Brak adresu repozytorium dla: $repository" >&2
    return 1
  fi
  mkdir -p -- "$(dirname -- "$repository")"
  echo "Klonowanie: $repository ($branch)"
  git clone --branch "$branch" -- "$url" "$repository"
}
