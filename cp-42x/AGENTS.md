# CellProfiler Development Guide for AI Agents

## General Concepts

- A **CellProfiler Module** is not a python module meant to be importable, but rather an instance of the **Module** class, forming a unit of a **CellProfiler Pipeline** (like a node in a DAG) that takes inputs of images, objects, or measurements from previous **CellProfiler Modules**, and produces outputs of images, objects, and/or measurements for subsequent **CellProfiler Modules**.
- A **CellProfiler Module** has parameters/settings that affect how it operates on inputs.

## Build/Test Commands
```bash
# Install dependencies (use pixi)
pixi install -e dev

# Activate virtual environment
pixi shell -e dev # also does install if necessary

# Run tests
pixi run -e dev pytest cp/tests core/tests # All tests
pixi run -e dev pytest cp/tests/modules/test_align.py  # Single test file
pixi run -e dev pytest core/tests -k "test_pipeline" -v  # Pattern match tests

# Run CellProfiler (gui by default, -h for cli)
pixi run -e dev cp
```

## Project Structure
- `cp/` - Code for `cellprofiler`; frontend package contianing code related to the CellProfiler GUI (using `wxPython`) and CLI, as well as code for CellProfiler modules.
    - `cp/cellprofiler/modules` - CellProfiler modules for each module and, its settings, and lifecylcle methods (e.g. `run`).
- `core/` - Code for `cellprofiler_core`; the core package acting as the engine for CellProfiler, which contains the pipeline system (which sets up and runs modules), the measurements, the image readers, the concurrency system (threading and multiprocessing), workspace, image set classes, utilities, and more.
- `distribution` - Scripts, assets, and configuration files for bundling the application for distribution to macOS, linux, windows, and docker.
- `cp/tests` - Unit and integration tests for frontend code, `cellprofiler`.
- `core/tests` - Unit and integration tests for `cellprofiler_core`.
- Ignore the following folders and files:
  * `.pixi/`
  * `.git/`
  * `pixi.lock`
  * `flake.lock`
  * `flike.nix`
  * `nix/`
  * `scripts/`
  * `.vscode/`
  * `.pytest_cache/`
  * `**/*.egg-info/`
  * `**/__pyacache__/`

## Code Style Guidelines
- Use existing imports: numpy, scipy, scikit-image, matplotlib, wxPython
- Follow module patterns in `cp/cellprofiler/modules/`
- Error handling: Use logging.Logger, avoid bare exceptions
- No code comments unless explicitly requested
- Naming: snake_case for functions/variables, PascalCase for classes
- Use ruff for linting (available via pixi environment)
- Discouraged from using pip, uv, conda, mamba, etc; only pixi
