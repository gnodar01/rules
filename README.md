# Rules

> [!WARNING]
Contents here are very much in flux and may change radically at any time.

Personal rules for various projects I work on.

My general approach is to place rules files of various agentic systems in `.gitignore` of all projects I work on.

This is not to hide it, but because there is no common standard, and so everyone wanting to contribute to projects will use different formats that conflict with each other.
For example Cursor [uses](https://cursor.com/docs/context/rules) `.cursor/rules/*.mdc` in the project root and/or in subdirectories or alternatively a top level `AGENTS.md` (and used to use `.cursorrules`).
Warp.dev [uses](https://docs.warp.dev/knowledge-and-collaboration/rules) `WARP.md` which can live in the root of the repository and/or in subdirectories.
There's a ton more examples.

A top level `AGENTS.md` is the closest I've seen to an [agreed upon standard](https://agents.md/), but only lvies in the root of the project.
There are also analagous non-version controled rules files stored in some system-global config directory for a given tool like `~/.claude/CLAUDE.md` or `~/.opencode/AGENTS.md`.

Instead of polluting my project repositories with my specific AI-tool-of-the-day's preffered format, I match my folder hierarchy in this repo to the folder hierarchies of my projects (where the code actually lives).
I then place my rules files here, and use scripts to symlink them into my various projects.

If others find them helpful, then they too can run:
```bash
./create_symlinks.sh </path/to/target_project>
```

where `<target_project>` must match a top level directory name in this repo.

## Current Workflow

As of writing this, I only have one project `CellProfiler`, with a top level `AGENTS.md` used by [opencode](https://opencode.ai/) to dispatch to a variety of different models through [zen](https://opencode.ai/docs/zen).
Since I'm currently only using a top-level `AGENTS.md`, I don't have the full folder hierarchy matched to the [CellProfiler repo](github.com/CellProfiler/CellProfiler).
I plan to grow this repo out so I have rules files for most/all subdirectories of `CellProfiler`, [piximi](github.com/piximi/piximi), and any other project I'm working on.

