# Module Refactor Pattern: Frontend Module -> `cellprofiler_library`

Captures the repeatable refactor applied to three CellProfiler Modules in
this branch window:

- `measureobjectsizeshape` (`e8a5e21d0` .. `c81a19eaf`)
- `measureobjectneighbors` (`e533479a1` .. `9880bd09c`)
- `measureimagequality` (freshest; `88be5a7dd` .. `53b2372ff`)

Goal: move math / image-processing / measurement-producing logic out of
`src/frontend/cellprofiler/modules/<name>.py` into `cellprofiler_library`.
The frontend module becomes a thin "settings + workspace plumbing" layer.

When the older modules disagree with `measureimagequality`, prefer the
`measureimagequality` shape - the pattern matured across the three.

---

## 1. The 3-layer architecture

Made explicit in commits `04dfbf391` and `a3d62913d` (both titled
"Refactor ... to 3-layer architecture"):

1. **Layer 1 - Pure math/image-processing functions**
   (`cellprofiler_library/functions/*.py`).
   No CellProfiler awareness. Arrays in, arrays/dicts/tuples out. No
   feature-name strings, no `LibraryMeasurements`, no enums. Decomposed
   into small focused helpers. Lives in `functions/measurement.py`,
   `functions/segmentation.py`, `functions/object_processing.py`,
   `functions/image_processing.py`, or `functions/file_processing.py`.

2. **Layer 2 - Library module entry point**
   (`cellprofiler_library/modules/_<name>.py`).
   One public `@validate_call`-decorated function named after the module
   (`measureobjectsizeshape`, `measure_object_neighbors`, `measure_image_quality`
   - prefer snake_case). Orchestrates Layer 1, formats feature names,
   packs results into `LibraryMeasurements`. Optionally returns a
   `<Name>DisplayData` pydantic model.

3. **Layer 3 - Frontend module**
   (`src/frontend/cellprofiler/modules/<name>.py`).
   The `Module` subclass: settings, `create_settings`, `visible_settings`,
   `settings`, `get_measurement_columns`, `get_categories`,
   `get_measurements`, `get_measurement_scales`, `validate_module`,
   `upgrade_settings`, `display`. Plus a slim `run()` that
   (a) gathers inputs from `workspace`, (b) calls the Layer-2 function,
   (c) unpacks the returned `LibraryMeasurements` into core `Measurements`,
   (d) optionally unpacks `<Name>DisplayData` onto `workspace.display_data`.

Rule of thumb: the frontend module no longer imports `numpy`, `scipy`,
`skimage`, or `centrosome`. Cleanup commits `558055fd1` and `069e71e4d`
ratify this.

---

## 2. Canonical phased plan

One commit per phase. The commit subject prefix is `[<module>]: (N) ...`.

### Phase (1): opts/enums + stub library module + rewire to enums

Refs: `e8a5e21d0`, `e533479a1`, `88be5a7dd`. No behavior change.

- Create `src/subpackages/library/cellprofiler_library/opts/<name>.py` with
  the module's enums and string constants (see section 3).
- Create literally empty
  `src/subpackages/library/cellprofiler_library/modules/_<name>.py`.
- Edit the frontend module to import its constants from `opts/<name>.py`
  instead of defining them locally.
- Edit `tests/frontend/modules/test_<name>.py` accordingly. Module-attribute
  accesses like `cellprofiler.modules.measureimagequality.F_TOTAL_VOLUME`
  become `Feature.TOTAL_VOLUME.value`.

### Phase (2): decompose the FE `run()` body into helper methods

Refs: `a8e5d9774`, `abd931c52`. Frontend file only. Cut the big `run()`
into smaller `def <verb>(self, ...):` methods on the same class. Pure
cut-and-paste; no algorithmic change. This sets up phase 3.

### Phase (3): move helpers out of the FE class into `modules/_<name>.py`

Refs: `a5244de1a`, `9dccd1e6d`.

- Cut helpers from the frontend class to free functions in
  `cellprofiler_library/modules/_<name>.py`.
- Drop `self.` access by threading values in as parameters.
- Trim signatures: anything derivable from other params becomes a local
  derivation (commit `a5244de1a` is explicit about this).
- Pure-math helpers go to `cellprofiler_library/functions/<category>.py`.
  Pick the right category (commit `8e23e0c2c` rebalanced
  `object_processing` -> `segmentation` for some helpers).

### Phase (4): move the public function into the library; add type annotations

