# CellProfiler #5169: investigation and implementation handoff

## Scope and source context

This investigation concerns **CellProfiler 4.2.x**, not the current default branch or version 5. The user explicitly required assessment against the local version 4 checkout.

- Issue: https://github.com/CellProfiler/CellProfiler/issues/5169
- Title: Issue with installation path and starting path mount mismatch
- Proposal by `gnodar01`: https://github.com/CellProfiler/CellProfiler/issues/5169#issuecomment-4745846863
- Issue and comment were read using the GitHub CLI. The issue was open when queried.
- Local `cp` checkout: branch `4.2.x`, commit `8315ebe0ef41360e0c81eeca07d4ad6754a8496e`.
- Local `core` checkout: commit `eaff8b4a853fb8177dabc37cc2699f4579c73a5c`.
- Investigation date: 2026-10-22.

Repository layout here has separate `cp` and `core` checkouts. Paths below are relative to the workspace root; adapt them if using a different layout. Read the destination checkout's `AGENTS.md` before implementation. No application code was changed during this investigation, and nothing was posted to GitHub.

## Reported failure

The reporter uses Windows Server 2019 and CellProfiler 4.2.8 installed in a conda environment on `C:`. A batch launcher lives on `D:` and is linked from users' desktops. The launcher starts CellProfiler with a plugins directory on `D:`. Starting with a working directory on `D:` crashes during GUI initialization:

```text
cellprofiler/gui/help/content.py: image_resource
    relpath = os.path.relpath(...)
ValueError: path is on mount 'c:', start on mount 'D:'
OnInit returned false, exiting...
```

The traceback reaches this function through `read_content("display_interactive_navigation.rst")` while importing GUI help content. The resource is on `C:`, while `os.path.relpath()` implicitly uses the working directory on `D:`. Windows cannot express that relationship as a relative path.

The reporter found that moving the launcher to `C:` works. `gnodar01` suggested adding `cd /d C:\` before launching CellProfiler, and proposed catching `ValueError` in `image_resource()` and returning the absolute resource path with forward slashes.

The working-directory workaround is reasonable for the reported setup. It is not the application-level fix; changing the working directory also changes how relative user paths are interpreted.

## Assessment of the proposed patch

The diagnosis is correct. Catching `ValueError` and returning an absolute path should prevent this specific cross-drive exception, provided the rest of the original function remains intact.

The posted snippet is incomplete if pasted as a whole-function replacement: its successful `try` branch assigns `relpath` but never returns it, so same-drive calls return `None`. If the intention was to retain the original function's tail, that problem does not apply.

A complete, conservative hotfix would be:

```python
def image_resource(filename):
    abspath = os.path.abspath(
        pkg_resources.resource_filename(
            "cellprofiler", os.path.join("data", "images", filename)
        )
    )
    try:
        relpath = os.path.relpath(abspath)
    except ValueError:
        return abspath.replace("\\", "/")

    if relpath == os.path.join("..", "cellprofiler", "data", "images", filename):
        return "../images/{}".format(filename)

    return relpath.replace("\\", "/")
```

This is a proposed hotfix, not a patch applied or validated end to end. It preserves existing behavior on the same drive, including the existing documentation heuristic. It does not resolve the broader problems below.

## Additional findings

### Rendering paths with spaces

Replacing backslashes does not make a filesystem path a correctly encoded image URI. An isolated check using the installed Docutils 0.15.2 produced:

```text
RST:  .. image:: C:/Program Files/CellProfiler/data/images/module_help.png
HTML: src="C:/ProgramFiles/CellProfiler/data/images/module_help.png"
```

Using `file:///C:/Program%20Files/CellProfiler/data/images/module_help.png` preserved the encoded space in the generated HTML. Therefore, a cross-drive fallback can allow startup while leaving help images broken for installation paths containing spaces. This is distinct from spaces in the reporter's launcher or plugins directory; the resource installation path is what matters here.

### Working-directory-dependent cached references

`cp/cellprofiler/gui/help/content.py` calls `read_content()` during import. Several modules also call `image_resource()` when constructing help strings during import. A relative image reference generated then can become invalid if the working directory later changes. This is a demonstrated property of the references, not a claim that this session reproduced a particular GUI action changing the directory.

### One helper has both URI and filesystem consumers

`image_resource_dataUrl()` in the same file currently does:

```python
with open(image_resource(filename), "rb") as img:
```

The welcome screen calls this function for multiple images. Consequently, changing `image_resource()` to return a `file:` URI without changing this consumer will break file access. Do not percent-encode the shared return value while leaving `open()` pointed at it.

### Documentation behavior must be preserved explicitly

The current frontend helper recognizes one particular relative path as a presumed Sphinx build and returns `../images/<filename>`. This is an implicit working-directory heuristic, not an explicit documentation mode.

