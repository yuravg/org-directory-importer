;;; test-suite.el --- Test suite runner for org-directory-importer -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; This file is part of org-directory-importer.

;;; Commentary:

;; Main entry point for batch test execution.
;; Usage: emacs -batch -l ert -l tests/test-suite.el

;;; Code:

(require 'ert)

;; Add parent directory to load-path
(add-to-list 'load-path (file-name-directory (directory-file-name (file-name-directory load-file-name))))

;; Load the main package
(require 'org-directory-importer)

;; Load all test files
(load (expand-file-name "test-gitignore.el" (file-name-directory load-file-name)))
(load (expand-file-name "test-binary-detection.el" (file-name-directory load-file-name)))
(load (expand-file-name "test-language-detection.el" (file-name-directory load-file-name)))
(load (expand-file-name "test-roundtrip.el" (file-name-directory load-file-name)))
(load (expand-file-name "test-edge-cases.el" (file-name-directory load-file-name)))
(load (expand-file-name "test-update.el" (file-name-directory load-file-name)))

;; Run all tests when called from batch mode
(when noninteractive
  (ert-run-tests-batch-and-exit))

(provide 'test-suite)
;;; test-suite.el ends here
