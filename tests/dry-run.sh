#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf "ERROR %s\n" "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"

  grep -Fq "$expected" "$file" || fail "Expected ${file#"$ROOT_DIR"/} to contain: $expected"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq "$unexpected" "$file"; then
    fail "Did not expect ${file#"$ROOT_DIR"/} to contain: $unexpected"
  fi
}

write_forbidden_stub() {
  local stub_dir="$1"
  local command_name="$2"

  cat > "$stub_dir/$command_name" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "${STUB_LOG:?}"
exit 97
EOF
  chmod +x "$stub_dir/$command_name"
}

write_query_stub() {
  local stub_dir="$1"
  local command_name="$2"

  cat > "$stub_dir/$command_name" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$stub_dir/$command_name"
}

write_flatpak_stub() {
  local stub_dir="$1"

  cat > "$stub_dir/flatpak" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  info|remotes)
    exit 1
    ;;
  *)
    printf 'flatpak %s\n' "$*" >> "${STUB_LOG:?}"
    exit 97
    ;;
esac
EOF
  chmod +x "$stub_dir/flatpak"
}

create_stubs() {
  local stub_dir="$1"
  local command_name
  local forbidden_commands=(
    add-apt-repository
    apt-get
    curl
    dnf
    gpg
    gsettings
    mysql
    npm
    php
    sudo
    systemctl
    wget
  )

  mkdir -p "$stub_dir"

  for command_name in "${forbidden_commands[@]}"; do
    write_forbidden_stub "$stub_dir" "$command_name"
  done

  write_query_stub "$stub_dir" dpkg-query
  write_query_stub "$stub_dir" getent
  write_query_stub "$stub_dir" rpm
  write_flatpak_stub "$stub_dir"
}

run_dry_run_check() {
  local distro="$1"
  local tmpdir="$2"
  local stub_dir="$tmpdir/stubs-$distro"
  local output_file="$tmpdir/$distro.out"
  local stub_log="$tmpdir/$distro-stubs.log"
  local home_dir="$tmpdir/home-$distro"
  local expected_family="$distro"

  if [[ "$distro" == "nobara" ]]; then
    expected_family="fedora"
  fi

  mkdir -p "$home_dir"
  : > "$stub_log"
  create_stubs "$stub_dir"

  if ! (
    cd "$ROOT_DIR"
    STUB_LOG="$stub_log" \
    PATH="$stub_dir:/usr/bin:/bin" \
    HOME="$home_dir" \
    LOG_DIR="$tmpdir/logs-$distro" \
    USER="testuser" \
    XDG_CURRENT_DESKTOP="GNOME" \
      bash ./install.sh --distro="$distro" --dry-run > "$output_file" 2>&1
  ); then
    sed -n '1,200p' "$output_file" >&2 || true
    fail "Dry-run installer failed for $distro"
  fi

  assert_contains "$output_file" "Running in DRY-RUN mode - no changes will be made"
  assert_contains "$output_file" "Selected installer family: $expected_family"
  assert_contains "$output_file" "Installing terminal and desktop tools..."
  assert_contains "$output_file" "[DRY-RUN] Would install flatpak: com.github.dynobo.normcap"
  assert_contains "$output_file" "[DRY-RUN] Would configure Flameshot GNOME shortcut and screenshot portal permission"
  assert_contains "$output_file" "[DRY-RUN] Would configure Samba usershare directory"
  assert_contains "$output_file" "[DRY-RUN] Would ensure line exists in $home_dir/.bashrc"
  assert_not_contains "$output_file" "Command failed"

  if [[ -s "$stub_log" ]]; then
    sed -n '1,120p' "$stub_log" >&2 || true
    fail "Dry-run invoked mutating system commands for $distro"
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

run_dry_run_check ubuntu "$tmpdir"
run_dry_run_check fedora "$tmpdir"

printf "Dry-run safety checks passed\n"
