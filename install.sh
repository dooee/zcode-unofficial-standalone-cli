#!/usr/bin/env bash
# zcode-cli-install-helper
# Builds the official ZCode CLI/TUI (GLM) from the official source repo
# (zai-org/ZCode, Apache-2.0) and installs it as the `zcode` command.
#
# Requirements: Node.js >= 24 (npm bundled) and network access.
# git, curl, pnpm, corepack and even the OS tar command are NOT needed:
# downloads use Node fetch, pnpm 10.33.2 (upstream pin) and a pure-JS tar
# extractor are installed in isolation under ~/.zcode-cli/tools.
#
# Usage:
#   ./install.sh                    install the tested default tag
#   ./install.sh --tag v3.15.1      install a specific tag
#   ./install.sh --latest           install the newest official tag
#   ./install.sh update             same as --latest (skips if already current)
#   ./install.sh --lang ko          Korean messages (default: en)
#
# Environment overrides (for testing or custom layouts):
#   ZCODE_INSTALL_ROOT   (default ~/.zcode-cli)
#   ZCODE_BIN_DIR        (default ~/.local/bin)
set -euo pipefail

SCRIPT_VERSION="0.4.0"
DEFAULT_TAG="v3.15.1"
REQUIRED_NODE_MAJOR=24
PNPM_VERSION="10.33.2"
TARBALL_BASE="https://codeload.github.com/zai-org/ZCode/tar.gz/refs/tags"
TAGS_API="https://api.github.com/repos/zai-org/ZCode/tags"

ROOT="${ZCODE_INSTALL_ROOT:-$HOME/.zcode-cli}"
BIN_DIR="${ZCODE_BIN_DIR:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "$0")"

C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_RED='\033[0;31m'; C_OFF='\033[0m'
info() { printf "${C_GREEN}==>${C_OFF} %s\n" "$1"; }
warn() { printf "${C_YELLOW}WARNING:${C_OFF} %s\n" "$1"; }
die()  { printf "${C_RED}ERROR:${C_OFF} %s\n" "$1" >&2; exit 1; }

# ---------------------------------------------------------------- arg parsing
CMD="install"
TAG=""
WANT_LATEST=0
FORCE=0
LANG_OPT=""
while [ $# -gt 0 ]; do
  case "$1" in
    install|update) CMD="$1" ;;
    --latest)       WANT_LATEST=1 ;;
    --force)        FORCE=1 ;;
    --tag)          shift; [ $# -gt 0 ] || die "--tag needs a value"; TAG="$1" ;;
    --tag=*)        TAG="${1#--tag=}" ;;
    --lang)         shift; [ $# -gt 0 ] || die "--lang needs a value"; LANG_OPT="$1" ;;
    --lang=*)       LANG_OPT="${1#--lang=}" ;;
    *)              die "unknown argument: $1" ;;
  esac
  shift
done
[ -n "$TAG" ] && [ "$WANT_LATEST" = "1" ] && die "--tag and --latest cannot be combined"
if [ "$CMD" = "update" ] && [ -z "$TAG" ] && [ "$WANT_LATEST" = "0" ]; then WANT_LATEST=1; fi

# ---------------------------------------------------------------- messages (i18n)
if [ -z "$LANG_OPT" ] && [ -f "$ROOT/LANG" ]; then LANG_OPT="$(cat "$ROOT/LANG")"; fi
[ -n "$LANG_OPT" ] || LANG_OPT="en"
case "$LANG_OPT" in en|ko) ;; *) die "--lang must be en or ko" ;; esac

LANG_FILE="$SCRIPT_DIR/lang/$LANG_OPT.sh"
[ -f "$LANG_FILE" ] || LANG_FILE="$SCRIPT_DIR/lang/en.sh"
[ -f "$LANG_FILE" ] || die "language file not found: $SCRIPT_DIR/lang/en.sh"
. "$LANG_FILE"

# ---------------------------------------------------------------- pre-flight
info "$M_PREFLIGHT"
case "$(uname -s)" in
  Darwin|Linux) : ;;
  *) die "$(printf "$M_OS_FAIL" "$(uname -s)")" ;;
esac
command -v node >/dev/null 2>&1 || die "$(printf "$M_NODE_MISSING" "$REQUIRED_NODE_MAJOR")"
NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"
[ "$NODE_MAJOR" -ge "$REQUIRED_NODE_MAJOR" ] || die "$(printf "$M_NODE_OLD" "$REQUIRED_NODE_MAJOR" "$(node --version)")"
command -v npm >/dev/null 2>&1 || die "$M_NPM_MISSING"
info "$(printf "$M_ENV_OK" "$(node --version)" "$(uname -s)" "$(uname -m)")"
info "$M_LANG_NOTE"

