# Bilayers Project - Code Agent Guide

This document provides a comprehensive overview of the Bilayers project for code agents, including project structure, conventions, patterns, and development workflows.

## Project Overview

Bilayers is an open-source specification designed to characterize software containers for bioimage analysis algorithms. It automatically generates user-friendly interfaces (Gradio and Jupyter) from YAML configuration files, making deep learning tools accessible to non-technical users without requiring terminal knowledge.

### Key Concepts
- **Container Specification**: YAML-based configuration defining inputs, outputs, and parameters
- **Interface Generation**: Automated creation of Gradio web apps and Jupyter notebooks
- **Docker Containerization**: All algorithms packaged as portable Docker images
- **CI/CD Pipeline**: Automated building, validation, and deployment of containers

## Project Structure

```
bilayers/
├── src/bilayers/                    # Core Python package
│   ├── algorithms/                  # Algorithm implementations
│   │   ├── classical_segmentation/  # Example algorithm
│   │   ├── cellpose_inference/      # Algorithm wrappers
│   │   ├── gaussian_smoothing/      # More algorithm examples
│   │   └── instanseg_inference/     # Custom algorithms
│   └── build/                       # Interface generation system
│       ├── dockerfiles/             # Docker templates
│       └── parse/                   # Config parsing and generation
├── src/bilayers_cli/               # Command-line interface
├── tests/                          # Test suites
├── docs/                           # Documentation (MyST format)
├── scripts/                        # Build and validation scripts
├── .github/workflows/              # CI/CD pipelines
└── pyproject.toml                  # Package configuration
```

## Configuration System

### Core Files
- **`pyproject.toml`**: Package metadata, dependencies, tooling configuration
- **`noxfile.py`**: Task automation and session management
- **`myst.yml`**: Documentation configuration
- **Algorithm `config.yaml`**: Algorithm specifications

### Package Dependencies
- **Core**: `pyyaml`, `nox` (required)
- **Development**: `numpy`, `scipy`, `scikit-image`, `jinja2`, `nbformat`, `ipython`, `ipywidgets`, `gradio`, `pytest`, `ruff`
- **Documentation**: `mystmd`

## Algorithm Configuration Pattern

Each algorithm follows a standard structure:

```yaml
citations:
  - name: "Algorithm Name"
    doi: "DOI or reference"
    license: "License type"
    description: "Brief description"

docker_image:
  org: "dockerhub_org"
  name: "image_name"
  tag: "version"
  platform: "linux/arm64"

algorithm_folder_name: "folder_name"

exec_function:
  name: "generate_cli_command"
  cli_command: "python -m module_name"
  hidden_args: {}

inputs:
  - name: input_name
    type: image
    label: "User-friendly label"
    # ... detailed configuration

outputs:
  - name: output_name
    type: image
    # ... configuration

parameters:
  - name: param_name
    type: radio|float|textbox|dropdown|checkbox
    # ... parameter configuration
```

## Code Patterns and Conventions

### Python Code Style
- **Line Length**: 160 characters (configured in pyproject.toml)
- **Linting**: Ruff with specific rules (W, F, C, E categories)
- **Type Hints**: Extensive use of TypedDict and typing annotations
- **Error Handling**: Comprehensive argument parsing and validation

### Key Patterns

#### 1. TypedDict Configuration Classes
```python
class ParsedArgs(TypedDict):
    folder: str
    threshold_method: str
    min_size: float
    max_size: float
    save_dir: str
```

#### 2. Configuration Parsing
```python
def parse_config(config_path: Optional[str] = None) -> Config:
    with open(config_path, "r") as file:
        config = yaml.safe_load(file)
    # Convert lists to dictionaries using "name" as key
    config["inputs"] = {item["name"]: item for item in config.get("inputs", [])}
    return config
```

#### 3. Template-Based Generation
- Uses Jinja2 templates for generating Gradio apps and Jupyter notebooks
- Templates located in `src/bilayers/build/parse/`
- Dynamic content generation based on configuration

#### 4. Docker Integration
- Multi-stage Docker builds with platform-specific images
- Base image pulling with fallback to local builds
- Temporary file system for build coordination

## Development Workflow

### 1. Nox Sessions
Primary development tasks are managed through Nox:

```bash
# Parse configuration
nox -s run_parse -- config_path

# Generate interfaces
nox -s run_generate -- config_path

# Build algorithm Docker image
nox -s build_algorithm -- algorithm_name

# Build interface Docker image
nox -s build_interface -- interface_type algorithm_name

# Linting and formatting
nox -s lint
nox -s format
```