Refs: `8e0ed84bc`, `5acbc2678`.

- The frontend's `run()` shrinks to a delegating call.
- Add `@validate_call(config=ConfigDict(arbitrary_types_allowed=True))`.
- Every parameter is `Annotated[<type>, Field(description="...")]`.
- Sometimes this commit also reorders loops for I/O efficiency
  (`5acbc2678`: swap nesting so each image loads once).

### Phase (5) "AI Code": switch return type to `LibraryMeasurements`

Refs: `84af28f13`, `8379f3d69`, `446c70196`. Commit subject is always
`[<module>][AI Code]: ...`.

- Layer-2 return type changes from `Dict[str, Any]` (or a raw array tuple)
  to `LibraryMeasurements`.
- The function takes `object_name` / `image_name` so the full feature key
  (`AreaShape_Area`, `Neighbors_NumberOfNeighbors_Nuclei_5`, ...) is
  formatted inside the library, not the frontend.
- Frontend `run()` iterates `lib_measurements.image`,
  `lib_measurements.objects`, and `lib_measurements.get_relationship_groups()`
  to call `m.add_image_measurement(...)`, `m.add_measurement(...)`,
  `m.add_relate_measurement(...)`.
- Big helpers split into smaller ones; redundant parameters dropped.

### Phase (6) cleanup commits

Short, single-issue commits. Load-bearing - they ratify what the AI roughed
in. Typical themes (all documented in section 7):

- Type-annotation fixes; `import numpy` not `import numpy as np`.
- Drop redundant imports.
- Add `return_visualization_data: bool = False` parameter and a
  `<Name>DisplayData` pydantic model.
- Move display-image generation into the library.
- Move statistics-table calc into the library.
- Wrap `workspace.display_data.*` writes in `if self.show_window:`.
- Remove `centrosome.*` from the frontend; route constants via opts.
- Drop satisfied TODOs.

---

## 3. File-layout conventions

```
src/subpackages/library/cellprofiler_library/
  opts/<name>.py              # enums, constants, TemplateMeasurementFormat
  modules/_<name>.py          # public library entry point + DisplayData
  functions/measurement.py    # pure-math per-feature helpers
  functions/segmentation.py   # label/segmentation helpers
  functions/object_processing.py
  functions/image_processing.py
  functions/file_processing.py
  measurement_model.py        # LibraryMeasurements (do not edit per-module)
  types.py                    # ImageGrayscale, ObjectSegmentation, etc.
src/frontend/cellprofiler/modules/<name>.py
tests/frontend/modules/test_<name>.py
```

The leading underscore on `_<name>.py` is convention - the package's
`modules/__init__.py` re-exports without the underscore. The opts file is
NOT underscored. Module name: lowercase, no underscores in the filename
(`measureobjectsizeshape.py`).

---

## 4. Recurring artifacts

### 4.1 `opts/<name>.py` template

```python
from enum import Enum

# Top-level category constant (the feature-name prefix).
C_<NAME> = "<Name>"

class Feature(str, Enum):                  # MUST inherit from (str, Enum)
    FOO = "Foo"
    BAR = "Bar"
    ...

# Grouped lists go OUTSIDE the Enum class (commit e8a5e21d0 moved them out;
# nested lists inside Enum end up as enum members).
F_GROUP_A = [Feature.FOO, Feature.BAR]
F_GROUP_B = [Feature.BAZ]

# Optional: a printf-template holder (NOT an Enum) for the library to
# format feature names. Modeled by TemplateMeasurementFormat in
# opts/measureimagequality.py.
class TemplateMeasurementFormat(str):
    IQ_FOO = f"{C_<NAME>}_{Feature.FOO.value}_%s"

# If the module mirrors centrosome constants, re-bind them here so the
# frontend never imports centrosome directly (commit 069e71e4d).
from centrosome.threshold import TM_OTSU, TM_MOG, TM_METHODS
class ScaledThresholdMethod(str, Enum):
    OTSU = TM_OTSU
    MOG  = TM_MOG
THRESHOLD_METHODS = TM_METHODS
```

Rules from cleanup commits:
- Every Enum is `(str, Enum)`, not bare `Enum` (`e8a5e21d0`).
- Do NOT define `__str__(self): return self.value` on enums (`8e23e0c2c`).
- Group lists are module-level, not nested inside the enum class.
- Re-export centrosome constants through this file.

### 4.2 `modules/_<name>.py` template

