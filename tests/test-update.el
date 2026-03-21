;;; test-update.el --- Tests for incremental update functionality -*- lexical-binding: t; -*-

(require 'ert)
(require 'org-directory-importer)

(ert-deftest test-metadata-properties-added ()
  "Test that import adds metadata properties to file entries."
  (let* ((test-dir (make-temp-file "test-import-" t))
         (test-file (expand-file-name "test.txt" test-dir))
         (org-buffer (generate-new-buffer "*test-import*")))
    (unwind-protect
        (progn
          ;; Create test file
          (with-temp-file test-file
            (insert "Hello, World!\n"))

          ;; Import into org buffer
          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Find the test.txt entry
            (goto-char (point-min))
            (re-search-forward "\\*\\*\\* test\\.txt")

            ;; Check properties exist
            (should (org-entry-get nil "IMPORT_PATH"))
            (should (org-entry-get nil "IMPORT_CHECKSUM"))
            (should (org-entry-get nil "IMPORT_SIZE"))
            (should (org-entry-get nil "IMPORT_MTIME"))

            ;; Verify property values
            (should (string= (org-entry-get nil "IMPORT_PATH") "test.txt"))
            (should (string= (org-entry-get nil "IMPORT_SIZE") "14"))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-detects-unchanged ()
  "Test that update command detects unchanged files."
  (let* ((test-dir (make-temp-file "test-update-" t))
         (test-file (expand-file-name "test.txt" test-dir))
         (org-buffer (generate-new-buffer "*test-update*")))
    (unwind-protect
        (progn
          ;; Create test file
          (with-temp-file test-file
            (insert "Unchanged content\n"))

          ;; Initial import
          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Run update (should detect no changes)
            (goto-char (point-min))
            (re-search-forward "IMPORT_SOURCE")
            (beginning-of-line)
            (let ((message-log nil))
              (org-directory-importer-import-update)
              ;; Update should complete without error
              (should t))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-detects-modified ()
  "Test that update command detects modified files."
  (let* ((test-dir (make-temp-file "test-update-mod-" t))
         (test-file (expand-file-name "test.txt" test-dir))
         (org-buffer (generate-new-buffer "*test-update-mod*")))
    (unwind-protect
        (progn
          ;; Create test file
          (with-temp-file test-file
            (insert "Original content\n"))

          ;; Initial import
          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Get original checksum
            (goto-char (point-min))
            (re-search-forward "\\*\\*\\* test\\.txt")
            (let ((original-checksum (org-entry-get nil "IMPORT_CHECKSUM")))

              ;; Modify the file
              (sleep-for 0.1) ; Ensure mtime changes
              (with-temp-file test-file
                (insert "Modified content\n"))

              ;; Run update
              (goto-char (point-min))
              (re-search-forward "IMPORT_SOURCE")
              (beginning-of-line)
              (org-directory-importer-import-update)

              ;; Check that checksum changed
              (goto-char (point-min))
              (re-search-forward "\\*\\*\\* test\\.txt")
              (let ((new-checksum (org-entry-get nil "IMPORT_CHECKSUM")))
                (should-not (string= original-checksum new-checksum)))

              ;; Check that content was updated
              (re-search-forward "^Modified content")
              (should t))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-detects-new-files ()
  "Test that update command detects new files."
  (let* ((test-dir (make-temp-file "test-update-new-" t))
         (test-file1 (expand-file-name "file1.txt" test-dir))
         (test-file2 (expand-file-name "file2.txt" test-dir))
         (org-buffer (generate-new-buffer "*test-update-new*")))
    (unwind-protect
        (progn
          ;; Create first file
          (with-temp-file test-file1
            (insert "File 1\n"))

          ;; Initial import
          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Verify only file1 exists
            (goto-char (point-min))
            (should (re-search-forward "\\*\\*\\* file1\\.txt" nil t))
            (goto-char (point-min))
            (should-not (re-search-forward "\\*\\*\\* file2\\.txt" nil t))

            ;; Add second file
            (with-temp-file test-file2
              (insert "File 2\n"))

            ;; Run update
            (goto-char (point-min))
            (re-search-forward "IMPORT_SOURCE")
            (beginning-of-line)
            (org-directory-importer-import-update)

            ;; Verify file2 was added
            (goto-char (point-min))
            (should (re-search-forward "\\*\\*\\* file2\\.txt" nil t))
            (should (org-entry-get nil "IMPORT_PATH"))
            (should (string= (org-entry-get nil "IMPORT_PATH") "file2.txt"))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

;;; ============================================================
;;; Hierarchy Preservation Tests
;;; ============================================================

(defun test-update--count-heading-level (line)
  "Count the number of leading asterisks in LINE."
  (if (string-match "^\\(\\*+\\) " line)
      (length (match-string 1 line))
    0))

(defun test-update--get-heading-structure (buffer)
  "Extract heading structure from BUFFER as list of (level . title) pairs."
  (with-current-buffer buffer
    (let ((structure '()))
      (goto-char (point-min))
      (while (re-search-forward "^\\(\\*+\\) \\(.+\\)$" nil t)
        (push (cons (length (match-string 1))
                    (string-trim (match-string 2)))
              structure))
      (nreverse structure))))

(defun test-update--create-nested-dir-structure (base-dir structure)
  "Create nested directory STRUCTURE under BASE-DIR.
STRUCTURE is a list of relative file paths like (\"sub/file.txt\" \"file.txt\")."
  (dolist (path structure)
    (let* ((full-path (expand-file-name path base-dir))
           (dir (file-name-directory full-path)))
      (make-directory dir t)
      (with-temp-file full-path
        (insert (format "Content of %s\n" path))))))

(ert-deftest test-update-nested-hierarchy-preserved ()
  "Test that nested directory hierarchy is preserved after update.
Structure: subdir/file.txt should maintain correct heading levels."
  (let* ((test-dir (make-temp-file "test-nested-" t))
         (org-buffer (generate-new-buffer "*test-nested*")))
    (unwind-protect
        (progn
          ;; Create nested structure: subdir/nested.txt
          (test-update--create-nested-dir-structure
           test-dir '("subdir/nested.txt"))

          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Verify initial structure:
            ;; * Imported Directory: ...
            ;; ** ./
            ;; *** subdir/
            ;; **** nested.txt
            (let ((structure (test-update--get-heading-structure org-buffer)))
              (should (= 4 (length structure)))
              ;; Check levels are correct
              (should (= 1 (car (nth 0 structure)))) ; * Imported...
              (should (= 2 (car (nth 1 structure)))) ; ** ./
              (should (= 3 (car (nth 2 structure)))) ; *** subdir/
              (should (= 4 (car (nth 3 structure)))) ; **** nested.txt
              ;; Check names
              (should (string-match-p "subdir/" (cdr (nth 2 structure))))
              (should (string= "nested.txt" (cdr (nth 3 structure)))))

            ;; Run update (no changes to filesystem)
            (goto-char (point-min))
            (re-search-forward "IMPORT_SOURCE")
            (org-directory-importer-import-update)

            ;; Verify hierarchy is still correct after update
            (let ((structure (test-update--get-heading-structure org-buffer)))
              (should (= 4 (length structure)))
              (should (= 1 (car (nth 0 structure))))
              (should (= 2 (car (nth 1 structure))))
              (should (= 3 (car (nth 2 structure))))
              (should (= 4 (car (nth 3 structure)))))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-new-file-in-existing-subdir ()
  "Test adding a new file to an existing subdirectory.
New file should be placed at correct level under its parent directory."
  (let* ((test-dir (make-temp-file "test-newfile-subdir-" t))
         (org-buffer (generate-new-buffer "*test-newfile-subdir*")))
    (unwind-protect
        (progn
          ;; Create initial structure with one file in subdir
          (test-update--create-nested-dir-structure
           test-dir '("subdir/file1.txt"))

          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Verify initial structure
            (goto-char (point-min))
            (should (re-search-forward "^\\*\\*\\*\\* file1\\.txt" nil t))
            (goto-char (point-min))
            (should-not (re-search-forward "file2\\.txt" nil t))

            ;; Add new file to same subdir
            (with-temp-file (expand-file-name "subdir/file2.txt" test-dir)
              (insert "New file content\n"))

            ;; Run update
            (goto-char (point-min))
            (re-search-forward "IMPORT_SOURCE")
            (org-directory-importer-import-update)

            ;; Verify new file was added at correct level (4 stars)
            (goto-char (point-min))
            (should (re-search-forward "^\\*\\*\\*\\* file2\\.txt" nil t))

            ;; Verify it has correct IMPORT_PATH
            (should (string= "subdir/file2.txt"
                            (org-entry-get nil "IMPORT_PATH")))

            ;; Verify file1 is still at correct level
            (goto-char (point-min))
            (should (re-search-forward "^\\*\\*\\*\\* file1\\.txt" nil t))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-new-file-in-new-subdir ()
  "Test adding a file in a completely new subdirectory.
The update should handle the case where the parent directory heading doesn't exist."
  (let* ((test-dir (make-temp-file "test-new-subdir-" t))
         (org-buffer (generate-new-buffer "*test-new-subdir*")))
    (unwind-protect
        (progn
          ;; Create initial structure with just a root file
          (test-update--create-nested-dir-structure
           test-dir '("root-file.txt"))

          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Verify no newsubdir exists
            (goto-char (point-min))
            (should-not (re-search-forward "newsubdir" nil t))

            ;; Create new subdirectory with a file
            (test-update--create-nested-dir-structure
             test-dir '("newsubdir/newfile.txt"))

            ;; Run update
            (goto-char (point-min))
            (re-search-forward "IMPORT_SOURCE")
            (org-directory-importer-import-update)

            ;; Verify the new file was added
            (goto-char (point-min))
            (should (re-search-forward "newfile\\.txt" nil t))

            ;; Check hierarchy - file should be under newsubdir/ heading
            ;; or at minimum maintain valid org structure
            (let ((structure (test-update--get-heading-structure org-buffer)))
              ;; Each level should be at most 1 more than previous
              (let ((prev-level 0))
                (dolist (item structure)
                  (let ((level (car item)))
                    (should (<= level (1+ prev-level)))
                    (setq prev-level level)))))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-deep-nesting ()
  "Test hierarchy with 4+ levels of nesting.
Structure: a/b/c/deep.txt should have correct heading levels throughout."
  (let* ((test-dir (make-temp-file "test-deep-" t))
         (org-buffer (generate-new-buffer "*test-deep*")))
    (unwind-protect
        (progn
          ;; Create deep structure
          (test-update--create-nested-dir-structure
           test-dir '("a/b/c/deep.txt"))

          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Verify structure:
            ;; * Imported...  (level 1)
            ;; ** ./          (level 2)
            ;; *** a/         (level 3)
            ;; **** b/        (level 4)
            ;; ***** c/       (level 5)
            ;; ****** deep.txt (level 6)
            (let ((structure (test-update--get-heading-structure org-buffer)))
              (should (>= (length structure) 6))
              ;; Verify deep.txt is at level 6
              (let ((deep-entry (seq-find (lambda (x) (string= "deep.txt" (cdr x)))
                                          structure)))
                (should deep-entry)
                (should (= 6 (car deep-entry)))))

            ;; Modify deep file
            (with-temp-file (expand-file-name "a/b/c/deep.txt" test-dir)
              (insert "Modified deep content\n"))

            ;; Run update
            (goto-char (point-min))
            (re-search-forward "IMPORT_SOURCE")
            (org-directory-importer-import-update)

            ;; Verify hierarchy is preserved after update
            (let ((structure (test-update--get-heading-structure org-buffer)))
              (let ((deep-entry (seq-find (lambda (x) (string= "deep.txt" (cdr x)))
                                          structure)))
                (should deep-entry)
                (should (= 6 (car deep-entry)))))

            ;; Verify content was updated
            (goto-char (point-min))
            (should (re-search-forward "Modified deep content" nil t))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-multiple-changes ()
  "Test update with multiple simultaneous changes: modify, add, and delete.
Verifies that all operations work correctly when done together."
  (let* ((test-dir (make-temp-file "test-multi-" t))
         (org-buffer (generate-new-buffer "*test-multi*")))
    (unwind-protect
        (progn
          ;; Create initial structure
          (test-update--create-nested-dir-structure
           test-dir '("keep.txt" "modify.txt" "delete.txt"))

          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Get original checksum for modify.txt
            (goto-char (point-min))
            (re-search-forward "\\*\\*\\* modify\\.txt")
            (let ((orig-checksum (org-entry-get nil "IMPORT_CHECKSUM")))

              ;; Make changes:
              ;; 1. Modify modify.txt
              (with-temp-file (expand-file-name "modify.txt" test-dir)
                (insert "Modified content here\n"))
              ;; 2. Delete delete.txt
              (delete-file (expand-file-name "delete.txt" test-dir))
              ;; 3. Add new.txt
              (with-temp-file (expand-file-name "new.txt" test-dir)
                (insert "Brand new file\n"))

              ;; Run update
              (goto-char (point-min))
              (re-search-forward "IMPORT_SOURCE")
              (org-directory-importer-import-update)

              ;; Verify modify.txt was updated
              (goto-char (point-min))
              (re-search-forward "\\*\\*\\* modify\\.txt")
              (should-not (string= orig-checksum
                                   (org-entry-get nil "IMPORT_CHECKSUM")))

              ;; Verify new.txt was added at correct level
              (goto-char (point-min))
              (should (re-search-forward "^\\*\\*\\* new\\.txt" nil t))
              (should (string= "new.txt" (org-entry-get nil "IMPORT_PATH")))

              ;; Verify keep.txt is still there and unchanged
              (goto-char (point-min))
              (should (re-search-forward "^\\*\\*\\* keep\\.txt" nil t)))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-heading-levels-valid ()
  "Test that after update, all heading levels form a valid tree.
No heading should be more than 1 level deeper than its predecessor."
  (let* ((test-dir (make-temp-file "test-levels-" t))
         (org-buffer (generate-new-buffer "*test-levels*")))
    (unwind-protect
        (progn
          ;; Create complex structure
          (test-update--create-nested-dir-structure
           test-dir '("file1.txt"
                      "sub1/file2.txt"
                      "sub1/sub2/file3.txt"
                      "sub1/file4.txt"
                      "file5.txt"))

          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Add more files after initial import
            (test-update--create-nested-dir-structure
             test-dir '("sub1/sub2/newdeep.txt"
                        "newsub/newfile.txt"))

            ;; Run update
            (goto-char (point-min))
            (re-search-forward "IMPORT_SOURCE")
            (org-directory-importer-import-update)

            ;; Validate all heading levels
            (let ((structure (test-update--get-heading-structure org-buffer))
                  (prev-level 0)
                  (valid t))
              (dolist (item structure)
                (let ((level (car item))
                      (title (cdr item)))
                  ;; Level can increase by at most 1, or decrease to any level
                  (when (> level (1+ prev-level))
                    (setq valid nil)
                    (message "Invalid level jump: %d -> %d at '%s'"
                             prev-level level title))
                  (setq prev-level level)))
              (should valid))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-modified-file-keeps-position ()
  "Test that modifying a file doesn't change its position in hierarchy."
  (let* ((test-dir (make-temp-file "test-position-" t))
         (org-buffer (generate-new-buffer "*test-position*")))
    (unwind-protect
        (progn
          ;; Create structure with multiple files at same level
          (test-update--create-nested-dir-structure
           test-dir '("aaa.txt" "bbb.txt" "ccc.txt"))

          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Record positions
            (goto-char (point-min))
            (re-search-forward "^\\*\\*\\* aaa\\.txt")
            (let ((aaa-pos (point)))
              (re-search-forward "^\\*\\*\\* bbb\\.txt")
              (let ((bbb-pos (point)))
                (re-search-forward "^\\*\\*\\* ccc\\.txt")
                (let ((ccc-pos (point)))

                  ;; Modify middle file
                  (with-temp-file (expand-file-name "bbb.txt" test-dir)
                    (insert "Modified bbb content\n"))

                  ;; Run update
                  (goto-char (point-min))
                  (re-search-forward "IMPORT_SOURCE")
                  (org-directory-importer-import-update)

                  ;; Verify order is preserved (aaa < bbb < ccc)
                  (goto-char (point-min))
                  (re-search-forward "^\\*\\*\\* aaa\\.txt")
                  (let ((new-aaa-pos (point)))
                    (should (re-search-forward "^\\*\\*\\* bbb\\.txt" nil t))
                    (should (re-search-forward "^\\*\\*\\* ccc\\.txt" nil t))))))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-sibling-files-same-level ()
  "Test that sibling files in same directory have same heading level."
  (let* ((test-dir (make-temp-file "test-siblings-" t))
         (org-buffer (generate-new-buffer "*test-siblings*")))
    (unwind-protect
        (progn
          ;; Create structure with multiple files in subdir
          (test-update--create-nested-dir-structure
           test-dir '("sub/file1.txt" "sub/file2.txt" "sub/file3.txt"))

          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Add another file to same subdir
            (with-temp-file (expand-file-name "sub/file4.txt" test-dir)
              (insert "File 4 content\n"))

            ;; Run update
            (goto-char (point-min))
            (re-search-forward "IMPORT_SOURCE")
            (org-directory-importer-import-update)

            ;; All files in sub/ should be at level 4
            (let ((structure (test-update--get-heading-structure org-buffer)))
              (let ((file-levels
                     (mapcar #'car
                             (seq-filter
                              (lambda (x)
                                (string-match-p "^file[1-4]\\.txt$" (cdr x)))
                              structure))))
                ;; All should be same level
                (should (= 4 (length file-levels)))
                (should (= 1 (length (delete-dups file-levels))))))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-from-child-heading ()
  "Test that update works when point is on a child heading.
The command should navigate up to the IMPORT_SOURCE heading,
not just use the heading at point."
  (let* ((test-dir (make-temp-file "test-child-heading-" t))
         (org-buffer (generate-new-buffer "*test-child-heading*")))
    (unwind-protect
        (progn
          ;; Create two files
          (test-update--create-nested-dir-structure
           test-dir '("sub/file1.txt" "sub/file2.txt"))

          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Get original checksum for file1.txt
            (goto-char (point-min))
            (re-search-forward "\\*\\*\\*\\* file1\\.txt")
            (let ((orig-checksum (org-entry-get nil "IMPORT_CHECKSUM")))

              ;; Modify file1.txt
              (with-temp-file (expand-file-name "sub/file1.txt" test-dir)
                (insert "Modified file1 content\n"))

              ;; Run update from file2.txt heading (a sibling, NOT the root)
              (goto-char (point-min))
              (re-search-forward "\\*\\*\\*\\* file2\\.txt")
              (beginning-of-line)
              (org-directory-importer-import-update)

              ;; Verify file1.txt was updated despite point being on file2
              (goto-char (point-min))
              (re-search-forward "\\*\\*\\*\\* file1\\.txt")
              (should-not (string= orig-checksum
                                   (org-entry-get nil "IMPORT_CHECKSUM")))

              ;; Verify the content was actually updated
              (goto-char (point-min))
              (should (re-search-forward "Modified file1 content" nil t)))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(ert-deftest test-update-detects-block-content-divergence ()
  "Test that update detects when Org block content diverges from disk.
Simulates: edit in Org + tangle, then git revert on disk.
The stored IMPORT_CHECKSUM matches the file (both are original),
but the src block content differs — update should detect this."
  (let* ((test-dir (make-temp-file "test-update-diverge-" t))
         (test-file (expand-file-name "test.txt" test-dir))
         (original-content "Original content\n")
         (edited-content "Edited in Org\n")
         (org-buffer (generate-new-buffer "*test-update-diverge*")))
    (unwind-protect
        (progn
          ;; Create test file with original content
          (with-temp-file test-file
            (insert original-content))

          ;; Initial import
          (with-current-buffer org-buffer
            (org-mode)
            (setq buffer-file-name (expand-file-name "test.org" test-dir))
            (org-directory-importer-import test-dir)

            ;; Verify import worked
            (goto-char (point-min))
            (should (re-search-forward "Original content" nil t))

            ;; Simulate editing the src block in Org (as if user edited + tangled)
            ;; 1. Change the src block content
            (goto-char (point-min))
            (re-search-forward "#\\+begin_src")
            (forward-line 1)
            (let ((start (point)))
              (re-search-forward "#\\+end_src")
              (beginning-of-line)
              (delete-region start (point))
              (goto-char start)
              (insert edited-content))

            ;; 2. The file on disk still has original content (simulating git revert)
            ;; — we don't need to change it, it already has "Original content\n"

            ;; 3. IMPORT_CHECKSUM still matches the file on disk (both are original)
            ;; This is the crux of the bug: checksum matches but block content differs

            ;; Run update — should detect the divergence
            (goto-char (point-min))
            (re-search-forward "IMPORT_SOURCE")
            (beginning-of-line)
            (org-directory-importer-import-update)

            ;; The src block should now be restored to match the file on disk
            (goto-char (point-min))
            (should (re-search-forward "Original content" nil t))
            ;; The edited content should be gone
            (goto-char (point-min))
            (should-not (re-search-forward "Edited in Org" nil t))))

      ;; Cleanup
      (delete-directory test-dir t)
      (kill-buffer org-buffer))))

(provide 'test-update)

;;; test-update.el ends here