### 2. Shell Scripts
Located in `scripts/`:
- **`build_docker.sh`**: Complete Docker build pipeline
- **`lint.sh`**: LinkML schema linting
- **`validate.sh`**: Configuration validation against schema

### 3. Testing Strategy
- **Unit Tests**: Algorithm-specific tests in `tests/test_algorithm/`
- **Configuration Validation**: LinkML schema validation in `tests/test_config/`
- **Interface Tests**: Gradio interface tests in `tests/test_gradio/`

## CI/CD Pipeline

### GitHub Actions Workflows

#### 1. **`deploy.yml`** - Documentation Deployment
- Triggers on pushes to main branch
- Uses MyST Markdown for documentation building
- Deploys to GitHub Pages

#### 2. **`docker-build.yml`** - Docker Container Pipeline
- Runs on self-hosted runners (architecture-specific)
- Three-stage process:
  1. **Lint-Validate-Docs**: LinkML linting, schema validation, doc generation
  2. **Build**: Docker image building for all algorithms and interfaces
  3. **Check Machine**: Architecture verification

#### 3. **`test.yml`** - Validation Testing
- Configuration file validation
- LinkML schema compliance testing
- Pytest execution for validation logic

### Build Process
1. **Parse** configuration files
2. **Generate** interface code (Gradio/Jupyter)
3. **Build** algorithm Docker images (pull from DockerHub or build locally)
4. **Build** interface Docker images with generated code
5. **Validate** all configurations against LinkML schema

## Key Development Tools

### 1. LinkML Schema Validation
- Schema definition in `tests/test_config/validate_schema.yaml`
- Automatic validation of all algorithm configurations
- Error reporting for configuration compliance

### 2. Jinja2 Template System
- **`gradio_template.py.j2`**: Gradio web interface template
- **`jupyter_template.py.j2`**: Jupyter notebook template
- **`jupyter_final_validation_template.py.j2`**: Validation cells
- **`jupyter_shell_command_template.py.j2`**: Command execution cells

### 3. Docker Multi-Platform Support
- ARM64 and AMD64 platform support
- Platform-specific build arguments
- Fallback mechanisms for missing images

## Testing Conventions

### Configuration Testing
```python
@pytest.mark.parametrize(
    "config_path, expected_error",
    [
        ("tests/test_algorithm/correct_validation_config.yaml", ["No issues found"]),
        ("tests/test_algorithm/incorrect_validation_config.yaml", [expected_errors]),
    ],
)
def test_specific_validation_errors(schema_path: str, config_path: str, expected_error: list[str]) -> None:
    # LinkML validation testing
```

### Test Structure
- **Fixtures**: Schema path definitions
- **Parametrized Tests**: Multiple configuration scenarios
- **Subprocess Testing**: LinkML command-line tool integration

## Documentation System

### MyST Markdown
- **Configuration**: `myst.yml` with structured table of contents
- **Sections**:
  - Standard documentation (What is Bilayers)
  - Tool user guides
  - Custom algorithm development
  - Auto-generated developer docs (LinkML schema)

### Documentation Structure
- **`docs/standard/`**: General project information
- **`docs/tool_user/`**: End-user guides
- **`docs/custom_algorithm/`**: Developer guides
- **`docs/developer/`**: Auto-generated schema documentation

## Code Agent Best Practices

### When Working with This Project:

1. **Always validate configurations** using LinkML schema before making changes
2. **Follow the established TypedDict pattern** for type safety
3. **Use Nox sessions** for development tasks rather than direct script execution
4. **Test both Gradio and Jupyter interfaces** when modifying generation logic
5. **Maintain Docker compatibility** across ARM64 and AMD64 platforms
6. **Update documentation** when adding new algorithms or interfaces
7. **Follow the established naming conventions** for algorithms and parameters

### Key Files to Monitor:
- Algorithm `config.yaml` files for specification compliance
- Template files in `src/bilayers/build/parse/` for interface generation
- `noxfile.py` for build process modifications
- Schema files in `tests/test_config/` for validation rules

### Common Development Tasks:
1. **Adding a new algorithm**: Create folder in `src/bilayers/algorithms/`, add `config.yaml` and implementation
2. **Modifying interfaces**: Update Jinja2 templates in `src/bilayers/build/parse/`
3. **Extending configuration schema**: Update LinkML schema and validation tests
4. **Adding new parameter types**: Extend template logic and validation rules

This project emphasizes automation, validation, and standardization to ensure consistent, reliable container generation for bioimage analysis tools.