```python
import numpy
from numpy.typing import NDArray
from typing import Annotated, Optional, List, Tuple, Union, Any
from pydantic import BaseModel, Field, validate_call, ConfigDict

from cellprofiler_library.types import ImageGrayscale, ImageGrayscaleMask  # etc.
from cellprofiler_library.measurement_model import LibraryMeasurements
from cellprofiler_library.opts.<name> import Feature, C_<NAME>, ...
from cellprofiler_library.functions.measurement import helper_one, helper_two

<Name>Statistics = List[Tuple[str, str, ...]]  # row schema for display table

class <Name>DisplayData(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True, populate_by_name=True)
    statistics: <Name>Statistics
    # plus any precomputed image arrays needed by Module.display()

@validate_call(config=ConfigDict(arbitrary_types_allowed=True))
def <name>(
    image:                     Annotated[ImageGrayscale, Field(description="...")],
    image_name:                Annotated[str, Field(description="...")],
    ...
    return_visualization_data: Annotated[bool, Field(description="Return data for display")] = False,
) -> Union[LibraryMeasurements, Tuple[LibraryMeasurements, <Name>DisplayData]]:
    measurements = LibraryMeasurements()
    statistics: <Name>Statistics = []

    def add_measurement(...):
        # local closure: write to `measurements`, append to `statistics`
        # if return_visualization_data
        ...

    # ... math, calling functions/* helpers ...

    if return_visualization_data:
        return measurements, <Name>DisplayData(statistics=statistics, ...)
    return measurements
```

Conventions:
- Return either `LibraryMeasurements` or
  `Tuple[LibraryMeasurements, <Name>DisplayData]` keyed on
  `return_visualization_data`.
- A local closure `add_measurement(...)` keeps measurements and stats rows
  in lockstep. Without it you'll forget to append display rows.
- Feature names are fully formatted inside the library
  (e.g. `f"{C_IMAGE_QUALITY}_{Feature.FOCUS_SCORE.value}_{image_name}"` or
  `TemplateMeasurementFormat.IQ_FOCUS_SCORE % image_name`). The frontend
  passes them through verbatim (see gotcha 7.4).

### 4.3 Frontend `run()` skeleton

```python
def run(self, workspace):
    objects = workspace.get_objects(self.object_name.value)
    image   = workspace.image_set.get_image(image_name, must_be_grayscale=True)

    # Broader than self.show_window if there are also image-output toggles.
    wants_lib_display = self.show_window or self.wants_<some_image>.value

    res = <name>(..., return_visualization_data=wants_lib_display)
    if wants_lib_display:
        lib_measurements, lib_display = res
    else:
        lib_measurements = res

    m = workspace.measurements
    # TODO #5122: replace these three loops with one helper
    for feature_name, value in lib_measurements.image.items():
        m.add_image_measurement(feature_name, value)
    for object_name, features in lib_measurements.objects.items():
        for feature_name, data in features.items():
            m.add_measurement(object_name, feature_name, data)
    for relationship in lib_measurements.get_relationship_groups():
        data = lib_measurements.get_relationships(
            relationship.relationship, relationship.object_name1, relationship.object_name2,
        )
        img_nums = numpy.ones(len(data), int) * m.image_set_number
        m.add_relate_measurement(
            self.module_num,
            relationship.relationship,
            relationship.object_name1, relationship.object_name2,
            img_nums, data[R_FIRST_OBJECT_NUMBER],
            img_nums, data[R_SECOND_OBJECT_NUMBER],
        )

    if self.show_window:
        workspace.display_data.statistics = lib_display.statistics
        workspace.display_data.col_labels = (...)
        # plus any image arrays needed by .display()
```

---

## 5. `LibraryMeasurements` integration

Defined in
`src/subpackages/library/cellprofiler_library/measurement_model.py`.

Shape:
- `image: Dict[str, Any]` - full image-feature names as keys.
- `objects: Dict[str, Dict[str, Any]]` - outer key is object name
  (e.g. `"Nuclei"`), inner key is the full feature name
  (e.g. `"AreaShape_Area"`).
- `experiment: Dict[str, Any]` - experiment-level features.
- `relationships: List[Relationship]`.

Useful methods:
- `add_measurement(object_name, feature_name, data)` - routes to
  image/objects/experiment based on `object_name`.
- `add_image_measurement(feature_name, data)`,
  `add_experiment_measurement(feature_name, data)`.
