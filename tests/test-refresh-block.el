;;; test-refresh-block.el --- ERT tests for refresh-block command -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; This file is part of org-directory-importer.

;;; Commentary:

;; ERT test suite for `org-directory-importer-refresh-block'.
;;
;; Tests the command that refreshes a source block's content by re-reading
;; from its tangle target file.

;;; Code:

(require 'ert)
(require 'org-directory-importer)

;;; Basic functionality tests

(ert-deftest test-refresh-block-basic ()
  "Refresh block without metadata, verify content updated."
  (let* ((temp-dir (make-temp-file "test-refresh-dir" t))
         (source-file (expand-file-name "source.py" temp-dir))
         (temp-org (expand-file-name "test.org" temp-dir)))
    (unwind-protect
        (progn
          ;; Create source file
          (with-temp-file source-file
            (insert "print('original')\n"))
          ;; Create org file with source block (no metadata)
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Test Heading\n")
            (insert "#+begin_src python :tangle ./source.py :mkdirp yes\n")
            (insert "print('original')\n")
            (insert "#+end_src\n")
            (write-file temp-org))
          ;; Modify source file externally
          (with-temp-file source-file
            (insert "print('modified')\n"))
          ;; Refresh the block
          (with-current-buffer (find-file-noselect temp-org)
            (goto-char (point-min))
            (search-forward "print")
            (org-directory-importer-refresh-block)
            ;; Verify content was updated
            (goto-char (point-min))
            (should (search-forward "print('modified')" nil t))
            (kill-buffer)))
      ;; Cleanup
      (when (file-directory-p temp-dir)
        (delete-directory temp-dir t)))))

(ert-deftest test-refresh-block-with-metadata ()
  "Refresh with metadata, verify all IMPORT_* updated."
  (let* ((temp-dir (make-temp-file "test-refresh-dir" t))
         (source-file (expand-file-name "source.py" temp-dir))
         (temp-org (expand-file-name "test.org" temp-dir)))
    (unwind-protect
        (progn
          ;; Create source file
          (with-temp-file source-file
            (insert "print('original')\n"))
          ;; Create org file with source block and metadata
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* source.py\n")
            (insert ":PROPERTIES:\n")
            (insert ":IMPORT_PATH: source.py\n")
            (insert ":IMPORT_CHECKSUM: old-checksum-value\n")
            (insert ":IMPORT_SIZE: 100\n")
            (insert ":IMPORT_MTIME: 2020-01-01 00:00:00\n")
            (insert ":END:\n")
            (insert "#+begin_src python :tangle ./source.py :mkdirp yes\n")
            (insert "print('original')\n")
            (insert "#+end_src\n")
            (write-file temp-org))
          ;; Modify source file externally
          (with-temp-file source-file
            (insert "print('modified content')\n"))
          ;; Refresh the block
          (with-current-buffer (find-file-noselect temp-org)
            (goto-char (point-min))
            (search-forward "print")
            (org-directory-importer-refresh-block)
            ;; Verify content was updated
            (goto-char (point-min))
            (should (search-forward "print('modified content')" nil t))
            ;; Verify metadata was updated
            (goto-char (point-min))
            (should (search-forward "IMPORT_CHECKSUM" nil t))
            (should-not (search-forward "old-checksum-value" (line-end-position) t))
            ;; Verify SIZE was updated (new file is longer)
            (goto-char (point-min))
            (search-forward "IMPORT_SIZE")
            (should-not (search-forward "100" (line-end-position) t))
            (kill-buffer)))
      ;; Cleanup
      (when (file-directory-p temp-dir)
        (delete-directory temp-dir t)))))

;;; Error handling tests

(ert-deftest test-refresh-block-not-in-src-block ()
  "Error when point not in src block."
  (let ((temp-org (make-temp-file "test-refresh" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Just a heading\nSome text here.\n")
            (goto-char (point-min))
            (forward-line 1)
            (should-error
             (org-directory-importer-refresh-block)
             :type 'user-error)))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

(ert-deftest test-refresh-block-no-tangle-path ()
  "Error when no :tangle specified."
  (let ((temp-org (make-temp-file "test-refresh" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Test\n")
            (insert "#+begin_src python\n")
            (insert "print('test')\n")
            (insert "#+end_src\n")
            (goto-char (point-min))
            (search-forward "print")
            (should-error
             (org-directory-importer-refresh-block)
             :type 'user-error)))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

(ert-deftest test-refresh-block-tangle-no ()
  "Error when :tangle is 'no'."
  (let ((temp-org (make-temp-file "test-refresh" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Test\n")
            (insert "#+begin_src python :tangle no\n")
            (insert "print('test')\n")
            (insert "#+end_src\n")
            (goto-char (point-min))
            (search-forward "print")
            (should-error
             (org-directory-importer-refresh-block)
             :type 'user-error)))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

(ert-deftest test-refresh-block-file-not-found ()
  "Error when file doesn't exist."
  (let ((temp-org (make-temp-file "test-refresh" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Test\n")
            (insert "#+begin_src python :tangle /nonexistent/path/file.py\n")
            (insert "print('test')\n")
            (insert "#+end_src\n")
            (goto-char (point-min))
            (search-forward "print")
            (should-error
             (org-directory-importer-refresh-block)
             :type 'user-error)))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

;;; Path handling tests

(ert-deftest test-refresh-block-relative-path ()
  "Handle relative tangle paths correctly."
  (let* ((temp-dir (make-temp-file "test-refresh-dir" t))
         (source-file (expand-file-name "src/main.py" temp-dir))
         (temp-org (expand-file-name "docs/test.org" temp-dir)))
    (unwind-protect
        (progn
          ;; Create directories
          (make-directory (expand-file-name "src" temp-dir) t)
          (make-directory (expand-file-name "docs" temp-dir) t)
          ;; Create source file
          (with-temp-file source-file
            (insert "print('hello')\n"))
          ;; Create org file with relative path
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Test\n")
            (insert "#+begin_src python :tangle ../src/main.py :mkdirp yes\n")
            (insert "print('original')\n")
            (insert "#+end_src\n")
            (write-file temp-org))
          ;; Refresh the block
          (with-current-buffer (find-file-noselect temp-org)
            (goto-char (point-min))
            (search-forward "print")
            (org-directory-importer-refresh-block)
            ;; Verify content was updated
            (goto-char (point-min))
            (should (search-forward "print('hello')" nil t))
            (kill-buffer)))
      ;; Cleanup
      (when (file-directory-p temp-dir)
        (delete-directory temp-dir t)))))

(ert-deftest test-refresh-block-absolute-path ()
  "Handle absolute tangle paths correctly."
  (let* ((temp-dir (make-temp-file "test-refresh-dir" t))
         (source-file (expand-file-name "source.py" temp-dir))
         (temp-org (expand-file-name "test.org" temp-dir)))
    (unwind-protect
        (progn
          ;; Create source file
          (with-temp-file source-file
            (insert "print('absolute')\n"))
          ;; Create org file with absolute path
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Test\n")
            (insert (format "#+begin_src python :tangle %s :mkdirp yes\n" source-file))
            (insert "print('original')\n")
            (insert "#+end_src\n")
            (write-file temp-org))
          ;; Refresh the block
          (with-current-buffer (find-file-noselect temp-org)
            (goto-char (point-min))
            (search-forward "print")
            (org-directory-importer-refresh-block)
            ;; Verify content was updated
            (goto-char (point-min))
            (should (search-forward "print('absolute')" nil t))
            (kill-buffer)))
      ;; Cleanup
      (when (file-directory-p temp-dir)
        (delete-directory temp-dir t)))))

;;; Edge cases

(ert-deftest test-refresh-block-content-unchanged ()
  "No error when file unchanged."
  (let* ((temp-dir (make-temp-file "test-refresh-dir" t))
         (source-file (expand-file-name "source.py" temp-dir))
         (temp-org (expand-file-name "test.org" temp-dir)))
    (unwind-protect
        (progn
          ;; Create source file
          (with-temp-file source-file
            (insert "print('same')\n"))
          ;; Create org file with same content
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Test\n")
            (insert "#+begin_src python :tangle ./source.py :mkdirp yes\n")
            (insert "print('same')\n")
            (insert "#+end_src\n")
            (write-file temp-org))
          ;; Refresh the block (should not error)
          (with-current-buffer (find-file-noselect temp-org)
            (goto-char (point-min))
            (search-forward "print")
            (org-directory-importer-refresh-block)
            ;; Verify content still there
            (goto-char (point-min))
            (should (search-forward "print('same')" nil t))
            (kill-buffer)))
      ;; Cleanup
      (when (file-directory-p temp-dir)
        (delete-directory temp-dir t)))))

(ert-deftest test-refresh-block-preserves-block-params ()
  "Language and other params preserved after refresh."
  (let* ((temp-dir (make-temp-file "test-refresh-dir" t))
         (source-file (expand-file-name "source.py" temp-dir))
         (temp-org (expand-file-name "test.org" temp-dir)))
    (unwind-protect
        (progn
          ;; Create source file
          (with-temp-file source-file
            (insert "print('new')\n"))
          ;; Create org file with extra params
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Test\n")
            (insert "#+begin_src python :tangle ./source.py :mkdirp yes :results output\n")
            (insert "print('old')\n")
            (insert "#+end_src\n")
            (write-file temp-org))
          ;; Refresh the block
          (with-current-buffer (find-file-noselect temp-org)
            (goto-char (point-min))
            (search-forward "print")
            (org-directory-importer-refresh-block)
            ;; Verify content was updated
            (goto-char (point-min))
            (should (search-forward "print('new')" nil t))
            ;; Verify params preserved (search from beginning for each)
            (goto-char (point-min))
            (should (search-forward ":results output" nil t))
            (goto-char (point-min))
            (should (search-forward ":mkdirp yes" nil t))
            (kill-buffer)))
      ;; Cleanup
      (when (file-directory-p temp-dir)
        (delete-directory temp-dir t)))))

(provide 'test-refresh-block)
;;; test-refresh-block.el ends here
