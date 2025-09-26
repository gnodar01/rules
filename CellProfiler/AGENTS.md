# CellProfiler Development Guide for AI Agents

## Build/Test Commands
```bash
# Install dependencies (use pixi)
pixi install --environment=dev

# Activate virtual environment
pixi shell --environment=dev # also does install if necessary

# Run tests
pytest tests/frontend tests/core tests/library  # All tests
pytest tests/frontend/modules/test_align.py  # Single test file
pytest tests/core -k "test_pipeline" -v  # Pattern match tests

# Run CellProfiler
pixi run cp
```

## Project Structure
- `src/frontend` - Frontend package contianing code related to the CellProfiler GUI (using `wxPython`) and CLI, as well as code for CellProfiler modules
- `src/frontend/cellprofiler/modules` - CellProfiler modules for each module and, its settings, and lifecylcle methods (e.g. `run`)
  - The mathematical and image processing logic is currently in progress of being moved to the `cellprofiler_library` subpackage
- `src/subpackages/core` - The core package acting as the engine for CellProfiler; contains the pipeline system (which sets up and runs modules), the measurements, the image readers, the concurrency system (threading and multiprocessing), workspace, image set classes, utilities, and more.
- `src/subpackages/library` - An in-progress package containing all of the mathematical and image processing logic for modules to use

## Code Style Guidelines
- Python 3.9 required, type hints encouraged but not enforced
- Use existing imports: numpy, scipy, scikit-image, matplotlib, wxPython
- Follow module patterns in src/frontend/cellprofiler/modules/
- Error handling: Use logging.Logger, avoid bare exceptions
- No code comments unless explicitly requested
- Naming: snake_case for functions/variables, PascalCase for classes
- Use ruff for linting (available via pixi environment)
- Discouraged from using pip, uv, conda, mamba, etc; only pixi
