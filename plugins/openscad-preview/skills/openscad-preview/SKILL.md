---
name: openscad-preview
description: Render OpenSCAD .scad files to PNG previews for visual inspection while editing CAD geometry. Use when checking OpenSCAD geometry, debugging fit, orientation, printable layouts, camera views, multi-angle previews, or visual regressions. Uses bundled wrappers around the OpenSCAD CLI with feature-detected and configurable default flags.
license: MIT
---

# OpenSCAD Preview

Use this skill for visual verification of `.scad` files. Render with the bundled wrapper, then inspect the PNG with the local image viewing tool.

## Requirements

- OpenSCAD CLI available on `PATH`, or pass `--openscad-bin PATH`.
- Bash-compatible shell on macOS or Linux.
- Optional `git` is used for project-root detection.
- The wrappers prefer `--backend=Manifold`, `--enable=roof`, and `--enable=textmetrics` when `openscad --help` reports support for them.

## Workflow

1. Identify the target `.scad` file and the view needed for the task.
2. Run `scripts/render_preview.sh` for one focused view, or `scripts/render_preview_set.sh` for several standard angles.
3. Open the generated PNGs with the local image viewing tool.
4. If a view is unclear, rerender with `--viewall`, `--autocenter`, a different `--camera`, `--projection`, `--view`, or `--imgsize`.
5. For geometry changes that need more than visual confidence, also run the project's OpenSCAD tests or export command.

## Single Preview

Run from the project containing the `.scad` file:

```bash
/path/to/openscad-preview/skills/openscad-preview/scripts/render_preview.sh scad/assembly.scad
```

Default output goes to `<project-root>/build/skill-previews/<input-name>.png`. The project root is detected from `--project-root`, `OPENSCAD_PREVIEW_PROJECT_ROOT`, `git rev-parse --show-toplevel`, then the current directory.

## Multi-Angle Preview Set

Generate several standard views:

```bash
/path/to/openscad-preview/skills/openscad-preview/scripts/render_preview_set.sh \
  scad/assembly.scad \
  --angles iso,front,right,top \
  --viewall \
  --autocenter
```

Default output goes to `<project-root>/build/skill-previews/<input-name>/<angle>.png`.

## Default OpenSCAD Arguments

The wrapper feature-detects these preferred defaults from `openscad --help`:

```bash
--backend=Manifold
--enable=roof
--enable=textmetrics
```

Unsupported preferred defaults are skipped. Pass `--strict-defaults` when unsupported defaults should fail the command instead.

Users can override or extend defaults without repeating flags in every command:

- Global file: `~/.config/openscad-preview/default-args`
- Project file: `.agents/openscad-preview.args`
- One argument per line; blank lines and lines starting with `#` are ignored.
- CLI additions: repeat `--openscad-arg VALUE`.
- Disable all default-args files and built-ins with `--no-default-args`.
- Use a specific defaults file with `--default-args-file PATH`.

Arguments after `--` are passed directly to OpenSCAD after defaults, so use them for one-off flags:

```bash
scripts/render_preview.sh scad/assembly.scad -- --hardwarnings
```

## Common Commands

Assembly preview:

```bash
scripts/render_preview.sh scad/assembly.scad --camera 0,0,0,60,0,35,1100
```

Orthographic debug view with axes and scales:

```bash
scripts/render_preview.sh \
  scad/steering_system/steering_assembly.scad \
  --camera=-40,0,0,180,0,180,500 \
  --projection ortho \
  --view axes,scales \
  --imgsize 754,934
```

Top-down printable plate check:

```bash
scripts/render_preview.sh \
  scad/printable.scad \
  --camera 0,0,0,0,0,0,900 \
  --projection ortho \
  --view axes
```

Multi-angle part inspection:

```bash
scripts/render_preview_set.sh \
  scad/printable_parts/bracket.scad \
  --angles iso,front,right,top \
  --imgsize 900,900 \
  --viewall \
  --autocenter
```

## Guidance

- Start with `--projection ortho` for dimension or alignment debugging.
- Use `--viewall --autocenter` when the model scale is unknown.
- Keep `--view axes,scales` on when checking orientation or relative placement.
- Increase `--imgsize` before zooming if small details are hard to judge.
- Reuse the exact render command after each edit so visual comparisons stay meaningful.

## Guardrails

- Prefer PNG previews for visual inspection; use STL or 3MF exports only when the task needs printable output.
- Write preview artifacts under `build/skill-previews/` unless the task needs a different location.
- If rendering fails, read the OpenSCAD error output before changing code.