# ---------------------------------------------------------------- tag resolution
resolve_latest_tag() {
  node -e '
  (async () => {
    const res = await fetch(process.argv[1] + "?per_page=100", {
      headers: { "User-Agent": "zcode-cli-install-helper" },
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) { console.error("HTTP " + res.status); process.exit(1); }
    const tags = (await res.json()).map(t => t.name).filter(n => /^v\d+\.\d+\.\d+$/.test(n));
    if (!tags.length) { console.error("no version tags found"); process.exit(1); }
    const ver = s => s.slice(1).split(".").map(Number);
    const cmp = (a, b) => { const x = ver(a), y = ver(b);
      for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i]; return 0; };
    tags.sort(cmp);
    console.log(tags[tags.length - 1]);
  })().catch(() => process.exit(1));
  ' "$TAGS_API"
}

INSTALLED_TAG=""
[ -f "$ROOT/INSTALLED" ] && INSTALLED_TAG="$(cat "$ROOT/INSTALLED")"

if [ "$WANT_LATEST" = "1" ]; then
  info "$M_LOOKUP"
  TAG="$(resolve_latest_tag)" || die "$M_LOOKUP_FAIL"
fi
[ -n "$TAG" ] || TAG="$DEFAULT_TAG"

if [ -n "$INSTALLED_TAG" ] && [ "$INSTALLED_TAG" = "$TAG" ] && [ "$FORCE" = "0" ]; then
  info "$(printf "$M_ALREADY" "$TAG")"
  exit 0
fi
info "$(printf "$M_TARGET" "$TAG" "${INSTALLED_TAG:-none}")"

# ---------------------------------------------------------------- pnpm (isolated)
# pnpm (build) + tar (pure-JS extraction), both isolated
info "$(printf "$M_PNPM_SETUP" "$PNPM_VERSION" "$ROOT")"
mkdir -p "$ROOT/tools" "$ROOT/bin"
npm install --prefix "$ROOT/tools" "pnpm@$PNPM_VERSION" tar --silent \
  || die "$M_PNPM_FAIL"
PNPM="$ROOT/tools/node_modules/.bin/pnpm"
[ -x "$PNPM" ] || die "$M_PNPM_FAIL"

# ---------------------------------------------------------------- download + extract
CACHE_DIR="$ROOT/cache"
mkdir -p "$CACHE_DIR"
TARBALL="$CACHE_DIR/zcode-$TAG.tar.gz"
if [ -f "$TARBALL" ]; then
  info "$(printf "$M_DL_CACHED" "$TARBALL")"
else
  info "$(printf "$M_DL" "$TARBALL_BASE/$TAG")"
  node -e '
  (async () => {
    const [url, dest] = process.argv.slice(1);
    const res = await fetch(url, {
      redirect: "follow",
      headers: { "User-Agent": "zcode-cli-install-helper" },
      signal: AbortSignal.timeout(300000),
    });
    if (!res.ok) { console.error("HTTP " + res.status + " " + url); process.exit(1); }
    const buf = Buffer.from(await res.arrayBuffer());
    require("fs").writeFileSync(dest, buf);
    console.error("(" + (buf.length / 1048576).toFixed(1) + " MB)");
  })().catch(e => { console.error(String(e && e.message || e)); process.exit(1); });
  ' "$TARBALL_BASE/$TAG" "$TARBALL" || die "$M_DL_FAIL"
fi

SRC_NEW="$ROOT/src-new"
rm -rf "$SRC_NEW"
mkdir -p "$SRC_NEW"
info "$M_EXTRACT"
node -e '
const tar = require(process.argv[1] + "/node_modules/tar");
tar.x({ file: process.argv[2], strip: 1, cwd: process.argv[3] })
  .catch(e => { console.error(String(e && e.message || e)); process.exit(1); });
' "$ROOT/tools" "$TARBALL" "$SRC_NEW" \
  || die "$(printf "$M_EXTRACT_FAIL" "$TARBALL")"

# ---------------------------------------------------------------- build
info "$M_DEPS"
( cd "$SRC_NEW" && "$PNPM" install --frozen-lockfile ) \
  || die "$(printf "$M_DEPS_FAIL" "$DEFAULT_TAG")"