- `add_relate_measurement(rel, name1, name2, nums1, nums2)` - merges into
  an existing group or appends. No-op when `len(object_numbers1) == 0`.
- `get_relationship_groups()` -> `List[RelationshipBase]`.
- `get_relationships(rel, name1, name2)` -> recarray with two fields
  `R_FIRST_OBJECT_NUMBER`, `R_SECOND_OBJECT_NUMBER`.

Unpacking on the frontend:

| Library                                   | Core Measurements                                                   |
| ----------------------------------------- | ------------------------------------------------------------------- |
| `lib_measurements.image[name] = v`        | `m.add_image_measurement(name, v)`                                  |
| `lib_measurements.objects[obj][name] = v` | `m.add_measurement(obj, name, v)`                                   |
| `lib_measurements.relationships`          | iterate groups, fetch, call `m.add_relate_measurement(self.module_num, rel, n1, n2, img_nums, first_nums, img_nums, second_nums)` |
| `lib_measurements.experiment[name] = v`   | `m.add_experiment_measurement(name, v)`                             |

Relationship notes:
- `Relationship` stores only `(relationship, object_name1, object_name2,
  object_numbers1, object_numbers2)`. Module-number and image-set-number
  are pipeline-specific and injected by the frontend (commit `4d2dcedc3`).
- The frontend computes
  `img_nums = numpy.ones(n_records, int) * m.image_set_number`
  and passes it twice (for first and second). Also supplies
  `self.module_num`.
- `Relationship.__deepcopy__` needs the `memo` arg (commit `2d67540a6`).

Reverse direction: `Measurements.to_library_measurements()` exists for
tests / introspection (commit `2d67540a6`).

---

## 6. Display-data pattern

The rule: anything `Module.display(workspace, figure)` needs - statistics
rows, colormapped images, expanded label maps - is computed in the library,
returned in `<Name>DisplayData`. Refs: `b5cbb5922`, `33d8976e3`,
`45dbde170`, `53b2372ff`, `8f52c79cd`.

```python
<Name>Statistics = List[Tuple[str, str, str, str, str]]   # cols as needed

class <Name>DisplayData(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True, populate_by_name=True)
    statistics: <Name>Statistics                            # always present, [] if unused
    # plus precomputed images:
    neighbor_count_image: NDArray[numpy.float64]
    object_mask: ObjectLabelMask
    expanded_labels: Optional[NDArray[numpy.int_]]
```

`statistics` is always declared (start as empty list) so callers see a
consistent shape (`b5cbb5922`).

Frontend wiring:

```python
res = <name>(..., return_visualization_data=wants_lib_display)
if wants_lib_display:
    lib_measurements, lib_display = res
else:
    lib_measurements = res

# ... unpack measurements ...

if self.show_window:
    workspace.display_data.statistics = lib_display.statistics
    workspace.display_data.col_labels = ("Object", "Feature", "Mean", "Median", "STD")
    workspace.display_data.<image_array> = lib_display.<image_array>

def display(self, workspace, figure):
    figure.set_subplots((1, 1))
    figure.subplot_table(0, 0, workspace.display_data.statistics,
                         col_labels=workspace.display_data.col_labels)
```

Wrap EVERY `workspace.display_data.*` write in `if self.show_window:`
(`4d69e6b29`).

`wants_lib_display` may be broader than `self.show_window` if the module
also produces optional output images (e.g. `wants_count_image`,
`wants_percent_touching_image`). Commit `9880bd09c` is the canonical
example.

---

## 7. Recurring gotchas (with the commit that fixed each)

### 7.1 Forgetting `.value` on a setting (`9880bd09c`)

`Binary`, `Choice`, etc. are objects, not scalars. Truthy-testing them
returns `True` unconditionally. Always use `.value`:
```python
wants_lib_display = self.show_window or self.wants_count_image.value
```

### 7.2 Mixing measurement-class name with measurement name in display (`4b25ec177`)

Statistics rows are `(name, value)`, not `(class, value)`. When iterating
`results_dict`, destructure as `measurement_name, measurement_value`,
not `measurement_class, measurement_items` then reusing the outer name.

### 7.3 Inconsistent mask parameter naming (`bf09a5b97`)

Image masks: `image_mask` (paired with `ImageGrayscaleMask` /
`ImageBinaryMask`). Object masks: `object_mask` (paired with
`ObjectLabelMask`). Never bare `mask`. Frontend call sites must pass
`image_mask=image.mask`.

### 7.4 Double-prefixing feature names on unpack

