# OpenSCAD Preview

**Table of Contents**

> - [OpenSCAD Preview](#openscad-preview)
>   - [What It Does](#what-it-does)
>   - [Requirements](#requirements)
>   - [Install In Codex](#install-in-codex)
>   - [Use With Codex](#use-with-codex)
>   - [Configuration](#configuration)
>   - [Script Reference](#script-reference)
>   - [Repository Layout](#repository-layout)
>   - [License](#license)

Codex plugin and Agent Skill for rendering OpenSCAD `.scad` files to configurable PNG previews.

## What It Does

OpenSCAD Preview gives Codex a repeatable workflow for visually checking OpenSCAD geometry. It bundles:

- `render_preview.sh` for one PNG render from a `.scad` file.
- `render_preview_set.sh` for standard multi-angle preview sets.
- An Agent Skill that tells Codex when and how to use those wrappers.
- A Codex plugin manifest and marketplace metadata.

The wrapper prefers fast and useful OpenSCAD features when the installed CLI supports them:

- `--backend=Manifold`
- `--enable=roof`
- `--enable=textmetrics`

These defaults are detected from `openscad --help`. Unsupported preferred defaults are skipped unless `--strict-defaults` is passed.

## Requirements

- OpenSCAD CLI on `PATH`, or pass `--openscad-bin PATH`.
- Bash-compatible shell on macOS or Linux.
- Optional `git` for project-root detection.

## Install In Codex

Add this repository as a plugin marketplace:

```bash
codex plugin marketplace add KarimAziev/openscad-preview
```

Then restart Codex, open the plugin directory, select the `OpenSCAD Preview` marketplace, and install the plugin.

For local development from this clone:

```bash
codex plugin marketplace add ~/src/openscad-preview
```

## Use With Codex

After installing the plugin, ask Codex to use OpenSCAD Preview while working in an OpenSCAD project:

```text
Use OpenSCAD Preview to render scad/assembly.scad and inspect the PNG.
```

```text
Use OpenSCAD Preview to generate multi-angle previews for scad/printable.scad.
```

```text
Use OpenSCAD Preview after this geometry change and check the part from the top and isometric views.
```

Codex loads the bundled skill, runs the scripts from the installed plugin, and inspects the generated PNGs with its local image viewing tool. Users normally do not need to call the scripts directly.

Generated previews are written under the target project's `build/skill-previews/` directory unless Codex chooses a task-specific output path.

The project root is detected from `--project-root`, `OPENSCAD_PREVIEW_PROJECT_ROOT`, `git rev-parse --show-toplevel`, then the current directory.

## Configuration

Default OpenSCAD arguments are loaded in this order:

1. Supported built-ins: `--backend=Manifold`, `--enable=roof`, `--enable=textmetrics`
2. `~/.config/openscad-preview/default-args`
3. `<project-root>/.agents/openscad-preview.args`
4. Files passed with `--default-args-file PATH`
5. Args passed with repeatable `--openscad-arg VALUE`
6. Args after `--`

Argument files use one argument per line:

```text
--backend=Manifold
--enable=textmetrics
--hardwarnings
```

Blank lines and lines starting with `#` are ignored.

Useful options:

```bash
--no-default-args      # disable built-ins and config files
--strict-defaults      # fail if preferred built-ins are unsupported
--openscad-bin PATH    # use a specific OpenSCAD binary
--viewall              # fit the object in the view
--autocenter           # center the camera on the object
```

## Script Reference

The bundled scripts are primarily for agents, but they can also be run manually for debugging or development.

Render one preview:

```bash
skills/openscad-preview/scripts/render_preview.sh path/to/model.scad
```

Render a preview set:

```bash
skills/openscad-preview/scripts/render_preview_set.sh \
  path/to/model.scad \
  --angles iso,front,right,top \
  --viewall \
  --autocenter
```

Default output paths:

- Single preview: `<project-root>/build/skill-previews/<input-name>.png`
- Preview set: `<project-root>/build/skill-previews/<input-name>/<angle>.png`

`render_preview_set.sh` supports:

```text
iso, front, rear, left, right, top, bottom
```

Example:

```bash
skills/openscad-preview/scripts/render_preview_set.sh \
  scad/assembly.scad \
  --angles iso,front,right,top,rear,left \
  --distance 1200 \
  --imgsize 900,900
```

## Repository Layout

```text
.codex-plugin/plugin.json
.agents/plugins/marketplace.json
skills/openscad-preview/SKILL.md
skills/openscad-preview/scripts/render_preview.sh
skills/openscad-preview/scripts/render_preview_set.sh
```

## License

MIT. See [LICENSE](LICENSE).
