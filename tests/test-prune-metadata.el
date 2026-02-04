;;; test-prune-metadata.el --- Tests for prune-metadata and C-u import -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for Phase 2.2: Universal argument and metadata pruning
;; - C-u prefix for plain import (skip-metadata)
;; - org-directory-importer-prune-metadata command
;; - Backwards compatibility of import-plain wrapper

;;; Code:

(require 'ert)
(require 'org-directory-importer)

;;; C-u Import (skip-metadata) Tests

(ert-deftest test-import-with-metadata-has-properties ()
  "Test that normal import includes IMPORT_* properties."
  (let* ((temp-dir (make-temp-file "import-test" t))
         (test-file (expand-file-name "test.txt" temp-dir))
         (org-buffer-file (make-temp-file "test-import" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "Test content\n")
            (write-region (point-min) (point-max) test-file nil 'silent))

          (with-current-buffer (find-file-noselect org-buffer-file)
            (org-mode)
            ;; Normal import (with metadata)
            (org-directory-importer-import temp-dir nil)
            (save-buffer)

            ;; Should have IMPORT_SOURCE on top-level heading
            (goto-char (point-min))
            (should (search-forward "IMPORT_SOURCE" nil t))

            ;; Should have IMPORT_PATH on file heading
            (goto-char (point-min))
            (should (search-forward "IMPORT_PATH" nil t))

            ;; Should have IMPORT_CHECKSUM
            (goto-char (point-min))
            (should (search-forward "IMPORT_CHECKSUM" nil t))))
      ;; Cleanup
      (when (file-exists-p test-file) (delete-file test-file))
      (when (get-file-buffer org-buffer-file)
        (with-current-buffer (get-file-buffer org-buffer-file)
          (set-buffer-modified-p nil)
          (kill-buffer)))
      (when (file-exists-p org-buffer-file) (delete-file org-buffer-file))
      (delete-directory temp-dir t))))

(ert-deftest test-import-skip-metadata-no-properties ()
  "Test that import with skip-metadata has no IMPORT_* properties."
  (let* ((temp-dir (make-temp-file "import-test" t))
         (test-file (expand-file-name "test.txt" temp-dir))
         (org-buffer-file (make-temp-file "test-import" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "Test content\n")
            (write-region (point-min) (point-max) test-file nil 'silent))

          (with-current-buffer (find-file-noselect org-buffer-file)
            (org-mode)
            ;; Import with skip-metadata (C-u equivalent)
            (org-directory-importer-import temp-dir t)
            (save-buffer)

            ;; Should NOT have IMPORT_SOURCE
            (goto-char (point-min))
            (should-not (search-forward "IMPORT_SOURCE" nil t))

            ;; Should NOT have IMPORT_PATH
            (goto-char (point-min))
            (should-not (search-forward "IMPORT_PATH" nil t))

            ;; Should NOT have IMPORT_CHECKSUM
            (goto-char (point-min))
            (should-not (search-forward "IMPORT_CHECKSUM" nil t))

            ;; But SHOULD have the file content
            (goto-char (point-min))
            (should (search-forward "test.txt" nil t))
            (should (search-forward "Test content" nil t))))
      ;; Cleanup
      (when (file-exists-p test-file) (delete-file test-file))
      (when (get-file-buffer org-buffer-file)
        (with-current-buffer (get-file-buffer org-buffer-file)
          (set-buffer-modified-p nil)
          (kill-buffer)))
      (when (file-exists-p org-buffer-file) (delete-file org-buffer-file))
      (delete-directory temp-dir t))))

(ert-deftest test-import-plain-wrapper-is-skip-metadata ()
  "Test that import-plain wrapper produces same result as skip-metadata."
  (let* ((temp-dir (make-temp-file "import-test" t))
         (test-file (expand-file-name "test.py" temp-dir))
         (org-buffer-file (make-temp-file "test-import" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "print('hello')\n")
            (write-region (point-min) (point-max) test-file nil 'silent))

          (with-current-buffer (find-file-noselect org-buffer-file)
            (org-mode)
            ;; Use import-plain wrapper
            (org-directory-importer-import-plain temp-dir)
            (save-buffer)

            ;; Should NOT have IMPORT_* properties (same as skip-metadata)
            (goto-char (point-min))
            (should-not (search-forward "IMPORT_SOURCE" nil t))
            (goto-char (point-min))
            (should-not (search-forward "IMPORT_PATH" nil t))

            ;; But SHOULD have the file content
            (goto-char (point-min))
            (should (search-forward "test.py" nil t))
            (should (search-forward "print('hello')" nil t))))
      ;; Cleanup
      (when (file-exists-p test-file) (delete-file test-file))
      (when (get-file-buffer org-buffer-file)
        (with-current-buffer (get-file-buffer org-buffer-file)
          (set-buffer-modified-p nil)
          (kill-buffer)))
      (when (file-exists-p org-buffer-file) (delete-file org-buffer-file))
      (delete-directory temp-dir t))))

;;; Prune Metadata Tests

(ert-deftest test-prune-metadata-empty-buffer ()
  "Test prune-metadata on buffer with no properties."
  (with-temp-buffer
    (org-mode)
    (insert "* Test Heading\n")
    (insert "Some content\n")
    ;; Should complete without error
    (org-directory-importer-prune-metadata)
    ;; Content should be unchanged
    (goto-char (point-min))
    (should (search-forward "Test Heading" nil t))))

(ert-deftest test-prune-metadata-removes-import-properties ()
  "Test that prune-metadata removes IMPORT_* properties."
  (with-temp-buffer
    (org-mode)
    (insert "* Test File\n")
    (insert ":PROPERTIES:\n")
    (insert ":IMPORT_PATH: test/file.py\n")
    (insert ":IMPORT_CHECKSUM: abc123\n")
    (insert ":IMPORT_SIZE: 42\n")
    (insert ":IMPORT_MTIME: 2026-01-01 12:00:00\n")
    (insert ":END:\n")
    (insert "Content here\n")

    ;; Prune metadata
    (org-directory-importer-prune-metadata)

    ;; IMPORT_* properties should be gone
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_PATH" nil t))
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_CHECKSUM" nil t))
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_SIZE" nil t))
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_MTIME" nil t))

    ;; Content should still exist
    (goto-char (point-min))
    (should (search-forward "Test File" nil t))
    (should (search-forward "Content here" nil t))))

(ert-deftest test-prune-metadata-preserves-other-properties ()
  "Test that prune-metadata preserves non-IMPORT_* properties."
  (with-temp-buffer
    (org-mode)
    (insert "* Test Entry\n")
    (insert ":PROPERTIES:\n")
    (insert ":IMPORT_PATH: test/file.txt\n")
    (insert ":CUSTOM_ID: my-entry\n")
    (insert ":IMPORT_CHECKSUM: xyz789\n")
    (insert ":CATEGORY: testing\n")
    (insert ":END:\n")

    (org-directory-importer-prune-metadata)

    ;; IMPORT_* should be removed
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_PATH" nil t))
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_CHECKSUM" nil t))

    ;; Other properties should remain
    (goto-char (point-min))
    (should (search-forward "CUSTOM_ID" nil t))
    (goto-char (point-min))
    (should (search-forward "CATEGORY" nil t))))

(ert-deftest test-prune-metadata-multiple-entries ()
  "Test prune-metadata handles multiple entries."
  (with-temp-buffer
    (org-mode)
    (insert "* Imported Directory: test\n")
    (insert ":PROPERTIES:\n")
    (insert ":IMPORT_SOURCE: /tmp/test\n")
    (insert ":IMPORT_DATE: 2026-01-01 12:00:00\n")
    (insert ":END:\n")
    (insert "** ./\n")
    (insert "*** file1.txt\n")
    (insert ":PROPERTIES:\n")
    (insert ":IMPORT_PATH: file1.txt\n")
    (insert ":IMPORT_CHECKSUM: aaa\n")
    (insert ":END:\n")
    (insert "#+begin_src text\nContent 1\n#+end_src\n")
    (insert "*** file2.txt\n")
    (insert ":PROPERTIES:\n")
    (insert ":IMPORT_PATH: file2.txt\n")
    (insert ":IMPORT_CHECKSUM: bbb\n")
    (insert ":END:\n")
    (insert "#+begin_src text\nContent 2\n#+end_src\n")

    (org-directory-importer-prune-metadata)

    ;; All IMPORT_* properties should be gone
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_SOURCE" nil t))
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_DATE" nil t))
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_PATH" nil t))
    (goto-char (point-min))
    (should-not (search-forward "IMPORT_CHECKSUM" nil t))

    ;; Content should still exist
    (goto-char (point-min))
    (should (search-forward "Content 1" nil t))
    (should (search-forward "Content 2" nil t))))

(ert-deftest test-prune-metadata-on-real-import ()
  "Test prune-metadata on actual imported content."
  (let* ((temp-dir (make-temp-file "prune-test" t))
         (test-file (expand-file-name "test.txt" temp-dir))
         (org-buffer-file (make-temp-file "test-import" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "Test content\n")
            (write-region (point-min) (point-max) test-file nil 'silent))

          (with-current-buffer (find-file-noselect org-buffer-file)
            (org-mode)
            ;; Normal import (with metadata)
            (org-directory-importer-import temp-dir nil)
            (save-buffer)

            ;; Verify metadata exists
            (goto-char (point-min))
            (should (search-forward "IMPORT_SOURCE" nil t))
            (goto-char (point-min))
            (should (search-forward "IMPORT_PATH" nil t))

            ;; Prune the metadata
            (org-directory-importer-prune-metadata)

            ;; Verify metadata is gone
            (goto-char (point-min))
            (should-not (search-forward "IMPORT_SOURCE" nil t))
            (goto-char (point-min))
            (should-not (search-forward "IMPORT_PATH" nil t))
            (goto-char (point-min))
            (should-not (search-forward "IMPORT_CHECKSUM" nil t))

            ;; But content is preserved
            (goto-char (point-min))
            (should (search-forward "test.txt" nil t))
            (should (search-forward "Test content" nil t))))
      ;; Cleanup
      (when (file-exists-p test-file) (delete-file test-file))
      (when (get-file-buffer org-buffer-file)
        (with-current-buffer (get-file-buffer org-buffer-file)
          (set-buffer-modified-p nil)
          (kill-buffer)))
      (when (file-exists-p org-buffer-file) (delete-file org-buffer-file))
      (delete-directory temp-dir t))))

;;; Update Requires Metadata Tests

(ert-deftest test-update-fails-after-prune ()
  "Test that import-update fails gracefully after pruning metadata."
  (let* ((temp-dir (make-temp-file "update-test" t))
         (test-file (expand-file-name "test.txt" temp-dir))
         (org-buffer-file (make-temp-file "test-import" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "Original content\n")
            (write-region (point-min) (point-max) test-file nil 'silent))

          (with-current-buffer (find-file-noselect org-buffer-file)
            (org-mode)
            ;; Normal import
            (org-directory-importer-import temp-dir nil)
            (save-buffer)

            ;; Prune metadata
            (org-directory-importer-prune-metadata)
            (save-buffer)

            ;; Update should fail (no IMPORT_SOURCE)
            (goto-char (point-min))
            (should-error
             (org-directory-importer-import-update)
             :type 'user-error)))
      ;; Cleanup
      (when (file-exists-p test-file) (delete-file test-file))
      (when (get-file-buffer org-buffer-file)
        (with-current-buffer (get-file-buffer org-buffer-file)
          (set-buffer-modified-p nil)
          (kill-buffer)))
      (when (file-exists-p org-buffer-file) (delete-file org-buffer-file))
      (delete-directory temp-dir t))))

(ert-deftest test-update-fails-on-skip-metadata-import ()
  "Test that import-update fails on plain/skip-metadata imports."
  (let* ((temp-dir (make-temp-file "update-test" t))
         (test-file (expand-file-name "test.txt" temp-dir))
         (org-buffer-file (make-temp-file "test-import" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "Content\n")
            (write-region (point-min) (point-max) test-file nil 'silent))

          (with-current-buffer (find-file-noselect org-buffer-file)
            (org-mode)
            ;; Import with skip-metadata (C-u equivalent)
            (org-directory-importer-import temp-dir t)
            (save-buffer)

            ;; Update should fail (no IMPORT_SOURCE)
            (goto-char (point-min))
            (should-error
             (org-directory-importer-import-update)
             :type 'user-error)))
      ;; Cleanup
      (when (file-exists-p test-file) (delete-file test-file))
      (when (get-file-buffer org-buffer-file)
        (with-current-buffer (get-file-buffer org-buffer-file)
          (set-buffer-modified-p nil)
          (kill-buffer)))
      (when (file-exists-p org-buffer-file) (delete-file org-buffer-file))
      (delete-directory temp-dir t))))

(provide 'test-prune-metadata)
;;; test-prune-metadata.el ends here
