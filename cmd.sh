#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/Erikvl87/docker-languagetool.git}"

usage() {
  cat <<'EOF'
Usage:
  ./cmd.sh status                  Show branch, remotes, and working-tree status
  ./cmd.sh pull                    Fast-forward the current branch from origin
  ./cmd.sh upstream-fetch          Configure and fetch the original repository
  ./cmd.sh upstream-audit          Show ahead/behind counts and pending commits
  ./cmd.sh upstream-sync           Pull origin/main, then merge upstream/main
  ./cmd.sh commit "message"        Stage all repository changes and commit them
  ./cmd.sh push [branch]           Push a branch to the techcto fork
  ./cmd.sh pr [base]               Open a pull request with GitHub CLI
  ./cmd.sh test                    Validate shell scripts and Docker Compose

Typical upstream update:
  ./cmd.sh upstream-fetch
  ./cmd.sh upstream-audit
  ./cmd.sh upstream-sync
  ./cmd.sh test
  ./cmd.sh push main

Typical feature pull request:
  git switch -c my-change
  # edit files
  ./cmd.sh test
  ./cmd.sh commit "Describe the change"
  ./cmd.sh push my-change
  ./cmd.sh pr main
EOF
}

ensure_upstream() {
  if git -C "$REPO_DIR" remote get-url upstream >/dev/null 2>&1; then
    configured="$(git -C "$REPO_DIR" remote get-url upstream)"
    if [[ "$configured" != "$UPSTREAM_URL" ]]; then
      printf 'The upstream remote points to %s; expected %s.\n' "$configured" "$UPSTREAM_URL" >&2
      exit 1
    fi
  else
    git -C "$REPO_DIR" remote add upstream "$UPSTREAM_URL"
  fi
}

require_clean_tree() {
  if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
    echo 'The working tree must be clean before syncing upstream.' >&2
    exit 1
  fi
}

case "${1:-help}" in
  status)
    git -C "$REPO_DIR" status --short --branch
    git -C "$REPO_DIR" remote -v
    ;;
  pull)
    git -C "$REPO_DIR" pull --ff-only
    ;;
  upstream-fetch)
    ensure_upstream
    git -C "$REPO_DIR" fetch --prune upstream
    ;;
  upstream-audit)
    ensure_upstream
    git -C "$REPO_DIR" fetch --prune upstream
    git -C "$REPO_DIR" rev-list --left-right --count HEAD...upstream/main
    git -C "$REPO_DIR" log --oneline --left-right --cherry-pick HEAD...upstream/main
    ;;
  upstream-sync)
    require_clean_tree
    if [[ "$(git -C "$REPO_DIR" branch --show-current)" != "main" ]]; then
      echo 'Switch to main before syncing upstream.' >&2
      exit 1
    fi
    ensure_upstream
    git -C "$REPO_DIR" pull --ff-only origin main
    git -C "$REPO_DIR" fetch --prune upstream
    git -C "$REPO_DIR" merge --no-edit upstream/main
    ;;
  commit)
    message="${2:-}"
    if [[ -z "$message" ]]; then
      echo 'Usage: ./cmd.sh commit "message"' >&2
      exit 2
    fi
    git -C "$REPO_DIR" add --all
    git -C "$REPO_DIR" commit -m "$message"
    ;;
  push)
    branch="${2:-$(git -C "$REPO_DIR" branch --show-current)}"
    git -C "$REPO_DIR" push --set-upstream origin "$branch"
    ;;
  pr)
    base="${2:-main}"
    command -v gh >/dev/null 2>&1 || { echo 'GitHub CLI (gh) is required.' >&2; exit 1; }
    branch="$(git -C "$REPO_DIR" branch --show-current)"
    if [[ "$branch" == "$base" ]]; then
      echo "Create or switch to a feature branch before opening a pull request to $base." >&2
      exit 1
    fi
    gh pr create --repo techcto/docker-languagetool --base "$base" --head "$branch" --fill
    ;;
  test)
    bash -n "$REPO_DIR/cmd.sh" "$REPO_DIR/start.sh"
    docker compose -f "$REPO_DIR/docker-compose.yml" config --quiet
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
