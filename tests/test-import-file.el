;;; test-import-file.el --- ERT tests for single file import -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; This file is part of org-directory-importer.

;;; Commentary:

;; ERT test suite for `org-directory-importer-import-file'.
;;
;; Tests the unconditional single file import command that is the inverse
;; of `org-babel-tangle-file'.

;;; Code:

(require 'ert)
(require 'org-directory-importer)
(require 'ob-tangle)

(defvar test-import-file-fixtures-dir
  (expand-file-name "fixtures/projects/simple" (file-name-directory load-file-name))
  "Directory containing test fixtures.")

;;; Basic functionality tests

(ert-deftest test-import-file-basic ()
  "Import a regular text file successfully."
  (let ((test-file (expand-file-name "src/main.py" test-import-file-fixtures-dir))
        (temp-org (make-temp-file "test-import-file" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (let ((org-directory-importer-tangle-path-type 'absolute))
              (org-directory-importer-import-file test-file))
            ;; Verify heading was created
            (goto-char (point-min))
            (should (search-forward "* main.py" nil t))
            ;; Verify properties
            (should (search-forward ":IMPORT_PATH:" nil t))
            (should (search-forward ":IMPORT_CHECKSUM:" nil t))
            (should (search-forward ":IMPORT_SIZE:" nil t))
            (should (search-forward ":IMPORT_MTIME:" nil t))
            ;; Verify source block
            (should (search-forward "#+begin_src python" nil t))
            (should (search-forward ":tangle" nil t))
            (should (search-forward "#+end_src" nil t))))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

(ert-deftest test-import-file-binary-allowed ()
  "Import a binary file unconditionally (no filtering)."
  (let ((temp-binary (make-temp-file "test-binary"))
        (temp-org (make-temp-file "test-import-file" nil ".org")))
    (unwind-protect
        (progn
          ;; Create a binary file with null bytes
          (with-temp-file temp-binary
            (insert "binary\0content\0here"))
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (let ((org-directory-importer-tangle-path-type 'absolute))
              (org-directory-importer-import-file temp-binary))
            ;; Verify file was imported (no binary filtering)
            (goto-char (point-min))
            (should (search-forward "#+begin_src" nil t))
            (should (search-forward "binary" nil t))))
      (when (file-exists-p temp-binary)
        (delete-file temp-binary))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

(ert-deftest test-import-file-excluded-pattern-allowed ()
  "Import a file matching excluded patterns unconditionally."
  (let ((temp-log (make-temp-file "test" nil ".log"))
        (temp-org (make-temp-file "test-import-file" nil ".org")))
    (unwind-protect
        (progn
          ;; Create a .log file (normally excluded)
          (with-temp-file temp-log
            (insert "log content here"))
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (let ((org-directory-importer-tangle-path-type 'absolute))
              (org-directory-importer-import-file temp-log))
            ;; Verify file was imported (no pattern filtering)
            (goto-char (point-min))
            (should (search-forward "#+begin_src" nil t))
            (should (search-forward "log content" nil t))))
      (when (file-exists-p temp-log)
        (delete-file temp-log))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

;;; Error handling tests

(ert-deftest test-import-file-non-org-buffer-error ()
  "Error when importing into non-org buffer."
  (with-temp-buffer
    (fundamental-mode)
    (should-error
     (org-directory-importer-import-file "/tmp/test.txt")
     :type 'user-error)))

(ert-deftest test-import-file-nonexistent-error ()
  "Error when importing non-existent file."
  (let ((temp-org (make-temp-file "test-import-file" nil ".org")))
    (unwind-protect
        (with-temp-buffer
          (org-mode)
          (set-visited-file-name temp-org t)
          (should-error
           (org-directory-importer-import-file "/nonexistent/file/path.txt")
           :type 'user-error))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

(ert-deftest test-import-file-relative-unsaved-error ()
  "Error when using relative paths with unsaved buffer."
  (with-temp-buffer
    (org-mode)
    ;; Don't set visited file name
    (let ((temp-file (make-temp-file "test-file")))
      (unwind-protect
          (progn
            (with-temp-file temp-file
              (insert "test content"))
            (let ((org-directory-importer-tangle-path-type 'relative))
              (should-error
               (org-directory-importer-import-file temp-file)
               :type 'user-error)))
        (when (file-exists-p temp-file)
          (delete-file temp-file))))))

;;; Tangle path tests

(ert-deftest test-import-file-absolute-path ()
  "Import file with absolute tangle path."
  (let ((temp-file (make-temp-file "test-file"))
        (temp-org (make-temp-file "test-import-file" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file temp-file
            (insert "test content"))
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (let ((org-directory-importer-tangle-path-type 'absolute))
              (org-directory-importer-import-file temp-file))
            ;; Verify absolute path in tangle
            (goto-char (point-min))
            (should (search-forward (format ":tangle %s" temp-file) nil t))))
      (when (file-exists-p temp-file)
        (delete-file temp-file))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

(ert-deftest test-import-file-relative-path ()
  "Import file with relative tangle path."
  (let* ((temp-dir (make-temp-file "test-import-dir" t))
         (temp-file (expand-file-name "source.txt" temp-dir))
         (temp-org (expand-file-name "notes.org" temp-dir)))
    (unwind-protect
        (progn
          (with-temp-file temp-file
            (insert "test content"))
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (let ((org-directory-importer-tangle-path-type 'relative))
              (org-directory-importer-import-file temp-file))
            ;; Verify relative path in tangle (should be ./source.txt)
            (goto-char (point-min))
            (should (search-forward ":tangle ./source.txt" nil t))))
      (when (file-exists-p temp-file)
        (delete-file temp-file))
      (when (file-exists-p temp-org)
        (delete-file temp-org))
      (when (file-directory-p temp-dir)
        (delete-directory temp-dir t)))))

;;; Header level tests

(ert-deftest test-import-file-top-level ()
  "Import file at top level when not under a heading."
  (let ((temp-file (make-temp-file "test-file"))
        (temp-org (make-temp-file "test-import-file" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file temp-file
            (insert "content"))
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (let ((org-directory-importer-tangle-path-type 'absolute))
              (org-directory-importer-import-file temp-file))
            ;; Should create level 1 heading
            (goto-char (point-min))
            (should (looking-at "\\* "))))
      (when (file-exists-p temp-file)
        (delete-file temp-file))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

(ert-deftest test-import-file-subheading ()
  "Import file as subheading when under an existing heading."
  (let ((temp-file (make-temp-file "test-file"))
        (temp-org (make-temp-file "test-import-file" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file temp-file
            (insert "content"))
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (insert "* Parent Heading\n")
            (goto-char (point-min))
            (org-end-of-line)
            (let ((org-directory-importer-tangle-path-type 'absolute))
              (org-directory-importer-import-file temp-file))
            ;; Should create level 2 heading
            (goto-char (point-min))
            (should (search-forward "** " nil t))))
      (when (file-exists-p temp-file)
        (delete-file temp-file))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

;;; Language detection tests

(ert-deftest test-import-file-language-detection ()
  "Verify language detection works for imported files."
  (let ((temp-py (make-temp-file "test" nil ".py"))
        (temp-org (make-temp-file "test-import-file" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file temp-py
            (insert "print('hello')"))
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (let ((org-directory-importer-tangle-path-type 'absolute))
              (org-directory-importer-import-file temp-py))
            ;; Verify python language detected
            (goto-char (point-min))
            (should (search-forward "#+begin_src python" nil t))))
      (when (file-exists-p temp-py)
        (delete-file temp-py))
      (when (file-exists-p temp-org)
        (delete-file temp-org)))))

;;; Roundtrip test

(ert-deftest test-import-file-roundtrip ()
  "Import a file, tangle it, and verify content matches."
  (let* ((temp-dir (make-temp-file "test-roundtrip-dir" t))
         (original-file (expand-file-name "original.py" temp-dir))
         (temp-org (expand-file-name "test.org" temp-dir))
         (tangled-file nil)
         (original-content "#!/usr/bin/env python3\n\ndef main():\n    print('hello world')\n\nif __name__ == '__main__':\n    main()\n"))
    (unwind-protect
        (progn
          ;; Create original file
          (with-temp-file original-file
            (insert original-content))
          ;; Import into org buffer
          (with-temp-buffer
            (org-mode)
            (set-visited-file-name temp-org t)
            (let ((org-directory-importer-tangle-path-type 'absolute))
              (org-directory-importer-import-file original-file))
            (write-file temp-org))
          ;; Delete original to prove tangle works
          (delete-file original-file)
          ;; Tangle back
          (with-current-buffer (find-file-noselect temp-org)
            (org-babel-tangle)
            (kill-buffer))
          ;; Verify tangled file matches original content
          (should (file-exists-p original-file))
          (with-temp-buffer
            (insert-file-contents original-file)
            (should (equal (buffer-string) original-content))))
      ;; Cleanup
      (when (file-directory-p temp-dir)
        (delete-directory temp-dir t)))))

(provide 'test-import-file)
;;; test-import-file.el ends here
