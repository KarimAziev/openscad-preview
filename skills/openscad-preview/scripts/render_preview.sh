#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  render_preview.sh <input.scad> [options] [-- <extra openscad args>]

Options:
  --output, -o PATH             Output PNG path
  --project-root PATH           Project root for relative inputs and outputs
  --camera VALUE                Camera tuple for OpenSCAD
  --imgsize VALUE               Image size, e.g. 754,934 or 754x934
  --view VALUE                  OpenSCAD view flags, e.g. axes,scales
  --projection VALUE            ortho or perspective
  --colorscheme VALUE           Optional OpenSCAD color scheme
  --autocenter                  Pass --autocenter to OpenSCAD
  --viewall                     Pass --viewall to OpenSCAD
  --preview                     Force preview mode (default)
  --render                      Omit --preview and let OpenSCAD render normally
  --openscad-bin PATH           Override the openscad executable
  --openscad-arg VALUE          Add one OpenSCAD argument after defaults
  --default-args-file PATH      Read default OpenSCAD args from a file
  --no-default-args             Disable built-in and config default args
  --strict-defaults             Fail if preferred built-in defaults are unsupported
  --help, -h                    Show this help

Default args are loaded in this order unless --no-default-args is used:
  1. Supported built-ins: --backend=Manifold, --enable=roof, --enable=textmetrics
  2. ~/.config/openscad-preview/default-args
  3. <project-root>/.agents/openscad-preview.args
  4. --default-args-file PATH values
  5. --openscad-arg VALUE values
  6. Arguments after --
EOF
}

input=""
output=""
project_root="${OPENSCAD_PREVIEW_PROJECT_ROOT:-}"
camera="0,0,0,60,0,35,1100"
imgsize="754,934"
view="axes,scales"
projection="ortho"
colorscheme=""
autocenter=0
viewall=0
mode="preview"
openscad_bin="${OPENSCAD_BIN:-openscad}"
use_default_args=1
strict_defaults=0
default_arg_files=()
cli_openscad_args=()
passthrough_args=()
openscad_args=()
openscad_help=""
openscad_help_loaded=0

normalize_imgsize() {
  printf '%s' "${1//x/,}"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

detect_project_root() {
  if [[ -n "$project_root" ]]; then
    cd -- "$project_root"
    printf '%s\n' "$PWD"
    return 0
  fi

  if command -v git >/dev/null 2>&1; then
    local git_root
    if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      printf '%s\n' "$git_root"
      return 0
    fi
  fi

  printf '%s\n' "$PWD"
}

resolve_input() {
  local candidate="$1"

  if [[ -f "$candidate" ]]; then
    cd -- "$(dirname -- "$candidate")"
    printf '%s/%s\n' "$PWD" "$(basename -- "$candidate")"
    return 0
  fi

  if [[ -f "$project_root/$candidate" ]]; then
    cd -- "$(dirname -- "$project_root/$candidate")"
    printf '%s/%s\n' "$PWD" "$(basename -- "$candidate")"
    return 0
  fi

  return 1
}

append_args_file() {
  local path="$1"

  [[ -f "$path" ]] || return 0

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    openscad_args+=("$line")
  done < "$path"
}

load_openscad_help() {
  if [[ "$openscad_help_loaded" -eq 1 ]]; then
    return 0
  fi

  if ! openscad_help="$("$openscad_bin" --help 2>&1)"; then
    if [[ "$strict_defaults" -eq 1 ]]; then
      printf 'Unable to inspect OpenSCAD features with: %s --help\n' "$openscad_bin" >&2
      return 1
    fi
    printf 'Warning: unable to inspect OpenSCAD features; skipping built-in default args.\n' >&2
    openscad_help_loaded=1
    return 0
  fi

  openscad_help_loaded=1
}

help_contains_word() {
  local word="$1"
  printf '%s\n' "$openscad_help" | grep -Eiq "(^|[^[:alnum:]_-])${word}([^[:alnum:]_-]|$)"
}

add_supported_or_strict() {
  local arg="$1"
  local word="$2"

  if help_contains_word "$word"; then
    openscad_args+=("$arg")
    return 0
  fi

  if [[ "$strict_defaults" -eq 1 ]]; then
    printf 'Preferred OpenSCAD default is unsupported by %s: %s\n' "$openscad_bin" "$arg" >&2
    return 1
  fi

  printf 'Skipping unsupported OpenSCAD default: %s\n' "$arg" >&2
}

append_detected_builtin_defaults() {
  load_openscad_help

  if [[ -z "$openscad_help" ]]; then
    return 0
  fi

  add_supported_or_strict "--backend=Manifold" "Manifold"
  add_supported_or_strict "--enable=roof" "roof"
  add_supported_or_strict "--enable=textmetrics" "textmetrics"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o)
      output="$2"
      shift 2
      ;;
    --output=*)
      output="${1#*=}"
      shift
      ;;
    --project-root)
      project_root="$2"
      shift 2
      ;;
    --project-root=*)
      project_root="${1#*=}"
      shift
      ;;
    --camera)
      camera="$2"
      shift 2
      ;;
    --camera=*)
      camera="${1#*=}"
      shift
      ;;
    --imgsize)
      imgsize="$(normalize_imgsize "$2")"
      shift 2
      ;;
    --imgsize=*)
      imgsize="$(normalize_imgsize "${1#*=}")"
      shift
      ;;
    --view)
      view="$2"
      shift 2
      ;;
    --view=*)
      view="${1#*=}"
      shift
      ;;
    --projection)
      projection="$2"
      shift 2
      ;;
    --projection=*)
      projection="${1#*=}"
      shift
      ;;
    --colorscheme)
      colorscheme="$2"
      shift 2
      ;;
    --colorscheme=*)
      colorscheme="${1#*=}"
      shift
      ;;
    --autocenter)
      autocenter=1
      shift
      ;;
    --viewall)
      viewall=1
      shift
      ;;
    --preview)
      mode="preview"
      shift
      ;;
    --render)
      mode="render"
      shift
      ;;
    --openscad-bin)
      openscad_bin="$2"
      shift 2
      ;;
    --openscad-bin=*)
      openscad_bin="${1#*=}"
      shift
      ;;
    --openscad-arg)
      cli_openscad_args+=("$2")
      shift 2
      ;;
    --openscad-arg=*)
      cli_openscad_args+=("${1#*=}")
      shift
      ;;
    --default-args-file)
      default_arg_files+=("$2")
      shift 2
      ;;
    --default-args-file=*)
      default_arg_files+=("${1#*=}")
      shift
      ;;
    --no-default-args)
      use_default_args=0
      shift
      ;;
    --strict-defaults)
      strict_defaults=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      passthrough_args=("$@")
      break
      ;;
    -*)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$input" ]]; then
        printf 'Only one input .scad file is supported.\n\n' >&2
        usage >&2
        exit 1
      fi
      input="$1"
      shift
      ;;
  esac