info "$M_BUILD"
( cd "$SRC_NEW" && "$PNPM" --filter "@zcode/cli..." build ) \
  || die "$M_BUILD_FAIL"

BUILT="$SRC_NEW/apps/zcode-cli/packages/cli/dist/zcode.cjs"
[ -f "$BUILT" ] || die "$(printf "$M_NO_OUT" "$BUILT")"

# ---------------------------------------------------------------- swap into place
info "$M_SWAP"
rm -rf "$ROOT/src"
mv "$SRC_NEW" "$ROOT/src"

# self-update assets: installer copy + shared update checker
# (skip the copy when this script already runs from $ROOT/bin, e.g. via apply)
if [ "$SCRIPT_PATH" != "$ROOT/bin/install.sh" ]; then
  cp "$SCRIPT_PATH" "$ROOT/bin/install.sh"
fi
if [ "$SCRIPT_DIR/lang" != "$ROOT/bin/lang" ]; then
  mkdir -p "$ROOT/bin/lang"
  cp "$SCRIPT_DIR/lang/"*.sh "$ROOT/bin/lang/"
fi
cat > "$ROOT/bin/.check-update.tmp" <<'CHECKER_EOF'
#!/usr/bin/env bash
# Exit codes: 0 = up to date, 3 = newer tag exists, 2 = check failed.
set -u
ROOT_DIR="__ROOT__"
TAGS_API="https://api.github.com/repos/zai-org/ZCode/tags"
INSTALLED="$(cat "$ROOT_DIR/INSTALLED" 2>/dev/null || echo none)"
OUT="$(node -e '
const [api, installed] = process.argv.slice(1);
(async () => {
  const res = await fetch(api + "?per_page=100", {
    headers: { "User-Agent": "zcode-cli-install-helper" },
    signal: AbortSignal.timeout(4000),
  });
  if (!res.ok) process.exit(2);
  const tags = (await res.json()).map(t => t.name).filter(n => /^v\d+\.\d+\.\d+$/.test(n));
  const ver = s => s.slice(1).split(".").map(Number);
  const cmp = (a, b) => { const x = ver(a), y = ver(b);
    for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i]; return 0; };
  tags.sort(cmp);
  const latest = tags[tags.length - 1];
  if (!latest) process.exit(2);
  console.log(latest);
  process.exit(latest === installed ? 0 : 3);
})().catch(() => process.exit(2));
' "$TAGS_API" "$INSTALLED" 2>/dev/null)"
RC=$?
echo "$OUT"
exit $RC
CHECKER_EOF
sed -i '' "s|__ROOT__|$ROOT|g" "$ROOT/bin/.check-update.tmp"
chmod +x "$ROOT/bin/.check-update.tmp"
mv -f "$ROOT/bin/.check-update.tmp" "$ROOT/bin/zcode-check-update"

# zcode wrapper: daily update notice, then exec the official binary untouched
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/.zcode.tmp" <<'WRAPPER_EOF'
#!/usr/bin/env bash
# Generated by zcode-cli-install-helper. Checks (at most once a day) whether a newer
# official ZCode tag has been released, prints a notice if so, then execs the
# official binary with all arguments unchanged.
set -u
ROOT="__ROOT__"
OFFICIAL="$ROOT/src/apps/zcode-cli/packages/cli/dist/zcode.cjs"
if [ ! -f "$OFFICIAL" ]; then
  echo "zcode: installation files are missing. Reinstall with zcode-cli-install-helper." >&2
  exit 1
fi
NOW="$(date +%s)"
LAST="$(cat "$ROOT/update-check.cache" 2>/dev/null || echo 0)"
if [ $((NOW - LAST)) -ge 86400 ]; then
  LATEST="$("$ROOT/bin/zcode-check-update" 2>/dev/null)"; RC=$?
  if [ "$RC" = "3" ] && [ -n "$LATEST" ]; then
    CUR="$(cat "$ROOT/INSTALLED" 2>/dev/null || echo unknown)"
    LANG_="${ZCODE_LANG:-$(cat "$ROOT/LANG" 2>/dev/null || echo en)}"
    if [ "$LANG_" = "ko" ]; then
      printf '알림: ZCode %s 가 출시되었습니다 (설치된 버전: %s).\nzcode-cli-install-helper 업데이트가 필요합니다. 실행: zcode-update --apply\n' "$LATEST" "$CUR" >&2
    else
      printf 'Notice: a new ZCode version %s is available (installed: %s).\nzcode-cli-install-helper needs an update. Run: zcode-update --apply\n' "$LATEST" "$CUR" >&2
    fi
  fi
  date +%s > "$ROOT/update-check.cache" 2>/dev/null || true