`cp/docs/Makefile` copies `cellprofiler/data/help` and `cellprofiler/data/images` into `docs/source` before invoking Sphinx. `cp/docs/source/conf.py` configures autodoc. Static help RST is copied directly, while imported module help may use resource helpers. A replacement must account for both routes and must not bake machine-specific installation URIs into published documentation.

### Another resource helper needs review

`core/cellprofiler_core/utilities/image.py` has a separate `image_resource()` implementation. It uses `os.path.relpath()` in its frozen-application branch and in a documentation-related branch. This exposes analogous cross-drive risk, although those execution paths were not reproduced end to end. The ordinary non-frozen branch already returns an absolute path.

## Recommended robust direction

Separate physical resource lookup from the reference used by an HTML/RST renderer. At runtime, avoid deriving resource locations from the process working directory.

Illustrative runtime helpers:

```python
from pathlib import Path


def image_resource_path(filename):
    return Path(
        pkg_resources.resource_filename(
            "cellprofiler", os.path.join("data", "images", filename)
        )
    ).resolve()


def image_resource(filename):
    return image_resource_path(filename).as_uri()
```

Update `image_resource_dataUrl()` to open `image_resource_path(filename)` directly. The existing `pkg_resources` dependency can stay for this maintenance fix; migrating resource APIs is not necessary to solve the issue.

The helper sketch is **not a complete implementation**: documentation rendering still needs an explicit policy that emits portable references to copied assets instead of runtime `file:` URIs. Choose and wire that policy before importing modules that cache help strings. Inspect actual Sphinx/autodoc consumers before selecting how to provide it; do not merely replace the current heuristic with a different directory-name guess.

Review all consumers before changing the return contract. Relevant locations include:

- `cp/cellprofiler/gui/help/content.py`: `image_resource()`, `read_content()`, `image_resource_dataUrl()`.
- `cp/cellprofiler/gui/_welcome_frame.py`: data URL consumers.
- `cp/cellprofiler/modules/_help.py` and several individual modules: image references embedded into module help at import time.
- `cp/cellprofiler/gui/html/utils.py`: converts RST through `docutils.core.publish_parts()`.
- `cp/cellprofiler/gui/html/htmlwindow.py`: wx HTML URL handling; existing `memory:` support is useful context.
- `core/cellprofiler_core/utilities/image.py`: separate helper and frozen-mode behavior.
- `cp/docs/Makefile` and `cp/docs/source/conf.py`: documentation copying and build setup.

Windows wx rendering of `Path.as_uri()` output must be tested; only the Docutils conversion was verified here. Do not consider the URI approach production-ready based on that conversion alone.

## Verification performed and limitations

An isolated Python harness extracted the actual frontend `image_resource()` function from its AST, supplied Windows `ntpath` behavior with mocked resource lookup and relative-path results, and confirmed:

1. The current function propagates the simulated cross-drive `ValueError`.
2. The posted whole-function replacement returns `None` on the same-drive path.
3. Its cross-drive fallback returns the absolute path with forward slashes.

The harness also ran real Docutils conversion to confirm the space-removal behavior described above, and demonstrated that a relative resource reference that exists from the initial directory does not resolve from a different directory.

These were targeted checks on macOS, not a Windows GUI reproduction. Installed versions reported Docutils 0.15.2 and wxPython 4.2.4 / wxWidgets 3.2.8 (macOS Cocoa). No application test suite or Sphinx build was run. `cp/tests/gui/html/test_manual.py` exists but is entirely commented out, so it does not currently provide active regression coverage.

## Validation required before shipping

- Regression coverage for same-drive and cross-drive resource resolution, including different Windows drive letters and UNC paths where practical.
- Installation/resource paths containing spaces, non-ASCII characters, `#`, and `%`; verify the generated image references point at the original assets.
- Launch the Windows GUI from a different drive; confirm startup, help images, module help, and welcome-screen images.
- Verify cached runtime image references still work after a working-directory change.
- Check frozen Windows behavior if modifying the core helper or supporting bundled distributions.
- Build the 4.2.x manual and verify both copied help pages and autodoc-generated module help use portable images, without local installation paths or `file:` URLs.

Use the repository's pixi environment for execution. The local development guide specifies `pixi run -e dev pytest ...` and discourages installing dependencies through other package managers.

## Useful commands to resume

```sh
gh issue view 5169 --repo CellProfiler/CellProfiler --json title,body,comments,url,state
git -C cp branch --show-current
git -C cp rev-parse HEAD
git -C core rev-parse HEAD
rg -n 'image_resource|image_resource_dataUrl|read_content' cp/cellprofiler core/cellprofiler_core
```

The requested task so far was investigation and proposal, followed by writing this handoff. Implementing or publishing a fix was not part of the completed work.
