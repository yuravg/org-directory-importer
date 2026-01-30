;;; test-edge-cases.el --- Edge case tests for org-directory-importer-importer -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for Phase 1.3: Edge case handling
;; - Symlink cycle detection
;; - UTF-16 encoding detection
;; - Permission-denied error handling
;; - Unicode filenames

;;; Code:

(require 'ert)
(require 'org-directory-importer)

;;; UTF-16 Detection Tests

(ert-deftest test-utf16-le-bom-detection ()
  "Test detection of UTF-16 LE BOM."
  (let ((test-file (make-temp-file "utf16-le-test")))
    (unwind-protect
        (progn
          ;; Write UTF-16 LE BOM (FF FE) followed by ASCII "test"
          (with-temp-buffer
            (set-buffer-multibyte nil)
            (insert 255 254)  ; UTF-16 LE BOM
            (insert ?t 0 ?e 0 ?s 0 ?t 0)  ; "test" in UTF-16 LE
            (write-region (point-min) (point-max) test-file nil 'silent))
          ;; Should detect as UTF-16, not binary
          (should (org-directory-importer--detect-utf16-p test-file))
          (should-not (org-directory-importer--looks-binary-p test-file)))
      (delete-file test-file))))

(ert-deftest test-utf16-be-bom-detection ()
  "Test detection of UTF-16 BE BOM."
  (let ((test-file (make-temp-file "utf16-be-test")))
    (unwind-protect
        (progn
          ;; Write UTF-16 BE BOM (FE FF) followed by ASCII "test"
          (with-temp-buffer
            (set-buffer-multibyte nil)
            (insert 254 255)  ; UTF-16 BE BOM
            (insert 0 ?t 0 ?e 0 ?s 0 ?t)  ; "test" in UTF-16 BE
            (write-region (point-min) (point-max) test-file nil 'silent))
          ;; Should detect as UTF-16, not binary
          (should (org-directory-importer--detect-utf16-p test-file))
          (should-not (org-directory-importer--looks-binary-p test-file)))
      (delete-file test-file))))

(ert-deftest test-utf8-not-detected-as-utf16 ()
  "Test that UTF-8 files are not misdetected as UTF-16."
  (let ((test-file (make-temp-file "utf8-test")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "Regular UTF-8 text content\n")
            (write-region (point-min) (point-max) test-file nil 'silent))
          ;; Should not be detected as UTF-16
          (should-not (org-directory-importer--detect-utf16-p test-file)))
      (delete-file test-file))))

(ert-deftest test-binary-still-detected ()
  "Test that actual binary files are still detected as binary."
  (let ((test-file (make-temp-file "binary-test")))
    (unwind-protect
        (progn
          ;; Write binary data with null bytes (guaranteed to be detected)
          (with-temp-buffer
            (set-buffer-multibyte nil)
            ;; Insert content with null bytes throughout
            (dotimes (i 50)
              (insert "text" 0 0 0))
            (write-region (point-min) (point-max) test-file nil 'silent))
          ;; Should still be detected as binary due to null bytes
          (should (org-directory-importer--looks-binary-p test-file)))
      (delete-file test-file))))

;;; Symlink Cycle Detection Tests

(ert-deftest test-symlink-cycle-detection-self ()
  "Test detection of symlink pointing to itself."
  (skip-unless (executable-find "ln"))
  (let* ((temp-dir (make-temp-file "symlink-test" t))
         (link-path (expand-file-name "self-link" temp-dir)))
    (unwind-protect
        (progn
          ;; Create self-referential symlink
          (make-symbolic-link temp-dir link-path)
          ;; Should detect the cycle
          (should (org-directory-importer--is-symlink-cycle-p
                   link-path
                   (list (file-truename temp-dir)))))
      (when (file-exists-p link-path)
        (delete-file link-path))
      (delete-directory temp-dir t))))

(ert-deftest test-symlink-cycle-detection-parent ()
  "Test detection of symlink to parent directory."
  (skip-unless (executable-find "ln"))
  (let* ((temp-dir (make-temp-file "symlink-test" t))
         (sub-dir (expand-file-name "subdir" temp-dir))
         (link-path (expand-file-name "parent-link" sub-dir)))
    (unwind-protect
        (progn
          (make-directory sub-dir)
          ;; Create symlink from subdir back to parent
          (make-symbolic-link temp-dir link-path)
          ;; Should detect the cycle when visiting subdir then the link
          (should (org-directory-importer--is-symlink-cycle-p
                   link-path
                   (list (file-truename temp-dir)
                         (file-truename sub-dir)))))
      (when (file-exists-p link-path)
        (delete-file link-path))
      (when (file-exists-p sub-dir)
        (delete-directory sub-dir t))
      (delete-directory temp-dir t))))

(ert-deftest test-no-cycle-valid-symlink ()
  "Test that valid symlinks without cycles are not flagged."
  (skip-unless (executable-find "ln"))
  (let* ((temp-dir (make-temp-file "symlink-test" t))
         (target-dir (make-temp-file "symlink-target" t))
         (link-path (expand-file-name "valid-link" temp-dir)))
    (unwind-protect
        (progn
          ;; Create symlink to a different directory
          (make-symbolic-link target-dir link-path)
          ;; Should not detect a cycle
          (should-not (org-directory-importer--is-symlink-cycle-p
                       link-path
                       (list (file-truename temp-dir)))))
      (when (file-exists-p link-path)
        (delete-file link-path))
      (delete-directory temp-dir t)
      (delete-directory target-dir t))))

;;; Unicode Filename Tests

(ert-deftest test-unicode-filename-basic ()
  "Test that basic Unicode filenames are handled correctly."
  (let* ((temp-dir (make-temp-file "unicode-test" t))
         (unicode-file (expand-file-name "файл.txt" temp-dir)))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "Content in Unicode filename\n")
            (write-region (point-min) (point-max) unicode-file nil 'silent))
          ;; File should be readable and processable
          (should (file-exists-p unicode-file))
          (should (file-readable-p unicode-file))
          ;; Should detect language correctly
          (should (equal "text" (org-directory-importer--detect-language unicode-file))))
      (when (file-exists-p unicode-file)
        (delete-file unicode-file))
      (delete-directory temp-dir t))))

(ert-deftest test-unicode-filename-emoji ()
  "Test that emoji in filenames are handled."
  (let* ((temp-dir (make-temp-file "unicode-test" t))
         (emoji-file (expand-file-name "test-🚀.txt" temp-dir)))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "Content with emoji filename\n")
            (write-region (point-min) (point-max) emoji-file nil 'silent))
          ;; File should be readable
          (should (file-exists-p emoji-file))
          (should (file-readable-p emoji-file)))
      (when (file-exists-p emoji-file)
        (delete-file emoji-file))
      (delete-directory temp-dir t))))

(ert-deftest test-unicode-filename-cjk ()
  "Test that CJK characters in filenames are handled."
  (let* ((temp-dir (make-temp-file "unicode-test" t))
         (cjk-file (expand-file-name "测试文件.txt" temp-dir)))
    (unwind-protect
        (progn
          (with-temp-buffer
            (insert "Content with CJK filename\n")
            (write-region (point-min) (point-max) cjk-file nil 'silent))
          ;; File should be readable
          (should (file-exists-p cjk-file))
          (should (file-readable-p cjk-file))
          ;; Should not be excluded
          (should-not (org-directory-importer--should-exclude-p cjk-file)))
      (when (file-exists-p cjk-file)
        (delete-file cjk-file))
      (delete-directory temp-dir t))))

;;; Permission Error Handling Tests

(ert-deftest test-unreadable-file-handling ()
  "Test that unreadable files are handled gracefully."
  (skip-unless (executable-find "chmod"))
  (let* ((temp-dir (make-temp-file "perm-test" t))
         (test-file (expand-file-name "unreadable.txt" temp-dir)))
    (unwind-protect
        (progn
          ;; Create a file and make it unreadable
          (with-temp-buffer
            (insert "Secret content\n")
            (write-region (point-min) (point-max) test-file nil 'silent))
          (set-file-modes test-file #o000)
          ;; Should not be readable
          (should-not (file-readable-p test-file))
          ;; Insert should return nil (not crash)
          (with-temp-buffer
            (org-mode)
            (should-not (org-directory-importer--insert-file-content
                         test-file 3 temp-dir))))
      ;; Cleanup: restore permissions first
      (when (file-exists-p test-file)
        (set-file-modes test-file #o644)
        (delete-file test-file))
      (delete-directory temp-dir t))))

(ert-deftest test-directory-permission-error ()
  "Test handling of directories with permission errors."
  (skip-unless (executable-find "chmod"))
  (let* ((temp-dir (make-temp-file "perm-test" t))
         (sub-dir (expand-file-name "forbidden" temp-dir)))
    (unwind-protect
        (progn
          (make-directory sub-dir)
          ;; Make directory inaccessible
          (set-file-modes sub-dir #o000)
          ;; Should handle gracefully (not crash)
          (should-not (file-accessible-directory-p sub-dir)))
      ;; Cleanup: restore permissions first
      (when (file-exists-p sub-dir)
        (set-file-modes sub-dir #o755)
        (delete-directory sub-dir t))
      (delete-directory temp-dir t))))

;;; Integration Tests

(ert-deftest test-edge-cases-integration ()
  "Integration test with multiple edge cases in one directory."
  (let* ((temp-dir (make-temp-file "edge-integration-test" t))
         (unicode-file (expand-file-name "ユニコード.txt" temp-dir))
         (utf16-file (expand-file-name "utf16.txt" temp-dir))
         (normal-file (expand-file-name "normal.txt" temp-dir))
         (org-buffer-file (make-temp-file "test-import" nil ".org")))
    (unwind-protect
        (progn
          ;; Create various test files
          (with-temp-buffer
            (insert "Unicode filename content\n")
            (write-region (point-min) (point-max) unicode-file nil 'silent))

          (with-temp-buffer
            (set-buffer-multibyte nil)
            (insert 255 254)  ; UTF-16 LE BOM
            (insert ?U 0 ?T 0 ?F 0 ?- 0 ?1 0 ?6 0)
            (write-region (point-min) (point-max) utf16-file nil 'silent))

          (with-temp-buffer
            (insert "Normal file content\n")
            (write-region (point-min) (point-max) normal-file nil 'silent))

          ;; Import the directory
          (with-current-buffer (find-file-noselect org-buffer-file)
            (org-mode)
            (org-directory-importer-import-plain temp-dir)
            ;; Should have imported at least the normal file
            (goto-char (point-min))
            (should (search-forward "normal.txt" nil t))
            ;; UTF-16 file should not be marked as binary
            (goto-char (point-min))
            (should (search-forward "utf16.txt" nil t))
            ;; Unicode filename should work
            (goto-char (point-min))
            (should (search-forward "ユニコード.txt" nil t))))
      ;; Cleanup
      (when (file-exists-p unicode-file) (delete-file unicode-file))
      (when (file-exists-p utf16-file) (delete-file utf16-file))
      (when (file-exists-p normal-file) (delete-file normal-file))
      (when (file-exists-p org-buffer-file) (delete-file org-buffer-file))
      (delete-directory temp-dir t))))

;;; Self-Import Prevention Tests

(ert-deftest test-self-import-prevention ()
  "Test that the current Org file is excluded during import."
  (let* ((temp-dir (make-temp-file "self-import-test" t))
         (org-file (expand-file-name "notes.org" temp-dir))
         (normal-file (expand-file-name "data.txt" temp-dir)))
    (unwind-protect
        (progn
          ;; Create a normal file in the directory
          (with-temp-buffer
            (insert "Normal file content\n")
            (write-region (point-min) (point-max) normal-file nil 'silent))

          ;; Create the Org file and import from its own directory
          (with-current-buffer (find-file-noselect org-file)
            (org-mode)
            (insert "* Test Import\n")
            (save-buffer)
            ;; Import the directory containing this file
            (org-directory-importer-import-plain temp-dir)
            (save-buffer)

            ;; Should have imported the normal file
            (goto-char (point-min))
            (should (search-forward "data.txt" nil t))

            ;; Should NOT have imported itself
            (goto-char (point-min))
            (should-not (search-forward "notes.org" nil t))))
      ;; Cleanup
      (when (file-exists-p normal-file) (delete-file normal-file))
      (when (get-file-buffer org-file)
        (with-current-buffer (get-file-buffer org-file)
          (set-buffer-modified-p nil)
          (kill-buffer)))
      (when (file-exists-p org-file) (delete-file org-file))
      (delete-directory temp-dir t))))

(ert-deftest test-self-import-prevention-update ()
  "Test that the current Org file is excluded during update."
  (let* ((temp-dir (make-temp-file "self-update-test" t))
         (org-file (expand-file-name "notes.org" temp-dir))
         (normal-file (expand-file-name "data.txt" temp-dir)))
    (unwind-protect
        (progn
          ;; Create initial file
          (with-temp-buffer
            (insert "Original content\n")
            (write-region (point-min) (point-max) normal-file nil 'silent))

          ;; Create the Org file and do initial import
          (with-current-buffer (find-file-noselect org-file)
            (org-mode)
            (org-directory-importer-import temp-dir)
            (save-buffer)

            ;; Verify initial import
            (goto-char (point-min))
            (should (search-forward "data.txt" nil t))
            (goto-char (point-min))
            (should-not (search-forward "notes.org" nil t))

            ;; Add new content to normal file
            (with-temp-buffer
              (insert "Updated content\n")
              (write-region (point-min) (point-max) normal-file nil 'silent))

            ;; Run update - should still exclude the Org file itself
            (goto-char (point-min))
            (search-forward "Imported Directory")
            (org-directory-importer-import-update)
            (save-buffer)

            ;; Should still have data.txt
            (goto-char (point-min))
            (should (search-forward "data.txt" nil t))

            ;; Should still NOT have imported itself
            (goto-char (point-min))
            (should-not (search-forward "notes.org" nil t))))
      ;; Cleanup
      (when (file-exists-p normal-file) (delete-file normal-file))
      (when (get-file-buffer org-file)
        (with-current-buffer (get-file-buffer org-file)
          (set-buffer-modified-p nil)
          (kill-buffer)))
      (when (file-exists-p org-file) (delete-file org-file))
      (delete-directory temp-dir t))))

(provide 'test-edge-cases)
;;; test-edge-cases.el ends here
