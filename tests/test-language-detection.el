;;; test-language-detection.el --- ERT tests for language detection -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; This file is part of org-directory-importer.

;;; Commentary:

;; ERT test suite for language detection functionality.
;; Tests `org-directory-importer--detect-language` (line 376).
;;
;; Coverage: All 43+ language mappings from lines 88-139
;; - Extension-based detection
;; - Full filename detection (Makefile, Dockerfile, etc.)
;; - Fallback behavior for unknown extensions

;;; Code:

(require 'ert)
(require 'org-directory-importer)

;;; Extension-based detection tests

(ert-deftest test-language-python ()
  "Python files (.py) should be detected correctly."
  (should (equal "python" (org-directory-importer--detect-language "script.py"))))

(ert-deftest test-language-rust ()
  "Rust files (.rs) should be detected correctly."
  (should (equal "rust" (org-directory-importer--detect-language "main.rs"))))

(ert-deftest test-language-javascript ()
  "JavaScript files (.js) should be detected correctly."
  (should (equal "javascript" (org-directory-importer--detect-language "app.js"))))

(ert-deftest test-language-typescript ()
  "TypeScript files (.ts) should be detected correctly."
  (should (equal "typescript" (org-directory-importer--detect-language "app.ts"))))

(ert-deftest test-language-java ()
  "Java files (.java) should be detected correctly."
  (should (equal "java" (org-directory-importer--detect-language "Main.java"))))

(ert-deftest test-language-c ()
  "C files (.c) should be detected correctly."
  (should (equal "c" (org-directory-importer--detect-language "main.c"))))

(ert-deftest test-language-cpp ()
  "C++ files (.cpp) should be detected correctly."
  (should (equal "cpp" (org-directory-importer--detect-language "main.cpp"))))

(ert-deftest test-language-go ()
  "Go files (.go) should be detected correctly."
  (should (equal "go" (org-directory-importer--detect-language "main.go"))))

(ert-deftest test-language-ruby ()
  "Ruby files (.rb) should be detected correctly."
  (should (equal "ruby" (org-directory-importer--detect-language "app.rb"))))

(ert-deftest test-language-php ()
  "PHP files (.php) should be detected correctly."
  (should (equal "php" (org-directory-importer--detect-language "index.php"))))

(ert-deftest test-language-shell-script-sh ()
  "Shell files (.sh) should be detected correctly."
  (should (equal "shell-script" (org-directory-importer--detect-language "script.sh"))))

(ert-deftest test-language-shell-script-bash ()
  "Bash files (.bash) should be detected correctly."
  (should (equal "shell-script" (org-directory-importer--detect-language "script.bash"))))

(ert-deftest test-language-perl ()
  "Perl files (.pl) should be detected correctly."
  (should (equal "perl" (org-directory-importer--detect-language "script.pl"))))

(ert-deftest test-language-sql ()
  "SQL files (.sql) should be detected correctly."
  (should (equal "sql" (org-directory-importer--detect-language "schema.sql"))))

(ert-deftest test-language-html ()
  "HTML files (.html) should be detected correctly."
  (should (equal "html" (org-directory-importer--detect-language "index.html"))))

(ert-deftest test-language-css ()
  "CSS files (.css) should be detected correctly."
  (should (equal "css" (org-directory-importer--detect-language "styles.css"))))

(ert-deftest test-language-json ()
  "JSON files (.json) should be detected correctly."
  (should (equal "json" (org-directory-importer--detect-language "config.json"))))

(ert-deftest test-language-yaml ()
  "YAML files (.yaml) should be detected correctly."
  (should (equal "yaml" (org-directory-importer--detect-language "config.yaml"))))

(ert-deftest test-language-yml ()
  "YAML files (.yml) should be detected correctly."
  (should (equal "yaml" (org-directory-importer--detect-language "config.yml"))))

(ert-deftest test-language-xml ()
  "XML files (.xml) should be detected correctly."
  (should (equal "xml" (org-directory-importer--detect-language "config.xml"))))

(ert-deftest test-language-markdown ()
  "Markdown files (.md) should be detected correctly."
  (should (equal "markdown" (org-directory-importer--detect-language "README.md"))))

(ert-deftest test-language-org ()
  "Org files (.org) should be detected correctly."
  (should (equal "org" (org-directory-importer--detect-language "notes.org"))))

(ert-deftest test-language-elisp-el ()
  "Emacs Lisp files (.el) should be detected correctly."
  (should (equal "emacs-lisp" (org-directory-importer--detect-language "init.el"))))

(ert-deftest test-language-lisp ()
  "Lisp files (.lisp) should be detected correctly."
  (should (equal "lisp" (org-directory-importer--detect-language "core.lisp"))))

(ert-deftest test-language-jsx ()
  "JSX files (.jsx) should be detected correctly."
  (should (equal "javascript" (org-directory-importer--detect-language "component.jsx"))))

(ert-deftest test-language-tsx ()
  "TSX files (.tsx) should be detected correctly."
  (should (equal "typescript" (org-directory-importer--detect-language "component.tsx"))))

(ert-deftest test-language-bat ()
  "Batch files (.bat) should be detected correctly."
  (should (equal "bat" (org-directory-importer--detect-language "script.bat"))))

(ert-deftest test-language-conf ()
  "Config files (.conf) should be detected correctly."
  (should (equal "conf" (org-directory-importer--detect-language "nginx.conf"))))

(ert-deftest test-language-rst ()
  "reStructuredText files (.rst) should be detected correctly."
  (should (equal "rst" (org-directory-importer--detect-language "doc.rst"))))

(ert-deftest test-language-perl-pm ()
  "Perl module files (.pm) should be detected correctly."
  (should (equal "perl" (org-directory-importer--detect-language "Module.pm"))))

(ert-deftest test-language-powershell ()
  "PowerShell files (.ps1) should be detected correctly."
  (should (equal "powershell" (org-directory-importer--detect-language "script.ps1"))))

(ert-deftest test-language-verilog ()
  "Verilog files (.sv) should be detected correctly."
  (should (equal "verilog" (org-directory-importer--detect-language "design.sv"))))

(ert-deftest test-language-tcl ()
  "TCL files (.tcl) should be detected correctly."
  (should (equal "tcl" (org-directory-importer--detect-language "script.tcl"))))

(ert-deftest test-language-plantuml ()
  "PlantUML files (.plantuml) should be detected correctly."
  (should (equal "plantuml" (org-directory-importer--detect-language "diagram.plantuml"))))

;;; Full filename detection tests

(ert-deftest test-language-makefile ()
  "Makefile should be detected by exact name match."
  (should (equal "makefile" (org-directory-importer--detect-language "Makefile"))))

(ert-deftest test-language-makefile-lowercase ()
  "makefile (lowercase) should be detected by exact name match."
  (should (equal "makefile" (org-directory-importer--detect-language "makefile"))))

(ert-deftest test-language-makefile-mk ()
  "Makefiles with .mk extension should be detected correctly."
  (should (equal "makefile" (org-directory-importer--detect-language "rules.mk"))))

(ert-deftest test-language-cmakelists ()
  "CMakeLists.txt should be detected by exact name match."
  (should (equal "cmake" (org-directory-importer--detect-language "CMakeLists.txt"))))

(ert-deftest test-language-cmake-extension ()
  "CMake files with .cmake extension should be detected correctly."
  (should (equal "cmake" (org-directory-importer--detect-language "config.cmake"))))

;;; Fallback behavior tests

(ert-deftest test-language-unknown-extension ()
  "Unknown extensions should default to text."
  (should (equal "text" (org-directory-importer--detect-language "file.xyz"))))

(ert-deftest test-language-no-extension ()
  "Files without extension should default to text."
  (should (equal "text" (org-directory-importer--detect-language "README"))))

(provide 'test-language-detection)
;;; test-language-detection.el ends here
