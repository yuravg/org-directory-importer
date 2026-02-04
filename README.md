# org-directory-importer

Import directory structures into Org-mode as executable Babel source blocks with automatic
language detection, gitignore support, and full tangle capability.

## Overview

Recursively converts directory trees into Org-mode documents where each file becomes a properly
formatted Babel source block. Supports automatic language detection, respects `.gitignore`
patterns, detects binary files, and enables full round-trip tangling to recreate the original
structure.

## Requirements

- Emacs 24.4 or later
- Org-mode 9.0 or later

## Installation

### Manual Installation

Clone or download this repository, then add to your Emacs configuration:

```elisp
(add-to-list 'load-path "/path/to/org-directory-importer")
(require 'org-directory-importer)
```

### Using use-package

```elisp
(use-package org-directory-importer
  :load-path "path/to/org-directory-importer")
```

## Usage

### Basic Usage

1. Open an Org-mode buffer
2. Position your cursor where you want to insert the directory structure
3. Run: `M-x org-directory-import`
4. Select the directory to import

The package will create a hierarchical Org structure with:
- Top-level heading with import metadata (source path, timestamp)
- Nested headings for each directory
- Babel source blocks for each file with `:tangle` properties

### Commands

- `org-directory-importer-import` - Import a directory with metadata and change tracking
  - Use `C-u` prefix for plain import without metadata
- `org-directory-importer-import-plain` - *(Deprecated: use `C-u org-directory-importer-import` instead)*
- `org-directory-importer-import-file` - Import a single file unconditionally with change-tracking metadata
- `org-directory-importer-import-update` - Update an existing tracked import with file system changes
- `org-directory-importer-prune-metadata` - Remove all IMPORT_* properties from current buffer

### Single File Import

Import a single file without directory structure or filtering constraints:

```elisp
M-x org-directory-importer-import-file RET /path/to/file.py RET
```

This command:
- Imports **any file** regardless of exclusion patterns or gitignore rules
- Does not check for binary content or enforce size limits
- Creates a heading with metadata for change tracking
- Useful for importing files from non-tracked sources or breaking filter constraints

The file can be updated incrementally using `org-directory-importer-import-update`.

### Plain Import (Without Metadata)

Import a directory without change-tracking metadata:

```
C-u M-x org-directory-importer-import RET /path/to/directory RET
```

This imports the structure without:
- The top-level metadata heading (IMPORT_SOURCE, IMPORT_DATE)
- File-level IMPORT_* properties (IMPORT_PATH, IMPORT_CHECKSUM, etc.)

Use this when you want plain content that cannot be incrementally updated.

### Removing Metadata

To remove all tracking metadata from an existing import:

```
M-x org-directory-importer-prune-metadata
```

This removes all IMPORT_* properties from all headings in the buffer while
preserving the content itself. After pruning, `org-directory-importer-import-update`
will no longer work on the affected entries.

### Tangling

Run `C-c C-v t` (`org-babel-tangle`) to recreate the original directory structure from imported blocks.

## Configuration

### Exclude Patterns

Customize which files and directories to skip during import:

```elisp
(setq org-directory-importer-excluded-patterns
      '("tmp" ".git" ".svn" ".hg"
        "node_modules" "__pycache__"
        "*.pyc" "*.o" "*.so" "*.dll"
        "*~" "#*#" ".#*" "*.log"))
```

Patterns support wildcards (`*` and `?`) and literal names.

### File Size Limit

Set maximum file size to import (default: 1MB, set to `nil` to disable):

```elisp
(setq org-directory-importer-max-file-size (* 2 1024 1024))  ; 2MB
```

### Binary File Detection

Enable/disable binary file detection (default: `t`):

```elisp
(setq org-directory-importer-detect-binary-files t)
```

### Gitignore Support

Respect local and global `.gitignore` patterns (both default to `t`):

```elisp
(setq org-directory-importer-respect-gitignore-local t)
(setq org-directory-importer-respect-gitignore-global t)
```

Patterns are cached for performance. Run `M-x org-directory-importer-clear-gitignore-cache`
after modifying `.gitignore` files.

**Supported patterns:** wildcards, directory patterns (`build/`), rooted patterns (`/config`), path patterns (`src/**`)
**Not supported:** negation patterns (`!important.log`)

### Language Mappings

Customize language detection (30+ languages supported by default):

```elisp
(add-to-list 'org-directory-importer-language-mappings '("jsx" . "javascript"))
```

### Tangle Path Type

Choose between relative or absolute paths in `:tangle` properties (default: `'relative`):

```elisp
;; Relative paths (default) - portable, path starts with './'
(setq org-directory-importer-tangle-path-type 'relative)

;; Absolute paths - tangle to exact system locations
(setq org-directory-importer-tangle-path-type 'absolute)
```

Use relative for portable documents, absolute for fixed system locations.

### Empty Directory Handling

Preserve empty directories as headings (default: `nil` skips them):

```elisp
(setq org-directory-importer-include-empty-directories t)
```

## Use Cases

- Document codebases with annotations
- Create literate programs that tangle to source files
- Archive/share project structures in portable Org format
- Build annotated code examples for learning

## License

See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
