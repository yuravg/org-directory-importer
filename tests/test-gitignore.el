;;; test-gitignore.el --- ERT tests for gitignore matching -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; This file is part of org-directory-importer.

;;; Commentary:

;; ERT test suite for gitignore pattern matching functionality.
;; Converted from manual test runner to proper ERT format.
;;
;; Tests cover:
;; - Simple basename patterns (*.log)
;; - Rooted patterns (/build)
;; - Path patterns (src/build)
;; - Globstar patterns (**/*.log)
;; - Directory patterns (dir/)
;; - Wildcard patterns in paths (src/*/test.txt)

;;; Code:

(require 'ert)
(require 'org-directory-importer)

(defvar test-gitignore-base-dir "/tmp/test-project"
  "Base directory for gitignore tests.")

;;; Test 1: Simple basename patterns

(ert-deftest test-gitignore-basename-simple ()
  "Test simple basename pattern *.log matches files in root."
  (should (org-directory-importer--gitignore-match-p
           "*.log" test-gitignore-base-dir "/tmp/test-project/debug.log")))

(ert-deftest test-gitignore-basename-nested ()
  "Test basename pattern *.log matches files in subdirectories."
  (should (org-directory-importer--gitignore-match-p
           "*.log" test-gitignore-base-dir "/tmp/test-project/src/debug.log")))

(ert-deftest test-gitignore-basename-no-match ()
  "Test basename pattern *.log does not match different extension."
  (should-not (org-directory-importer--gitignore-match-p
               "*.log" test-gitignore-base-dir "/tmp/test-project/test.txt")))

;;; Test 2: Rooted patterns

(ert-deftest test-gitignore-rooted-match ()
  "Test rooted pattern /build matches only at repository root."
  (should (org-directory-importer--gitignore-match-p
           "/build" test-gitignore-base-dir "/tmp/test-project/build")))

(ert-deftest test-gitignore-rooted-no-nested ()
  "Test rooted pattern /build does not match in subdirectories."
  (should-not (org-directory-importer--gitignore-match-p
               "/build" test-gitignore-base-dir "/tmp/test-project/src/build")))

;;; Test 3: Path patterns

(ert-deftest test-gitignore-path-direct ()
  "Test path pattern src/build matches exact path."
  (should (org-directory-importer--gitignore-match-p
           "src/build" test-gitignore-base-dir "/tmp/test-project/src/build")))

(ert-deftest test-gitignore-path-suffix ()
  "Test path pattern src/build matches as suffix in deeper paths."
  (should (org-directory-importer--gitignore-match-p
           "src/build" test-gitignore-base-dir "/tmp/test-project/other/src/build")))

;;; Test 4: Globstar patterns (**)

(ert-deftest test-gitignore-globstar-root ()
  "Test globstar pattern **/*.log matches files in root."
  (should (org-directory-importer--gitignore-match-p
           "**/*.log" test-gitignore-base-dir "/tmp/test-project/debug.log")))

(ert-deftest test-gitignore-globstar-subdir ()
  "Test globstar pattern **/*.log matches files in subdirectories."
  (should (org-directory-importer--gitignore-match-p
           "**/*.log" test-gitignore-base-dir "/tmp/test-project/src/debug.log")))

(ert-deftest test-gitignore-globstar-deep ()
  "Test globstar pattern **/*.log matches files in deep paths."
  (should (org-directory-importer--gitignore-match-p
           "**/*.log" test-gitignore-base-dir "/tmp/test-project/src/deep/debug.log")))

(ert-deftest test-gitignore-globstar-suffix-simple ()
  "Test globstar pattern build/** matches files under build/."
  (should (org-directory-importer--gitignore-match-p
           "build/**" test-gitignore-base-dir "/tmp/test-project/build/output.txt")))

(ert-deftest test-gitignore-globstar-suffix-deep ()
  "Test globstar pattern build/** matches files in deep subdirectories."
  (should (org-directory-importer--gitignore-match-p
           "build/**" test-gitignore-base-dir "/tmp/test-project/build/deep/output.txt")))

;;; Test 5: Directory patterns

(ert-deftest test-gitignore-directory-pattern ()
  "Test directory pattern temp-test-dir/ matches directories."
  (let ((temp-dir "/tmp/test-project/temp-test-dir"))
    (unwind-protect
        (progn
          (make-directory temp-dir t)
          (should (org-directory-importer--gitignore-match-p
                   "temp-test-dir/" test-gitignore-base-dir temp-dir)))
      (when (file-directory-p temp-dir)
        (delete-directory temp-dir)))))

;;; Test 6: Wildcard patterns in paths

(ert-deftest test-gitignore-wildcard-path-foo ()
  "Test wildcard pattern src/*/test.txt matches src/foo/test.txt."
  (should (org-directory-importer--gitignore-match-p
           "src/*/test.txt" test-gitignore-base-dir "/tmp/test-project/src/foo/test.txt")))

(ert-deftest test-gitignore-wildcard-path-bar ()
  "Test wildcard pattern src/*/test.txt matches src/bar/test.txt."
  (should (org-directory-importer--gitignore-match-p
           "src/*/test.txt" test-gitignore-base-dir "/tmp/test-project/src/bar/test.txt")))

(provide 'test-gitignore)
;;; test-gitignore.el ends here