done

if [[ -z "$input" ]]; then
  usage >&2
  exit 1
fi

project_root="$(detect_project_root)"

if ! resolved_input="$(resolve_input "$input")"; then
  printf 'Input file not found: %s\n' "$input" >&2
  exit 1
fi

input="$resolved_input"

if [[ -z "$output" ]]; then
  output="$project_root/build/skill-previews/$(basename -- "${input%.scad}").png"
elif [[ "$output" != /* ]]; then
  output="$project_root/$output"
fi

mkdir -p -- "$(dirname -- "$output")"

if [[ "$use_default_args" -eq 1 ]]; then
  append_detected_builtin_defaults
  append_args_file "$HOME/.config/openscad-preview/default-args"
  append_args_file "$project_root/.agents/openscad-preview.args"
  if [[ "${#default_arg_files[@]}" -gt 0 ]]; then
    for default_arg_file in "${default_arg_files[@]}"; do
      if [[ "$default_arg_file" != /* ]]; then
        default_arg_file="$project_root/$default_arg_file"
      fi
      append_args_file "$default_arg_file"
    done
  fi
fi

cmd=(
  "$openscad_bin"
  -o "$output"
)

if [[ "$mode" == "preview" ]]; then
  cmd+=(--preview)
fi

cmd+=(
  "--projection=$projection"
  "--imgsize=$imgsize"
  "--view=$view"
  "--camera=$camera"
)

if [[ -n "$colorscheme" ]]; then
  cmd+=("--colorscheme=$colorscheme")
fi

if [[ "$autocenter" -eq 1 ]]; then
  cmd+=(--autocenter)
fi

if [[ "$viewall" -eq 1 ]]; then
  cmd+=(--viewall)
fi

if [[ "${#openscad_args[@]}" -gt 0 ]]; then
  cmd+=("${openscad_args[@]}")
fi

if [[ "${#cli_openscad_args[@]}" -gt 0 ]]; then
  cmd+=("${cli_openscad_args[@]}")
fi

if [[ "${#passthrough_args[@]}" -gt 0 ]]; then
  cmd+=("${passthrough_args[@]}")
fi

cmd+=("$input")

printf 'Rendering preview to %s\n' "$output" >&2
printf 'Project root: %s\n' "$project_root" >&2
printf 'Command:' >&2
for arg in "${cmd[@]}"; do
  printf ' %q' "$arg" >&2
done
printf '\n' >&2

"${cmd[@]}"

printf '%s\n' "$output"