The library returns fully-formatted names (`"AreaShape_Area"`,
`"Neighbors_NumberOfNeighbors_Nuclei_5"`). When unpacking, do NOT
re-prepend the category. The measureobjectsizeshape unpack loop guards
against this:
```python
if not feature_name.startswith(ObjectSizeShapeFeatures.AREA_SHAPE.value):
    f = "%s_%s" % (ObjectSizeShapeFeatures.AREA_SHAPE.value, feature_name)
else:
    f = feature_name
```
For new modules, emit the fully-prefixed name in the library and have the
frontend pass it through verbatim.

### 7.5 `import numpy as np` (`507a0b243`, `d4cb33361`)

House style is `import numpy`. The AI sometimes emits `np`. Normalize.

### 7.6 Type annotations not aligned with `validate_call` (`21cca4171`)

`@validate_call` rejects loose types at first call. Use
`ImageGrayscale`, `ImageGrayscaleMask`, `ObjectSegmentation`,
`ObjectLabelMask` from `cellprofiler_library.types`; `NDArray[numpy.int_]`,
`NDArray[numpy.float_]` from `numpy.typing`; `Optional[Tuple[float, ...]]`
for spacing, never bare `Tuple`.

Conversely, remove redundant runtime type checks from inside
`functions/measurement.py` (`8034d040c`) - the Layer-2 `@validate_call`
already checks; Layer-1 helpers don't need to repeat it.

### 7.7 Centrosome leaking into the frontend (`558055fd1`, `069e71e4d`)

Anything the frontend imports from `centrosome.*` should be re-exported via
`opts/<name>.py` or pushed into the library function.
`opts/measureimagequality.py` is the model: imports `TM_OTSU`, `TM_MOG`,
`TM_METHODS` from `centrosome.threshold` and re-exposes them as
`ScaledThresholdMethod`, `THRESHOLD_METHODS`.

### 7.8 Dead imports left behind (`ee54a9bfc`, `9be230568`, `70993a769`)

Skim the import block of every touched file before opening the PR.

### 7.9 Helper in the wrong `functions/*.py` (`8e23e0c2c`)

Segmentation helpers belong in `segmentation.py`, not
`object_processing.py`. Won't break tests; will get flagged in review.

### 7.10 Empty / no-object input paths

`measureobjectsizeshape` handles "no objects" by zipping feature names
with `numpy.zeros((0,))`. `measure_object_neighbors` guards
`if len(first_objects) > 0:` before `add_relate_measurement`.
Tests exercise these branches.

### 7.11 `Optional[...]` defaults must stay None

Spacing defaults to `None`, not `(1.0, 1.0)`. The function fills in
`(1.0,) * labels.ndim` internally. Concrete defaults break 3D callers.

### 7.12 Shadowing names that core re-exports (`8b1e7d28e`)

If `cellprofiler_core/object/_objects.py` re-imports a function from
`cellprofiler_library.functions.segmentation` AND defines a method with
the same name, alias the imports as `_relate_labels`, `_relate_histogram`,
`_histogram_from_labels`. Public API does not change.

### 7.13 `LibraryMeasurements.relationships` default (`d4cb33361`)

Must be `Field(default_factory=list[Relationship])`, not bare `list`.
Pydantic v2 wants the generic.

---

## 8. Testing

Tests stay in `tests/frontend/modules/test_<name>.py`. They're end-to-end
tests against the frontend `Module` class - the same fixtures that
exercised the monolithic `run()` exercise the new delegating `run()`.

Adjustments:
1. Imports: `cellprofiler.modules.<name>.FEATURE_X` becomes
   `cellprofiler_library.opts.<name>.Feature.X.value`.
2. Where the test asserted on a constant, switch to the enum form, e.g.
   `for measurement in F_STANDARD + F_STD_2D: assert measurement.value in measurements`
   (note `.value` because members are no longer raw strings).

Library-level unit tests exist for shared infrastructure
(`tests/library/functions/test_library_measurements.py`) but NOT for each
module's library entry point - the frontend tests cover that transitively.
The exception is changes that touch `LibraryMeasurements` itself; those
get unit tests there.

Run:
```bash
pixi run -e dev pytest tests/frontend/modules/test_<name>.py
pixi run -e dev pytest tests/library   # if LibraryMeasurements changed
```

---

## 9. Concrete checklist for a new module

One commit per phase, in order.

