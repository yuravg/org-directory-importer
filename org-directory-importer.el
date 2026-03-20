;;; org-directory-importer.el --- Import directory structures as Org Babel source blocks  -*- lexical-binding: t; -*-

;; Author: Yuriy VG <yuravg@gmail.com>
;; Version: 1.5.0
;; URL: https://github.com/yuravg/org-directory-importer
;; Keywords: org, babel, files, import
;; Package-Requires: ((emacs "29.1") (org "9.0"))

;;; Commentary:

;; Recursively import directory structures into Org-mode documents as
;; tangleable Babel source blocks.  The package preserves directory
;; hierarchy and enables literate programming workflows.
;;
;; FEATURES:
;; - Recursive directory tree import with automatic language detection
;; - Three-layer filtering: pattern matching, gitignore, binary detection
;; - Supports tangling with relative paths and automatic directory creation
;;
;; AVAILABLE COMMANDS:
;;
;; `org-directory-importer-import' (Main command)
;;   Import a directory with metadata header and timestamp.
;;   Inserts a top-level heading containing import source and date.
;;   Use this for documenting where content came from and incremental updates.
;;   With C-u prefix: Import without any metadata (plain content).
;;
;; `org-directory-importer-import-plain'
;;   Import a directory directly at point without metadata wrapper.
;;   Now wraps `org-directory-importer-import' with skip-metadata.
;;   Use C-u M-x org-directory-importer-import instead.
;;
;; `org-directory-importer-import-file'
;;   Import a single file unconditionally at point.
;;   Creates a heading with a tangleable source block and change-tracking metadata.
;;   Unlike directory imports, bypasses all filters (patterns, gitignore, binary checks).
;;   Use this for importing specific files or files from non-tracked sources.
;;   With C-u prefix: Import without any metadata (plain content).
;;
;; `org-directory-importer-prune-metadata'
;;   Remove all IMPORT_* properties from current buffer.
;;   Cleans up change-tracking metadata while preserving content.
;;   Use after importing to convert tracked imports to plain content.
;;
;; `org-directory-importer-refresh-block'
;;   Refresh source block at point from its tangle target file.
;;   Re-reads the file specified in :tangle and updates block content.
;;   If IMPORT_* metadata exists, updates checksum, size, and mtime.
;;   Use when external changes were made to the source file.
;;
;; `org-directory-importer-import-update'
;;   Update an existing import incrementally (requires IMPORT_SOURCE property).
;;   Detects changes: modified files, new files, deleted files.
;;
;; `org-directory-importer-clear-gitignore-cache'
;;   Clear cached gitignore patterns to force re-reading.
;;   Use this after modifying .gitignore files.
;;
;; QUICK START:
;;   M-x org-directory-importer-import RET
;;   Select a directory, and the structure will be inserted at point.
;;
;; FILTERING:
;; Files are excluded through three complementary layers:
;;
;; 1. Pattern matching (customize `org-directory-importer-excluded-patterns')
;;    Fast wildcard-based exclusion for images, archives, etc.
;;
;; 2. Gitignore integration (respects local and global .gitignore)
;;    Enable/disable via `org-directory-importer-respect-gitignore-*'
;;
;; 3. Binary detection (samples first 8KB for null bytes)
;;    Enable/disable via `org-directory-importer-detect-binary-files'

;;; Code:

(require 'org)
(require 'seq)
(require 'cl-lib)

;;; Customization

(defgroup org-directory-importer nil
  "Import directory structures into Org-mode as Babel source blocks."
  :group 'org
  :prefix "org-directory-importer-")

(defcustom org-directory-importer-excluded-patterns
  '(;; Version control and temporary directories
    "tmp" ".git" ".svn" ".hg" "node_modules" "__pycache__"
    ;; Compiled and temporary files
    "*.pyc" "*.o" "*.so" "*.dll" "*~" "#*#" ".#*" "*.log"
    ;; Image files (SVG is text-based XML but shouldn't be imported)
    "*.svg" "*.png" "*.jpg" "*.jpeg" "*.gif" "*.ico" "*.webp"
    "*.bmp" "*.tiff" "*.tif"
    ;; Media files
    "*.mp4" "*.avi" "*.mov" "*.mkv" "*.wmv" "*.flv"
    "*.mp3" "*.wav" "*.ogg" "*.flac" "*.aac" "*.m4a"
    ;; Archive files
    "*.zip" "*.tar" "*.gz" "*.bz2" "*.xz" "*.7z" "*.rar"
    "*.tar.gz" "*.tgz" "*.tar.bz2" "*.tbz2"
    ;; Document and binary formats
    "*.pdf" "*.doc" "*.docx" "*.xls" "*.xlsx" "*.ppt" "*.pptx"
    ;; Font files
    "*.ttf" "*.otf" "*.woff" "*.woff2" "*.eot"
    ;; Database files
    "*.db" "*.sqlite" "*.sqlite3")
  "List of file and directory patterns to exclude during import.
Supports wildcards (* and ?) and literal names."
  :type '(repeat string)
  :group 'org-directory-importer)

(defcustom org-directory-importer-language-mappings
  '(("bat"       . "bat")
    ("c"         . "c")
    ("h"         . "c")
    ("cc"        . "cpp")
    ("cpp"       . "cpp")
    ("cxx"       . "cpp")
    ("hpp"       . "cpp")
    ("hxx"       . "cpp")
    ("conf"      . "conf")
    ("config"    . "conf")
    ("css"       . "css")
    ("el"        . "emacs-lisp")
    ("go"        . "go")
    ("html"      . "html")
    ("htm"       . "html")
    ("ini"       . "conf")
    ("java"      . "java")
    ("js"        . "javascript")
    ("json"      . "json")
    ("jsx"       . "javascript")
    ("lisp"      . "lisp")
    ("md"        . "markdown")
    ("org"       . "org")
    ("php"       . "php")
    ("pl"        . "perl")
    ("plantuml"  . "plantuml")
    ("pm"        . "perl")
    ("ps1"       . "powershell")
    ("py"        . "python")
    ("rb"        . "ruby")
    ("rs"        . "rust")
    ("rst"       . "rst")
    ("sh"        . "shell-script")
    ("bash"      . "shell-script")
    ("sql"       . "sql")
    ("sv"        . "verilog")
    ("svh"       . "verilog")
    ("v"         . "verilog")
    ("do"        . "tcl")
    ("tcl"       . "tcl")
    ("toml"      . "toml")
    ("ts"        . "typescript")
    ("tsx"       . "typescript")
    ("txt"       . "text")
    ("xml"       . "xml")
    ("yaml"      . "yaml")
    ("yml"       . "yaml")
    ("makefile"  . "makefile")
    ("Makefile"  . "makefile")
    ("mk"        . "makefile")
    ("cmake"     . "cmake")
    ("CMakeLists.txt" . "cmake"))
  "Mapping of file extensions and names to Org Babel language identifiers.
Keys can be file extensions (without dot) or full filenames."
  :type '(alist :key-type string :value-type string)
  :group 'org-directory-importer)

(defcustom org-directory-importer-max-file-size (* 1024 1024)
  "Maximum file size in bytes to import (default 1MB).
Files larger than this will be skipped with a warning."
  :type 'integer
  :group 'org-directory-importer)

(defcustom org-directory-importer-detect-binary-files t
  "When non-nil, skip files that appear to be binary.
This helps prevent corrupting the Org buffer with binary data."
  :type 'boolean
  :group 'org-directory-importer)

(defcustom org-directory-importer-respect-gitignore-local t
  "When non-nil, respect local .gitignore patterns during import.
Reads patterns from .gitignore files in the directory tree up to
repository root."
  :type 'boolean
  :group 'org-directory-importer)

(defcustom org-directory-importer-respect-gitignore-global t
  "When non-nil, respect global Git ignore patterns during import.
Reads patterns from the global Git ignore file configured in Git."
  :type 'boolean
  :group 'org-directory-importer)

(defcustom org-directory-importer-include-empty-directories nil
  "When non-nil, create headings for empty directories.
When nil (default), directories that contain no importable files
after filtering are skipped entirely.  When t, empty directories
are preserved as headings without content."
  :type 'boolean
  :group 'org-directory-importer)

(defcustom org-directory-importer-tangle-path-type 'relative
  "Type of path to use in :tangle properties.
- `relative': Use relative paths starting with \\='./' (default)
- `absolute': Use absolute paths to files"
  :type '(choice (const :tag "Relative paths (./...)" relative)
                 (const :tag "Absolute paths (/...)" absolute))
  :group 'org-directory-importer)

;;; Internal Functions

;;; Git ignore handling

(defvar org-directory-importer--gitignore-cache nil
  "Cache for gitignore patterns to avoid repeated file reads.
Format: ((base-directory . patterns-list) ...)

The cache persists across imports for performance.  Use
`org-directory-importer-clear-gitignore-cache' after modifying
.gitignore files to force re-reading.")

(defvar org-directory-importer--visited-directories nil
  "Set of canonical paths of directories being processed.
Used to detect symlink cycles during recursive traversal.")

(defvar org-directory-importer--current-org-file nil
  "Canonical path of the Org file being imported into.
Used to prevent importing the Org file into itself.")

(defun org-directory-importer--get-global-gitignore ()
  "Return path to global Git ignore file, or nil if not configured."
  (let ((global-ignore
         (or (ignore-errors
               (string-trim
                (shell-command-to-string "git config --global core.excludesfile")))
             "~/.gitignore_global")))
    (when (and global-ignore (not (string-empty-p global-ignore)))
      (expand-file-name global-ignore))))

(defun org-directory-importer--parse-gitignore-file (file-path)
  "Parse gitignore FILE-PATH and return list of pattern strings.
Ignores comments and empty lines."
  (when (and file-path (file-readable-p file-path))
    (with-temp-buffer
      (insert-file-contents file-path)
      (let ((patterns '()))
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (string-trim (buffer-substring-no-properties
                                    (line-beginning-position)
                                    (line-end-position)))))
            ;; Skip empty lines and comments
            (unless (or (string-empty-p line)
                        (string-prefix-p "#" line))
              (push line patterns)))
          (forward-line 1))
        (nreverse patterns)))))

(defun org-directory-importer--find-gitignore-files (directory)
  "Find all .gitignore files from DIRECTORY up to repository root.
Returns list of .gitignore file paths, ordered from root to deepest."
  (let ((files '())
        (current-dir (expand-file-name directory)))
    (while current-dir
      (let ((gitignore (expand-file-name ".gitignore" current-dir)))
        (when (file-readable-p gitignore)
          (push gitignore files)))
      ;; Stop at git repository root or filesystem root
      (if (or (file-exists-p (expand-file-name ".git" current-dir))
              (string= current-dir (expand-file-name "/")))
          (setq current-dir nil)
        (setq current-dir (file-name-directory (directory-file-name current-dir)))))
    files))

(defun org-directory-importer--get-gitignore-patterns (base-directory)
  "Get all gitignore patterns for BASE-DIRECTORY.
Combines local .gitignore files and global Git ignore file based on settings.
Results are cached per base directory."
  (when (or org-directory-importer-respect-gitignore-local
            org-directory-importer-respect-gitignore-global)
    (or (cdr (assoc base-directory org-directory-importer--gitignore-cache))
        (let ((patterns '()))
          ;; Add global gitignore patterns if enabled
          (when org-directory-importer-respect-gitignore-global
            (let ((global-file (org-directory-importer--get-global-gitignore)))
              (when global-file
                (setq patterns (append patterns
                                       (org-directory-importer--parse-gitignore-file global-file))))))

          ;; Add local .gitignore patterns if enabled
          (when org-directory-importer-respect-gitignore-local
            (dolist (gitignore-file (org-directory-importer--find-gitignore-files base-directory))
              (setq patterns (append patterns
                                     (org-directory-importer--parse-gitignore-file gitignore-file)))))

          ;; Cache the results
          (push (cons base-directory patterns) org-directory-importer--gitignore-cache)
          patterns))))

(defun org-directory-importer--gitignore-match-p (pattern base-dir path)
  "Check if PATH matches gitignore PATTERN relative to BASE-DIR."
  (let* ((rel-path (file-relative-name path base-dir))
         (is-dir (file-directory-p path))
         (pattern-is-dir (string-suffix-p "/" pattern))
         (clean-pattern (string-remove-suffix "/" pattern)))
    ;; Directory-only pattern, skip non-dirs
    (unless (and pattern-is-dir (not is-dir))
      (cond
       ;; Rooted: /build
       ((string-prefix-p "/" clean-pattern)
        (let ((p (string-remove-prefix "/" clean-pattern)))
          (or (equal rel-path p)
              (string-prefix-p (concat p "/") rel-path))))
       ;; Globstar: **/*.log or build/**
       ((string-match-p "\\*\\*" clean-pattern)
        (cond
         ;; **/ prefix: match pattern at any depth
         ((string-prefix-p "**/" clean-pattern)
          (let ((sub-pattern (substring clean-pattern 3)))
            (or (string-match-p (wildcard-to-regexp sub-pattern) rel-path)
                (string-match-p (wildcard-to-regexp sub-pattern)
                                (file-name-nondirectory rel-path)))))
         ;; /** suffix: match everything under directory
         ((string-suffix-p "/**" clean-pattern)
          (let ((dir-pattern (substring clean-pattern 0 -3)))
            (string-prefix-p (concat dir-pattern "/") rel-path)))
         ;; ** somewhere in middle: general case
         (t
          (let ((regex (replace-regexp-in-string
                        "\\*\\*" "[^/]*"
                        (wildcard-to-regexp clean-pattern))))
            (string-match-p regex rel-path)))))
       ;; Path: src/build
       ((string-match-p "/" clean-pattern)
        (or (string-match-p (wildcard-to-regexp clean-pattern) rel-path)
            (string-suffix-p clean-pattern rel-path)))
       ;; Basename: *.log
       (t
        (string-match-p (wildcard-to-regexp clean-pattern)
                        (file-name-nondirectory rel-path)))))))

(defun org-directory-importer--gitignore-exclude-p (path base-directory)
  "Return non-nil if PATH should be excluded based on gitignore patterns.
BASE-DIRECTORY is the root directory for import."
  (when (or org-directory-importer-respect-gitignore-local
            org-directory-importer-respect-gitignore-global)
    (let ((patterns (org-directory-importer--get-gitignore-patterns base-directory)))
      (and patterns
           (cl-some (lambda (pattern)
                      (org-directory-importer--gitignore-match-p
                       pattern base-directory path))
                    patterns)))))

(defun org-directory-importer--should-exclude-p (path &optional base-directory)
  "Return non-nil if PATH should be excluded based on configured patterns.
If BASE-DIRECTORY is provided, also checks gitignore patterns.
Also excludes the current Org file to prevent importing file into itself."
  (let ((basename (file-name-nondirectory path)))
    (or
     ;; Check if this is the current Org file (prevent self-import)
     (and org-directory-importer--current-org-file
          (condition-case nil
              (string= (file-truename path)
                       org-directory-importer--current-org-file)
            (error nil)))
     ;; Check user-configured exclusion patterns
     (seq-some (lambda (pattern)
                 (string-match-p (wildcard-to-regexp pattern) basename))
               org-directory-importer-excluded-patterns)
     ;; Check gitignore patterns if base-directory provided
     (and base-directory
          (org-directory-importer--gitignore-exclude-p path base-directory)))))

(defun org-directory-importer--detect-utf16-p (file-path)
  "Return non-nil if FILE-PATH appears to be UTF-16 encoded text.
Checks for UTF-16 BOM (Byte Order Mark) at the beginning of the file."
  (condition-case nil
      (with-temp-buffer
        (set-buffer-multibyte nil)
        (insert-file-contents-literally file-path nil 0 4)
        (goto-char (point-min))
        (or
         ;; UTF-16 LE BOM: FF FE
         (and (>= (buffer-size) 2)
              (= (char-after 1) #xFF)
              (= (char-after 2) #xFE)
              (or (< (buffer-size) 3)
                  (not (and (= (char-after 3) 0)
                            (= (char-after 4) 0)))))
         ;; UTF-16 BE BOM: FE FF
         (and (>= (buffer-size) 2)
              (= (char-after 1) #xFE)
              (= (char-after 2) #xFF))))
    (error nil)))

(defun org-directory-importer--looks-binary-p (file-path)
  "Return non-nil if FILE-PATH appears to contain binary data.
Checks the first 8000 bytes for null bytes and high proportion of
non-text characters.  UTF-16 encoded files are not considered binary."
  (when org-directory-importer-detect-binary-files
    (condition-case nil
        (progn
          ;; First check if it's UTF-16 encoded text
          (when (org-directory-importer--detect-utf16-p file-path)
            (cl-return-from org-directory-importer--looks-binary-p nil))

          ;; Otherwise, perform normal binary detection
          (with-temp-buffer
            (insert-file-contents file-path nil 0 8000)
            (goto-char (point-min))
            ;; If we find null bytes, it's likely binary
            (or (search-forward "\0" nil t)
                ;; Check for high proportion of control characters (excluding tabs, newlines)
                (let ((control-chars 0)
                      (total-chars (buffer-size)))
                  (when (> total-chars 0)
                    (goto-char (point-min))
                    (while (not (eobp))
                      (let ((char (char-after)))
                        (when (and char
                                   (< char 32)
                                   (not (memq char '(?\t ?\n ?\r))))
                          (cl-incf control-chars)))
                      (forward-char 1))
                    ;; If more than 30% are control chars, likely binary
                    (> (/ (* control-chars 100.0) total-chars) 30))))))
      (error nil))))

(defun org-directory-importer--detect-language (file-path)
  "Detect the appropriate Org Babel language for FILE-PATH.
Returns the language string or \\='text as fallback."
  (let* ((basename (file-name-nondirectory file-path))
         (extension (file-name-extension file-path)))
    (or (cdr (assoc basename org-directory-importer-language-mappings))
        (and extension
             (cdr (assoc extension org-directory-importer-language-mappings)))
        "text")))

(defun org-directory-importer--get-file-size (file-path)
  "Return the size of FILE-PATH in bytes, or nil if unavailable."
  (let ((attrs (file-attributes file-path)))
    (when attrs
      (file-attribute-size attrs))))

(defun org-directory-importer--file-too-large-p (file-path)
  "Return non-nil if FILE-PATH exceeds the maximum allowed size."
  (let ((size (org-directory-importer--get-file-size file-path)))
    (and size (> size org-directory-importer-max-file-size))))

(defun org-directory-importer--get-tangle-path (file-path _base-directory)
  "Return tangle path for FILE-PATH based on user configuration.
If `org-directory-importer-tangle-path-type' is `relative', returns
relative path from current Org buffer's directory to FILE-PATH.
If `absolute', returns the absolute path to FILE-PATH.

For relative paths, the path is calculated relative to the Org file's
directory, not BASE-DIRECTORY.  This ensures that tangling will write
files back to their original locations, even when importing from
relative paths like ../../other-dir/."
  (if (eq org-directory-importer-tangle-path-type 'absolute)
      (expand-file-name file-path)
    ;; For relative paths, calculate from the Org file's directory
    (let* ((org-file-dir (if buffer-file-name
                             (file-name-directory buffer-file-name)
                           ;; Fallback if buffer has no file (use current directory)
                           default-directory))
           (relative-path (file-relative-name file-path org-file-dir)))
      ;; Ensure paths start with ./ for same-directory or keep ../ for parent dirs
      (if (or (string-prefix-p "./" relative-path)
              (string-prefix-p "../" relative-path))
          relative-path
        (concat "./" relative-path)))))

(defun org-directory-importer--format-file-size (size)
  "Format SIZE in bytes to human-readable string."
  (cond
   ((> size (* 1024 1024)) (format "%.1fMB" (/ size (* 1024.0 1024.0))))
   ((> size 1024) (format "%.1fKB" (/ size 1024.0)))
   (t (format "%dB" size))))

(defun org-directory-importer--insert-file-properties (path checksum attrs)
  "Insert IMPORT_* property drawer for a file entry.
PATH is the value for IMPORT_PATH (relative path or filename).
CHECKSUM is the SHA-256 hash of file content.
ATTRS is the result of `file-attributes' for the file."
  (insert ":PROPERTIES:\n")
  (insert (format ":IMPORT_PATH: %s\n" path))
  (insert (format ":IMPORT_CHECKSUM: %s\n" checksum))
  (insert (format ":IMPORT_SIZE: %s\n"
                  (number-to-string (file-attribute-size attrs))))
  (insert (format ":IMPORT_MTIME: %s\n"
                  (format-time-string "%Y-%m-%d %H:%M:%S"
                                      (file-attribute-modification-time attrs))))
  (insert ":END:\n"))

(defun org-directory-importer--insert-file-content (file-path header-level base-directory &optional skip-metadata)
  "Insert FILE-PATH as an Org header with Babel source block at HEADER-LEVEL.
BASE-DIRECTORY is used to calculate relative paths for tangling.
When SKIP-METADATA is non-nil, omit IMPORT_* properties from the entry.
Returns t if file was processed successfully, nil otherwise."
  (let ((filename (file-name-nondirectory file-path)))
    (cond
     ;; Check if file is readable
     ((not (file-readable-p file-path))
      (message "Skipping unreadable file (permission denied): %s" filename)
      nil)

     ;; Check if file should be excluded
     ((org-directory-importer--should-exclude-p file-path base-directory)
      (message "Skipping excluded file: %s" filename)
      nil)

     ;; Check if file is too large
     ((org-directory-importer--file-too-large-p file-path)
      (let ((size (org-directory-importer--get-file-size file-path)))
        (message "Skipping large file (%s): %s"
                 (org-directory-importer--format-file-size size)
                 filename))
      nil)

     ;; Check if file appears to be binary
     ((org-directory-importer--looks-binary-p file-path)
      (message "Skipping binary file: %s" filename)
      nil)

     ;; Process the file
     (t
      (condition-case err
          (let* ((language (org-directory-importer--detect-language file-path))
                 (tangle-path (org-directory-importer--get-tangle-path
                               file-path base-directory))
                 (header-stars (make-string header-level ?*))
                 (file-content (with-temp-buffer
                                 (insert-file-contents file-path)
                                 (buffer-string)))
                 (checksum (secure-hash 'sha256 file-content))
                 (attrs (file-attributes file-path))
                 (rel-path (file-relative-name file-path base-directory)))

            ;; Insert the file as an Org entry
            (insert (format "%s %s\n" header-stars filename))

            ;; Add properties for change tracking (unless skip-metadata)
            (unless skip-metadata
              (org-directory-importer--insert-file-properties rel-path checksum attrs))

            ;; Insert source block
            (insert (format "#+begin_src %s :tangle %s :mkdirp yes\n"
                            language tangle-path))
            (insert file-content)
            (unless (string-suffix-p "\n" file-content)
              (insert "\n"))
            (insert "#+end_src\n\n")
            t)
        ;; Handle specific file error types
        (file-error
         (message "File error processing %s: %s" filename (error-message-string err))
         nil)
        ;; Handle coding system errors (e.g., invalid UTF-8)
        (coding-system-error
         (message "Encoding error in file %s, skipping" filename)
         nil)
        ;; Handle any other errors
        (error
         (message "Error processing file %s: %s" filename (error-message-string err))
         nil))))))

(defun org-directory-importer--sort-directory-entries (entries)
  "Sort ENTRIES with directories first, then files, both alphabetically."
  (sort entries
        (lambda (a b)
          (let ((a-is-dir (file-directory-p a))
                (b-is-dir (file-directory-p b)))
            (cond
             ;; Both are directories or both are files: sort alphabetically
             ((eq a-is-dir b-is-dir)
              (string< (file-name-nondirectory a)
                       (file-name-nondirectory b)))
             ;; Directory comes before file
             (a-is-dir t)
             (b-is-dir nil))))))

(defun org-directory-importer--is-symlink-cycle-p (directory visited-dirs)
  "Return non-nil if DIRECTORY create a cycle in VISITED-DIRS.
DIRECTORY is resolved to its canonical path and checked against
the set of already-visited canonical paths."
  (condition-case nil
      (let ((canonical-path (file-truename directory)))
        (member canonical-path visited-dirs))
    (error nil)))

(defun org-directory-importer--process-directory-recursive (directory header-level base-directory &optional visited-dirs skip-metadata)
  "Recursively process DIRECTORY, inserting contents at HEADER-LEVEL.
BASE-DIRECTORY is used for calculating relative paths.
VISITED-DIRS is a list of canonical directory paths already visited,
used to detect symlink cycles.
When SKIP-METADATA is non-nil, omit IMPORT_* properties from file entries.
Returns the total number of files processed."
  (let ((directory-name (file-name-nondirectory directory))
        (total-files-processed 0)
        (directory-content nil)
        (current-visited (or visited-dirs '())))

    ;; Check for symlink cycles
    (when (org-directory-importer--is-symlink-cycle-p directory current-visited)
      (message "Skipping symlink cycle detected: %s" directory)
      (cl-return-from org-directory-importer--process-directory-recursive 0))

    ;; Add current directory to visited set
    (condition-case nil
        (push (file-truename directory) current-visited)
      (error nil))

    ;; Process directory contents into a temporary buffer
    (condition-case err
        (let* ((entries (directory-files directory t "^[^.].*"))
               (sorted-entries (org-directory-importer--sort-directory-entries entries)))

          (with-temp-buffer
            (dolist (entry sorted-entries)
              (condition-case _entry-err
                  (cond
                   ;; Process regular files (including symlinks to files)
                   ((file-regular-p entry)
                    (when (and (file-readable-p entry)
                               (org-directory-importer--insert-file-content
                                entry (1+ header-level) base-directory skip-metadata))
                      (cl-incf total-files-processed)))

                   ;; Process subdirectories recursively
                   ((and (file-directory-p entry)
                         (not (org-directory-importer--should-exclude-p entry base-directory)))
                    (if (file-accessible-directory-p entry)
                        (cl-incf total-files-processed
                                 (org-directory-importer--process-directory-recursive
                                  entry (1+ header-level) base-directory current-visited skip-metadata))
                      (message "Skipping inaccessible directory: %s"
                               (file-name-nondirectory entry)))))
                ;; Handle permission errors on individual entries
                (file-error
                 (message "Permission denied or error accessing: %s"
                          (file-name-nondirectory entry)))))

            ;; Save the directory content
            (setq directory-content (buffer-string))))
      ;; Handle errors reading directory listing
      (file-error
       (message "Permission denied reading directory: %s" directory))
      (error
       (message "Error processing directory %s: %s"
                directory (error-message-string err))))

    ;; Only insert directory header and content if:
    ;; 1. There were files processed, OR
    ;; 2. User wants to include empty directories
    (when (or (> total-files-processed 0)
              org-directory-importer-include-empty-directories)
      ;; Use "./" for the base directory to indicate current directory context
      (let ((heading-name (if (equal (directory-file-name directory)
                                     (directory-file-name base-directory))
                              "."
                            directory-name)))
        (insert (format "%s %s/\n" (make-string header-level ?*) heading-name)))
      (when directory-content
        (insert directory-content)))

    total-files-processed))

;;; Public Interface

;;;###autoload
(defun org-directory-importer-clear-gitignore-cache ()
  "Clear cached gitignore patterns to force re-reading.

USAGE:
  \\[org-directory-importer-clear-gitignore-cache]

Use this command after modifying .gitignore files (local or global)
to ensure the next import uses current patterns.

Gitignore patterns are cached for performance.  The cache persists
across imports within the same Emacs session.  Normally you don't
need to clear it unless you've changed .gitignore files between
imports."
  (interactive)
  (setq org-directory-importer--gitignore-cache nil)
  (message "Gitignore cache cleared"))

(defun org-directory-importer--validate-import-preconditions (directory)
  "Validate that DIRECTORY can be imported.
Signals user-error if validation fails."
  (unless (file-directory-p directory)
    (user-error "Selected path is not a directory: %s" directory))
  (unless (file-readable-p directory)
    (user-error "Directory is not readable: %s" directory))
  (unless (derived-mode-p 'org-mode)
    (user-error "This command only works in Org-mode buffers"))
  ;; For relative tangle paths, require the buffer to be saved
  ;; so we know the correct base directory for calculating relative paths
  (when (and (eq org-directory-importer-tangle-path-type 'relative)
             (not buffer-file-name))
    (user-error "Please save the Org buffer before importing with relative paths.\nThis ensures tangle paths are calculated correctly.\nAlternatively, set `org-directory-importer-tangle-path-type' to 'absolute")))

(defun org-directory-importer--insert-import-metadata (directory)
  "Insert metadata header for imported DIRECTORY."
  (let ((dir-name (file-name-nondirectory directory)))
    (insert (format "* Imported Directory: %s\n" dir-name))
    (insert ":PROPERTIES:\n")
    (insert (format ":IMPORT_SOURCE: %s\n" directory))
    (insert (format ":IMPORT_DATE: %s\n" (format-time-string "%Y-%m-%d %H:%M:%S")))
    (insert ":END:\n\n")))

;;;###autoload
(defun org-directory-importer-import (directory &optional skip-metadata)
  "Import DIRECTORY structure into current Org buffer.

USAGE:
  \\[org-directory-importer-import] /path/to/directory RET

With \\[universal-argument] prefix: Import without metadata for plain content.
Without prefix: Import with full change-tracking metadata.

When importing with metadata (default):
- Creates a top-level heading with import metadata (source path, timestamp)
- Each file entry includes IMPORT_* properties for change tracking
- Supports incremental updates via `org-directory-importer-import-update'

When importing without metadata (C-u prefix or SKIP-METADATA non-nil):
- No metadata wrapper heading is created
- No IMPORT_* properties on files
- Content cannot be updated with `org-directory-importer-import-update'

Each directory becomes a heading and each file becomes a Babel source
block with :tangle property that can be tangled back to recreate files."
  (interactive (list (read-directory-name "Select directory to import: ")
                     current-prefix-arg))

  (let* ((expanded-directory (expand-file-name directory))
         (start-point (point))
         (files-processed 0)
         ;; Header level: 2 when metadata wrapper exists, 1 when plain
         (header-level (if skip-metadata 1 2))
         ;; Store current Org file to prevent self-import
         (org-directory-importer--current-org-file
          (when buffer-file-name
            (condition-case nil
                (file-truename buffer-file-name)
              (error nil)))))

    ;; Validate preconditions
    (org-directory-importer--validate-import-preconditions expanded-directory)

    (message "Importing directory structure from: %s%s"
             expanded-directory
             (if skip-metadata " (plain, no metadata)" ""))

    ;; Insert metadata header (unless skip-metadata)
    (unless skip-metadata
      (org-directory-importer--insert-import-metadata expanded-directory))

    ;; Process the directory
    (setq files-processed
          (org-directory-importer--process-directory-recursive
           expanded-directory header-level expanded-directory nil skip-metadata))

    (message "Successfully imported %d file%s from: %s"
             files-processed
             (if (= files-processed 1) "" "s")
             expanded-directory)

    ;; Position cursor at the beginning of imported content
    (goto-char start-point)))

;;;###autoload
(defun org-directory-importer-import-plain (directory)
  "Import DIRECTORY structure without metadata or change tracking.

DEPRECATED: Use `C-u \\[org-directory-importer-import]' instead.

This function is now a wrapper around `org-directory-importer-import'
with the SKIP-METADATA argument set to t.

Imports the directory structure directly at point without creating a
metadata wrapper heading or file-level IMPORT_* properties.  Use this
for one-time imports when you don't need change tracking.

The imported structure can be tangled back to recreate files, but cannot
be updated with `org-directory-importer-import-update'."
  (interactive "DSelect directory to import: ")
  (org-directory-importer-import directory t))

;;;###autoload
(defun org-directory-importer-import-file (file &optional skip-metadata)
  "Import FILE unconditionally into current Org buffer at point.

USAGE:
  \\[org-directory-importer-import-file] /path/to/file RET

With \\[universal-argument] prefix: Import without metadata for plain content.
Without prefix: Import with full change-tracking metadata.

When importing with metadata (default):
- Adds IMPORT_* properties (path, checksum, size, mtime) for change tracking

When importing without metadata (C-u prefix or SKIP-METADATA non-nil):
- No IMPORT_* properties on the file entry

This is the inverse of `org-babel-tangle-file' - it takes a source
file and creates an Org heading with a tangleable source block.

Unlike directory import commands, this function:
- Imports ANY file regardless of patterns or gitignore
- Does not check for binary content
- Does not enforce size limits"
  (interactive (list (read-file-name "Select file to import: ")
                     current-prefix-arg))

  ;; Validate preconditions
  (unless (derived-mode-p 'org-mode)
    (user-error "This command only works in Org-mode buffers"))

  (unless (file-exists-p file)
    (user-error "File does not exist: %s" file))

  (unless (file-readable-p file)
    (user-error "File is not readable: %s" file))

  ;; For relative tangle paths, require the buffer to be saved
  (when (and (eq org-directory-importer-tangle-path-type 'relative)
             (not buffer-file-name))
    (user-error "Please save the Org buffer before importing with relative paths.\nThis ensures tangle paths are calculated correctly.\nAlternatively, set `org-directory-importer-tangle-path-type' to 'absolute"))

  (let* ((expanded-file (expand-file-name file))
         (filename (file-name-nondirectory expanded-file))
         (file-dir (file-name-directory expanded-file))
         (language (org-directory-importer--detect-language expanded-file))
         (tangle-path (org-directory-importer--get-tangle-path
                       expanded-file file-dir))
         ;; Determine header level from context
         ;; If inside/under a heading, insert as subheading (level + 1)
         ;; Otherwise insert at top level
         (header-level (save-excursion
                         (if (ignore-errors (org-back-to-heading t))
                             (1+ (org-current-level))
                           1)))
         (header-stars (make-string header-level ?*))
         (file-content (with-temp-buffer
                         (insert-file-contents expanded-file)
                         (buffer-string)))
         (checksum (secure-hash 'sha256 file-content))
         (attrs (file-attributes expanded-file)))

    ;; Ensure we start on a new line
    (unless (bolp)
      (insert "\n"))

    ;; Insert the file as an Org entry with metadata
    (insert (format "%s %s\n" header-stars filename))

    ;; Add properties for change tracking (unless skip-metadata)
    (unless skip-metadata
      (org-directory-importer--insert-file-properties filename checksum attrs))

    ;; Insert source block
    (insert (format "#+begin_src %s :tangle %s :mkdirp yes\n"
                    language tangle-path))
    (insert file-content)
    (unless (string-suffix-p "\n" file-content)
      (insert "\n"))
    (insert "#+end_src\n\n")

    (message "Imported file: %s%s"
             filename
             (if skip-metadata " (plain, no metadata)" ""))))

;;;###autoload
(defun org-directory-importer-prune-metadata ()
  "Remove all IMPORT_* metadata properties from current Org buffer.

USAGE:
  \\[org-directory-importer-prune-metadata]

Removes package-specific properties from all headings in the buffer:
- IMPORT_SOURCE (directory-level)
- IMPORT_DATE (directory-level)
- IMPORT_PATH (file-level)
- IMPORT_CHECKSUM (file-level)
- IMPORT_SIZE (file-level)
- IMPORT_MTIME (file-level)

Other properties are preserved.  Use this command when you no longer
need change tracking or want to convert a tracked import to plain content.

After pruning, `org-directory-importer-import-update' will no longer work
on the affected entries."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "This command only works in Org-mode buffers"))
  (let ((count-entries 0)
        (count-props 0))
    (save-excursion
      (org-map-entries
       (lambda ()
         (let ((import-props (seq-filter
                              (lambda (prop)
                                (string-prefix-p "IMPORT_" (car prop)))
                              (org-entry-properties))))
           (when import-props
             (dolist (prop-pair import-props)
               (org-delete-property (car prop-pair))
               (cl-incf count-props))
             (cl-incf count-entries))))))
    (if (> count-props 0)
        (message "Pruned %d propert%s from %d entr%s"
                 count-props (if (= count-props 1) "y" "ies")
                 count-entries (if (= count-entries 1) "y" "ies"))
      (message "No IMPORT_* properties found in buffer"))))

;;;###autoload
(defun org-directory-importer-refresh-block ()
  "Refresh source block at point from its tangle target file.

USAGE:
  \\[org-directory-importer-refresh-block]

Reads the file specified in the :tangle header of the current source
block and updates the block content.  If the containing heading has
IMPORT_* metadata properties, they are also updated.

This is useful when external changes have been made to the source file
and you want to synchronize the Org document with those changes.

Point must be inside a source block with a :tangle path."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "This command only works in Org-mode buffers"))

  ;; Get source block info
  (let ((block-info (org-babel-get-src-block-info 'light)))
    (unless block-info
      (user-error "Point is not inside a source block"))

    (let* ((params (nth 2 block-info))
           (tangle-path (cdr (assq :tangle params))))

      ;; Validate tangle path
      (when (or (null tangle-path)
                (string= tangle-path "no")
                (string-empty-p tangle-path))
        (user-error "No tangle path specified for this source block"))

      ;; Resolve relative paths against Org file directory
      (let* ((org-file-dir (if buffer-file-name
                               (file-name-directory buffer-file-name)
                             default-directory))
             (resolved-path (expand-file-name tangle-path org-file-dir)))

        ;; Validate file exists and is readable
        (unless (file-exists-p resolved-path)
          (user-error "Tangle target file not found: %s" resolved-path))
        (unless (file-readable-p resolved-path)
          (user-error "Tangle target file is not readable: %s" resolved-path))

        ;; Read new content
        (let* ((new-content (with-temp-buffer
                              (insert-file-contents resolved-path)
                              (buffer-string)))
               (new-checksum (secure-hash 'sha256 new-content))
               (attrs (file-attributes resolved-path))
               (has-metadata nil))

          ;; Check if heading has IMPORT_* metadata
          (save-excursion
            (when (ignore-errors (org-back-to-heading t))
              (setq has-metadata (org-entry-get nil "IMPORT_CHECKSUM"))))

          ;; Update metadata if present
          (when has-metadata
            (save-excursion
              (org-back-to-heading t)
              (org-set-property "IMPORT_CHECKSUM" new-checksum)
              (org-set-property "IMPORT_SIZE"
                                (number-to-string (file-attribute-size attrs)))
              (org-set-property "IMPORT_MTIME"
                                (format-time-string "%Y-%m-%d %H:%M:%S"
                                                    (file-attribute-modification-time attrs)))))

          ;; Find and replace source block content
          ;; We need to find the current block's boundaries
          (let ((content-start nil)
                (content-end nil))

            ;; Find #+begin_src line
            (save-excursion
              (when (re-search-backward "^[ \t]*#\\+begin_src" nil t)
                (forward-line 1)
                (setq content-start (point))))

            ;; Find #+end_src line
            (save-excursion
              (when (re-search-forward "^[ \t]*#\\+end_src" nil t)
                (beginning-of-line)
                (setq content-end (point))))

            (when (and content-start content-end (< content-start content-end))
              ;; Replace content
              (delete-region content-start content-end)
              (goto-char content-start)
              (insert new-content)
              (unless (string-suffix-p "\n" new-content)
                (insert "\n"))))

          (message "Refreshed block from: %s" resolved-path))))))

;;;###autoload
(defun org-directory-importer-import-update ()
  "Update existing import by detecting change.

USAGE:
  \\[org-directory-importer-import-update]

Detects and updates modified files, adds new files, and reports deleted files
from a previously imported directory structure.  Must be run from within an
imported directory heading (one with an IMPORT_SOURCE property).

Reports statistics: modified, new, deleted, and unchanged files."
  (interactive)
  (let* ((import-root (org-entry-get nil "IMPORT_SOURCE" t))
         (stats (list :modified 0 :new 0 :deleted 0 :unchanged 0))
         ;; Store current Org file to prevent self-import
         (org-directory-importer--current-org-file
          (when buffer-file-name
            (condition-case nil
                (file-truename buffer-file-name)
              (error nil)))))

    (unless import-root
      (user-error "Not in an imported directory structure.\nMove point to a heading with IMPORT_SOURCE property"))

    (unless (file-directory-p import-root)
      (user-error "Import source directory no longer exists: %s" import-root))

    (message "Updating import from: %s" import-root)

    (save-excursion
      ;; Navigate to the heading that owns IMPORT_SOURCE (not a child
      ;; that merely inherits it).  Without this, running the command
      ;; from a child heading would scan only a partial subtree.
      (org-back-to-heading t)
      (while (not (org-entry-get nil "IMPORT_SOURCE"))
        (org-up-heading-safe))
      ;; Collect existing files: path → (checksum marker)
      (let ((existing (make-hash-table :test 'equal))
            (found-in-fs (make-hash-table :test 'equal)))

        ;; Build map of existing imported files
        (org-map-entries
         (lambda ()
           (when-let ((path (org-entry-get nil "IMPORT_PATH"))
                      (checksum (org-entry-get nil "IMPORT_CHECKSUM")))
             (puthash path (list checksum (point-marker)) existing)))
         nil 'tree)

        ;; Walk filesystem, compare with existing
        (org-directory-importer--walk-for-update
         import-root import-root existing found-in-fs stats)

        ;; Find deleted files (in existing but not found in filesystem)
        (maphash
         (lambda (path _record)
           (unless (gethash path found-in-fs)
             (cl-incf (plist-get stats :deleted))))
         existing)))

    (message "Update complete: %d modified, %d new, %d deleted, %d unchanged"
             (plist-get stats :modified)
             (plist-get stats :new)
             (plist-get stats :deleted)
             (plist-get stats :unchanged))))

(defun org-directory-importer--walk-for-update (dir base-dir existing found-in-fs stats)
  "Walk DIR comparing with EXISTING, update STATS.
BASE-DIR is the import root directory.
EXISTING is a hash table of path → (checksum marker).
FOUND-IN-FS is a hash table tracking which files we found in filesystem.
STATS is a plist with :modified :new :deleted :unchanged counters."
  (condition-case err
      (let* ((entries (directory-files dir t "^[^.].*"))
             (sorted-entries (org-directory-importer--sort-directory-entries entries)))

        (dolist (entry sorted-entries)
          (condition-case _entry-err
              (let ((rel-path (file-relative-name entry base-dir)))
                (cond
                 ;; Process subdirectories recursively
                 ((and (file-directory-p entry)
                       (not (org-directory-importer--should-exclude-p entry base-dir)))
                  (when (file-accessible-directory-p entry)
                    (org-directory-importer--walk-for-update
                     entry base-dir existing found-in-fs stats)))

                 ;; Process regular files
                 ((and (file-regular-p entry)
                       (file-readable-p entry)
                       (not (org-directory-importer--should-exclude-p entry base-dir))
                       (not (org-directory-importer--file-too-large-p entry))
                       (not (org-directory-importer--looks-binary-p entry)))

                  ;; Mark this file as found in filesystem
                  (puthash rel-path t found-in-fs)

                  ;; Check if file exists in import
                  (if-let ((record (gethash rel-path existing)))
                      ;; File exists - check if modified
                      (let* ((old-checksum (car record))
                             (marker (cadr record))
                             (new-content (with-temp-buffer
                                            (insert-file-contents entry)
                                            (buffer-string)))
                             (new-checksum (secure-hash 'sha256 new-content)))

                        (if (equal old-checksum new-checksum)
                            ;; Unchanged
                            (cl-incf (plist-get stats :unchanged))
                          ;; Modified: update block
                          (org-directory-importer--update-block marker entry base-dir new-content new-checksum)
                          (cl-incf (plist-get stats :modified))))

                    ;; New file: insert it
                    (org-directory-importer--insert-new-file entry base-dir)
                    (cl-incf (plist-get stats :new))))))

            ;; Handle errors on individual entries
            (file-error
             (message "Error accessing: %s" (file-name-nondirectory entry))))))

    ;; Handle errors reading directory
    (file-error
     (message "Permission denied reading directory: %s" dir))
    (error
     (message "Error processing directory %s: %s" dir (error-message-string err)))))

(defun org-directory-importer--update-block (marker file-path _base-dir new-content new-checksum)
  "Update source block at MARKER with content from FILE-PATH.
BASE-DIR is the import root directory.
NEW-CONTENT is the file content string.
NEW-CHECKSUM is the SHA256 hash of the new content."
  (save-excursion
    (goto-char marker)
    (let ((attrs (file-attributes file-path)))

      ;; Update properties
      (org-set-property "IMPORT_CHECKSUM" new-checksum)
      (org-set-property "IMPORT_SIZE" (number-to-string (file-attribute-size attrs)))
      (org-set-property "IMPORT_MTIME"
                        (format-time-string "%Y-%m-%d %H:%M:%S"
                                            (file-attribute-modification-time attrs)))

      ;; Find and replace source block content
      (when (re-search-forward "^[ \t]*#\\+begin_src" (org-entry-end-position) t)
        (forward-line 1)
        (let ((start (point)))
          (when (re-search-forward "^[ \t]*#\\+end_src" (org-entry-end-position) t)
            (beginning-of-line)
            (let ((end (point)))
              ;; Replace content
              (delete-region start end)
              (goto-char start)
              (insert new-content)
              (unless (string-suffix-p "\n" new-content)
                (insert "\n")))))))))

(defun org-directory-importer--insert-new-file (file-path base-dir)
  "Insert a new file at appropriate location in the tree.
FILE-PATH is the absolute path to the new file.
BASE-DIR is the import root directory.

This function finds the appropriate parent directory heading and inserts
the new file under it."
  (let* ((rel-path (file-relative-name file-path base-dir))
         (path-parts (split-string rel-path "/"))
         (dir-parts (butlast path-parts)))

    (save-excursion
      ;; Navigate to import root heading (has IMPORT_SOURCE property)
      (org-back-to-heading t)

      ;; Navigate to the "./" base directory heading (first child)
      (unless (org-directory-importer--find-subheading ".")
        (error "Could not find base directory (./) heading in import structure"))

      ;; Navigate down to find appropriate directory heading
      (let ((found t))
        (cl-block nil
          (dolist (dir-name dir-parts)
            (unless (org-directory-importer--find-subheading dir-name)
              (setq found nil)
              (cl-return))))

        (if found
            ;; Found the directory - insert file here
            (let ((dir-level (org-current-level)))
              (org-end-of-subtree t t)
              (org-directory-importer--insert-file-content
               file-path (1+ dir-level) base-dir))

          ;; Directory heading not found - insert at end of base directory
          (message "Warning: Could not find directory heading for new file: %s" rel-path)
          (org-back-to-heading t)
          (org-end-of-subtree t t)
          (org-directory-importer--insert-file-content
           file-path (1+ (org-current-level)) base-dir))))))

(defun org-directory-importer--find-subheading (heading-name)
  "Find and move to child heading with HEADING-NAME.
Returns non-nil if found, nil otherwise.
Leaves point at the found heading or at the original position if not found.
Only searches direct children of current heading, not deeper descendants."
  (let ((start-pos (point))
        (found nil)
        (search-name (if (string-suffix-p "/" heading-name)
                         heading-name
                       (concat heading-name "/")))
        (parent-level (org-current-level)))

    ;; Try to move to first child
    (when (and (outline-next-heading)
               (> (org-current-level) parent-level))
      ;; We're now at a child heading
      (let ((child-level (org-current-level)))
        ;; Search through siblings at this level
        (while (and (not found)
                    (= (org-current-level) child-level))
          (when (and (looking-at org-complex-heading-regexp)
                     (string= (match-string 4) search-name))
            (setq found t))
          (unless found
            ;; Move to next sibling (stay at same level)
            (unless (and (outline-next-heading)
                         (>= (org-current-level) child-level))
              ;; No more siblings or moved to parent level
              (setq found nil)
              (cl-return))))))

    (unless found
      (goto-char start-pos))
    found))

(provide 'org-directory-importer)

;;; org-directory-importer.el ends here
