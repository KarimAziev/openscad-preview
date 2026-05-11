#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  render_preview_set.sh <input.scad> [options] [-- <extra openscad args>]

Options:
  --output-dir PATH             Directory for generated angle PNGs
  --project-root PATH           Project root for relative inputs and outputs
  --angles LIST                 Comma-separated angles (default: iso,front,right,top)
  --distance VALUE              Camera distance for built-in angles (default: 1100)
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

Supported built-in angles:
  iso, front, rear, left, right, top, bottom
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
render_preview="$script_dir/render_preview.sh"

input=""
output_dir=""
project_root="${OPENSCAD_PREVIEW_PROJECT_ROOT:-}"
angles="iso,front,right,top"
distance="1100"
imgsize="754,934"
view="axes,scales"
projection="ortho"
colorscheme=""
autocenter=0
viewall=0
mode="preview"
openscad_bin="${OPENSCAD_BIN:-openscad}"
no_default_args=0
strict_defaults=0
default_arg_files=()
cli_openscad_args=()
passthrough_args=()

normalize_imgsize() {
  printf '%s' "${1//x/,}"
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

camera_for_angle() {
  local angle="$1"

  case "$angle" in
    iso)
      printf '0,0,0,60,0,35,%s\n' "$distance"
      ;;
    front)
      printf '0,0,0,90,0,0,%s\n' "$distance"
      ;;
    rear)
      printf '0,0,0,90,0,180,%s\n' "$distance"
      ;;
    right)
      printf '0,0,0,90,0,90,%s\n' "$distance"
      ;;
    left)
      printf '0,0,0,90,0,-90,%s\n' "$distance"
      ;;
    top)
      printf '0,0,0,0,0,0,%s\n' "$distance"
      ;;
    bottom)
      printf '0,0,0,180,0,0,%s\n' "$distance"
      ;;
    *)
      printf 'Unknown angle: %s\n' "$angle" >&2
      return 1
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      output_dir="$2"
      shift 2
      ;;
    --output-dir=*)
      output_dir="${1#*=}"
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
    --angles)
      angles="$2"
      shift 2
      ;;
    --angles=*)
      angles="${1#*=}"
      shift
      ;;
    --distance)
      distance="$2"
      shift 2
      ;;
    --distance=*)
      distance="${1#*=}"
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
      no_default_args=1
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

if [[ -z "$output_dir" ]]; then
  input_base="$(basename -- "${input%.scad}")"
  output_dir="$project_root/build/skill-previews/$input_base"
elif [[ "$output_dir" != /* ]]; then
  output_dir="$project_root/$output_dir"
fi

mkdir -p -- "$output_dir"

IFS=',' read -r -a angle_items <<< "$angles"

for angle in "${angle_items[@]}"; do
  angle="${angle#"${angle%%[![:space:]]*}"}"
  angle="${angle%"${angle##*[![:space:]]}"}"
  [[ -z "$angle" ]] && continue

  camera="$(camera_for_angle "$angle")"
  output="$output_dir/$angle.png"

  cmd=(
    "$render_preview"
    "$input"
    --project-root "$project_root"
    --output "$output"
    --camera "$camera"
    --imgsize "$imgsize"
    --view "$view"
    --projection "$projection"
    --openscad-bin "$openscad_bin"
  )

  if [[ "$mode" == "render" ]]; then
    cmd+=(--render)
  else
    cmd+=(--preview)
  fi

  if [[ -n "$colorscheme" ]]; then
    cmd+=(--colorscheme "$colorscheme")
  fi

  if [[ "$autocenter" -eq 1 ]]; then
    cmd+=(--autocenter)
  fi

  if [[ "$viewall" -eq 1 ]]; then
    cmd+=(--viewall)
  fi

  if [[ "$no_default_args" -eq 1 ]]; then
    cmd+=(--no-default-args)
  fi

  if [[ "$strict_defaults" -eq 1 ]]; then
    cmd+=(--strict-defaults)
  fi

  if [[ "${#default_arg_files[@]}" -gt 0 ]]; then
    for default_arg_file in "${default_arg_files[@]}"; do
      cmd+=(--default-args-file "$default_arg_file")
    done
  fi

  if [[ "${#cli_openscad_args[@]}" -gt 0 ]]; then
    for cli_arg in "${cli_openscad_args[@]}"; do
      cmd+=(--openscad-arg "$cli_arg")
    done
  fi

  if [[ "${#passthrough_args[@]}" -gt 0 ]]; then
    cmd+=(--)
    cmd+=("${passthrough_args[@]}")
  fi

  "${cmd[@]}"
done

printf '%s\n' "$output_dir"