- [ ] **(1)** Create `opts/<name>.py` with `(str, Enum)` enums, top-level
  `C_<NAME>`, module-level grouped lists, optional
  `TemplateMeasurementFormat(str)` class. Re-export any centrosome
  constants. Create empty `modules/_<name>.py`. Rewire the frontend
  module and `tests/frontend/modules/test_<name>.py` to import from the
  new opts. Verify the existing test suite still passes.
- [ ] **(2)** Decompose the FE `run()` into helper methods on the same
  class. No logic changes.
- [ ] **(3)** Move helpers from the FE class to free functions in
  `modules/_<name>.py`. Drop `self.` access. Trim signatures. Pure-math
  helpers go in `functions/{measurement,segmentation,...}.py`.
- [ ] **(4)** Move the public function into the library. Frontend `run()`
  becomes a delegating call. Add `@validate_call(config=ConfigDict(arbitrary_types_allowed=True))`
  and `Annotated[..., Field(description=...)]` on every parameter.
- [ ] **(5) [AI Code]** Convert return type to `LibraryMeasurements` (or
  `Union[LibraryMeasurements, Tuple[LibraryMeasurements, <Name>DisplayData]]`).
  Move feature-name formatting into the library. Frontend does the
  unpack-into-workspace loop. Split monolithic helpers.
- [ ] **(6) Cleanup commits**, each tiny and one-issue:
  - [ ] Add `return_visualization_data: bool = False` + `<Name>DisplayData`
    with `statistics` field.
  - [ ] Move stats-row generation into the library (closure
    `add_measurement(...)` packs into both).
  - [ ] Move display-image generation into the library if the module
    produces image outputs.
  - [ ] Wrap every `workspace.display_data.*` write in
    `if self.show_window:`.
  - [ ] Compute `wants_lib_display` correctly: `self.show_window or
    self.<other-toggle>.value` for every output toggle.
  - [ ] Remove every `centrosome.*`/`skimage.*`/`scipy.*` import from the
    frontend; route through opts or library.
  - [ ] `import numpy` not `import numpy as np`.
  - [ ] Delete redundant imports in all three touched files.
  - [ ] Audit parameter names: `image_mask` not `mask`; `object_mask` for
    object label masks.
  - [ ] Audit feature-name prefixing: library returns full name; frontend
    passes through unchanged.
  - [ ] Delete `__str__` overrides on enum classes.
  - [ ] Delete TODOs that are now satisfied.
- [ ] Run `pixi run -e dev pytest tests/frontend/modules/test_<name>.py`
  until green.
- [ ] Open the PR. Commit subjects follow `[<name>] ...` and
  `[<name>][AI Code]: ...`.

---

## Appendix: canonical commits per phase

| Phase                          | Sizeshape   | Neighbors   | Imagequality |
| ------------------------------ | ----------- | ----------- | ------------ |
| (1) opts + enums + empty file  | `e8a5e21d0` | `e533479a1` | `88be5a7dd`  |
| (2) decompose `run()`          | -           | `abd931c52` | `a8e5d9774`  |
| (3) move helpers out of FE     | -           | `a5244de1a` | `9dccd1e6d`  |
| (4) move pub fn + annotations  | -           | `8e0ed84bc` | `5acbc2678`  |
| 3-layer refactor               | `04dfbf391` | `a3d62913d` | (in AI commit) |
| [AI Code]                      | `84af28f13` | `8379f3d69` | `446c70196`  |
| DisplayData / `show_window`    | `45dbde170` | `b5cbb5922` | `069e71e4d`  |
| Stat calc -> library           | `45dbde170` | -           | `53b2372ff`  |
| Display-image gen -> library   | -           | `33d8976e3` | -            |
| `mask` -> `image_mask`         | -           | -           | `bf09a5b97`  |
| numpy alias                    | `507a0b243` | -           | -            |
| centrosome via opts            | `558055fd1` | -           | `069e71e4d`  |
| `wants_lib_display` / `.value` | -           | `9880bd09c` | -            |
| Feature/class display mixup    | -           | -           | `4b25ec177`  |
| `Relationship` model fixes     | -           | `2d67540a6`, `9e88d28d4` | - |
| Shadow core/_objects imports   | -           | `8b1e7d28e` | -            |

Cross-module statistics-pattern references: `8f52c79cd`
(measureobjectintensity) and `4d69e6b29` (measureimageintensity
`show_window` guard) - both adopt the same `return_visualization_data` /
`<Name>DisplayData.statistics` convention.