fi
exec "$OFFICIAL" "$@"
WRAPPER_EOF
sed -i '' "s|__ROOT__|$ROOT|g" "$BIN_DIR/.zcode.tmp"
chmod +x "$BIN_DIR/.zcode.tmp"
mv -f "$BIN_DIR/.zcode.tmp" "$BIN_DIR/zcode"

# zcode-update: check on demand, apply only when asked
cat > "$BIN_DIR/.zcode-update.tmp" <<'UPDATER_EOF'
#!/usr/bin/env bash
# Generated by zcode-cli-install-helper.
#   zcode-update          show installed vs latest official tag
#   zcode-update --apply  rebuild with the latest official tag
set -u
ROOT="__ROOT__"
LANG_="${ZCODE_LANG:-$(cat "$ROOT/LANG" 2>/dev/null || echo en)}"
CUR="$(cat "$ROOT/INSTALLED" 2>/dev/null || echo none)"
if [ ! -x "$ROOT/bin/zcode-check-update" ]; then
  echo "zcode-update: installation is incomplete. Reinstall with zcode-cli-install-helper." >&2
  exit 1
fi
LATEST="$("$ROOT/bin/zcode-check-update" 2>/dev/null)"; RC=$?
if [ "$RC" = "2" ]; then
  if [ "$LANG_" = "ko" ]; then echo "최신 버전 조회 실패. 네트워크를 확인하세요."; else echo "Failed to check the latest version. Check your network."; fi
  exit 1
fi
if [ "$RC" = "0" ]; then
  if [ "$LANG_" = "ko" ]; then echo "최신 버전입니다. (설치됨: $CUR)"; else echo "Already up to date. (installed: $CUR)"; fi
  [ "${1:-}" = "--apply" ] && exit 0
  exit 0
fi
# newer tag available
if [ "$LANG_" = "ko" ]; then
  echo "새 ZCode 버전이 출시되었습니다: $LATEST (설치된 버전: $CUR)"
  echo "zcode-cli-install-helper 업데이트가 필요합니다. 적용: zcode-update --apply"
else
  echo "A new ZCode version is available: $LATEST (installed: $CUR)"
  echo "zcode-cli-install-helper needs an update. Apply with: zcode-update --apply"
fi
if [ "${1:-}" = "--apply" ]; then
  ZCODE_INSTALL_ROOT="$ROOT" ZCODE_BIN_DIR="__BINDIR__" exec bash "$ROOT/bin/install.sh" --tag "$LATEST" --lang "$LANG_"
fi
exit 0
UPDATER_EOF
sed -i '' -e "s|__ROOT__|$ROOT|g" -e "s|__BINDIR__|$BIN_DIR|g" "$BIN_DIR/.zcode-update.tmp"
chmod +x "$BIN_DIR/.zcode-update.tmp"
mv -f "$BIN_DIR/.zcode-update.tmp" "$BIN_DIR/zcode-update"

echo "$TAG" > "$ROOT/INSTALLED"
echo "$LANG_OPT" > "$ROOT/LANG"
echo "$SCRIPT_VERSION" > "$ROOT/INSTALLER_VERSION"

# ---------------------------------------------------------------- verify + outro
VER_OUTPUT="$("$BIN_DIR/zcode" --version 2>/dev/null || true)"
info "$(printf "$M_DONE" "$BIN_DIR" "$TAG" "${VER_OUTPUT:-unknown}")"

ON_PATH=0
case ":$PATH:" in
  *":$BIN_DIR:"*) ON_PATH=1 ;;
  *) ON_PATH=0 ;;
esac
if [ "$ON_PATH" = "0" ]; then
  warn "$(printf "$M_PATH_WARN" "$BIN_DIR")"
  SHELL_NAME="$(basename "${SHELL:-/bin/sh}")"
  case "$SHELL_NAME" in
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *)    RC_FILE="$HOME/.profile" ;;
  esac
  echo "        echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> $RC_FILE"
  echo "        source $RC_FILE"
  warn "$M_PATH_SESSION"
fi
echo
echo "$M_NEXT1"
echo "$M_NEXT2"
echo "$M_NEXT3"
echo
echo "$M_DISCLAIMER"
