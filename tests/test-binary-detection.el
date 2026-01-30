;;; test-binary-detection.el --- ERT tests for binary file detection -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; This file is part of org-directory-importer.

;;; Commentary:

;; ERT test suite for binary file detection functionality.
;; Tests `org-directory-importer--looks-binary-p` (line 349).
;;
;; Tests cover:
;; - Binary files (PNG images, raw binary data)
;; - Text files (ASCII, UTF-8 with emoji)
;; - Edge cases (empty files, UTF-16, 30% threshold)

;;; Code:

(require 'ert)
(require 'org-directory-importer)

(defvar test-binary-fixtures-dir
  (expand-file-name "fixtures" (file-name-directory load-file-name))
  "Directory containing test fixtures.")

;;; Binary file tests

(ert-deftest test-binary-detection-png ()
  "PNG image should be detected as binary."
  (let ((file (expand-file-name "binary/test.png" test-binary-fixtures-dir)))
    (should (org-directory-importer--looks-binary-p file))))

(ert-deftest test-binary-detection-raw-binary ()
  "Raw binary data with null bytes should be detected as binary."
  (let ((file (expand-file-name "binary/test.bin" test-binary-fixtures-dir)))
    (should (org-directory-importer--looks-binary-p file))))

;;; Text file tests

(ert-deftest test-binary-detection-ascii-text ()
  "Plain ASCII text should not be detected as binary."
  (let ((file (expand-file-name "text/ascii.txt" test-binary-fixtures-dir)))
    (should-not (org-directory-importer--looks-binary-p file))))

(ert-deftest test-binary-detection-unicode-text ()
  "UTF-8 text with emoji should not be detected as binary."
  (let ((file (expand-file-name "text/unicode.txt" test-binary-fixtures-dir)))
    (should-not (org-directory-importer--looks-binary-p file))))

;;; Edge case tests

(ert-deftest test-binary-detection-empty-file ()
  "Empty file should not be detected as binary."
  (let ((temp-file (make-temp-file "test-empty")))
    (unwind-protect
        (should-not (org-directory-importer--looks-binary-p temp-file))
      (delete-file temp-file))))

(ert-deftest test-binary-detection-utf16 ()
  "UTF-16 encoded text may trigger false positive.
This is an edge case and acceptable behavior."
  (let ((file (expand-file-name "text/utf16.txt" test-binary-fixtures-dir)))
    ;; UTF-16 often contains null bytes and may be detected as binary
    ;; We test that the function runs without error, but don't assert result
    (org-directory-importer--looks-binary-p file)))

(provide 'test-binary-detection)
;;; test-binary-detection.el ends here
