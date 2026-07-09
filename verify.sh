#!/usr/bin/env bash
# verify.sh — the repo's single pass/fail gate. Run before any push (docs/HANDOFF.md).
#
#   ./verify.sh          full stack: gdparse sweep → import → 300-frame boot → probe_sim
#   ./verify.sh quick    gdparse sweep only (no Godot needed)
#
# Godot 4.7 headless is required for the full stack. In an agent container without it:
#   curl -sSL -o /tmp/godot.zip "https://sourceforge.net/projects/godot-engine.mirror/files/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip/download"
#   unzip /tmp/godot.zip -d /tmp && chmod +x /tmp/Godot_v4.7-stable_linux.x86_64 && mv /tmp/Godot_v4.7-stable_linux.x86_64 /usr/local/bin/godot
# gdparse comes from `pip install gdtoolkit`. NOTE: gdparse checks SYNTAX ONLY —
# a method can parse and still not exist at runtime; the probes catch that.
#
# Exits nonzero on the first hard failure. Godot steps also fail on any
# "SCRIPT ERROR" in output, since Godot's exit code alone doesn't catch them.

set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
FAIL=0

step() { printf '\n\033[1m── %s\033[0m\n' "$1"; }

step "gdparse syntax sweep (scripts/ config/ tests/)"
if command -v gdparse >/dev/null 2>&1; then
  BAD=0
  while IFS= read -r f; do
    gdparse "$f" || { echo "PARSE FAIL: $f"; BAD=1; }
  done < <(find scripts config tests -name '*.gd')
  [ "$BAD" -eq 0 ] && echo "all .gd files parse" || FAIL=1
else
  echo "SKIP: gdparse not installed (pip install gdtoolkit)"
fi

if [ "${1:-}" = "quick" ]; then
  [ "$FAIL" -eq 0 ] && echo -e "\nQUICK VERIFY PASSED" || echo -e "\nQUICK VERIFY FAILED"
  exit "$FAIL"
fi

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo -e "\nERROR: '$GODOT' not found — install Godot 4.7 headless (see header) or run './verify.sh quick'."
  exit 1
fi

godot_step() { # name, args...
  local name="$1"; shift
  step "$name"
  local out
  out="$("$GODOT" --headless --path . "$@" 2>&1)"
  local code=$?
  echo "$out" | tail -25
  if [ $code -ne 0 ] || echo "$out" | grep -q "SCRIPT ERROR"; then
    echo "STEP FAILED: $name (exit $code)"
    FAIL=1
  fi
}

godot_step "import (.godot cache + .uid regen)" --import --quit-after 1
godot_step "boot the real game 300 frames"      --quit-after 300
godot_step "probe_sim (fixed-step clock + determinism tripwire)" -s res://tests/probe_sim.gd
godot_step "probe_movement (C1 naval-movement spec acceptance)"  -s res://tests/probe_movement.gd
godot_step "probe_hardpoints (C2 turret suite, vs C3 enemies)"    -s res://tests/probe_hardpoints.gd
godot_step "probe_waves (C3 wave-director spec acceptance)"       -s res://tests/probe_waves.gd
godot_step "probe_tech (C4 levels & tech-tree spec acceptance)"   -s res://tests/probe_tech.gd
godot_step "probe_sonar (C5 sonar/subs/depth-charge spec acceptance)" -s res://tests/probe_sonar.gd

if [ "$FAIL" -eq 0 ]; then
  echo -e "\nALL VERIFY STEPS PASSED"
else
  echo -e "\nVERIFY FAILED"
fi
exit "$FAIL"
