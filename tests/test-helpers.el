;;; test-helpers.el --- ERT tests for internal helper functions -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; This file is part of org-directory-importer.

;;; Commentary:

;; Tests for internal helper functions:
;; - `org-directory-importer-clear-gitignore-cache'
;; - `org-directory-importer--find-subheading'
;; - `org-directory-importer--validate-import-preconditions'

;;; Code:

(require 'ert)
(require 'org-directory-importer)

;;; --- clear-gitignore-cache ---

(ert-deftest test-clear-gitignore-cache-resets-to-nil ()
  "Clearing the cache should set it to nil."
  (let ((org-directory-importer--gitignore-cache '(("/tmp" . ("*.log")))))
    (org-directory-importer-clear-gitignore-cache)
    (should (null org-directory-importer--gitignore-cache))))

(ert-deftest test-clear-gitignore-cache-when-already-nil ()
  "Clearing an already-nil cache should succeed without error."
  (let ((org-directory-importer--gitignore-cache nil))
    (org-directory-importer-clear-gitignore-cache)
    (should (null org-directory-importer--gitignore-cache))))

;;; --- find-subheading ---

(ert-deftest test-find-subheading-finds-direct-child ()
  "Should find a direct child heading by name."
  (with-temp-buffer
    (org-mode)
    (insert "* Parent\n** src/\n** docs/\n")
    (goto-char (point-min))
    (should (org-directory-importer--find-subheading "src"))))

(ert-deftest test-find-subheading-returns-nil-for-missing ()
  "Should return nil when child heading does not exist."
  (with-temp-buffer
    (org-mode)
    (insert "* Parent\n** src/\n** docs/\n")
    (goto-char (point-min))
    (should-not (org-directory-importer--find-subheading "nonexistent"))))

(ert-deftest test-find-subheading-restores-point-on-miss ()
  "Point should be restored to original position when heading not found."
  (with-temp-buffer
    (org-mode)
    (insert "* Parent\n** src/\n** docs/\n")
    (goto-char (point-min))
    (let ((original-pos (point)))
      (org-directory-importer--find-subheading "nonexistent")
      (should (= (point) original-pos)))))

(ert-deftest test-find-subheading-with-trailing-slash ()
  "Should find heading when search name already has trailing slash."
  (with-temp-buffer
    (org-mode)
    (insert "* Parent\n** src/\n")
    (goto-char (point-min))
    (should (org-directory-importer--find-subheading "src/"))))

(ert-deftest test-find-subheading-no-children ()
  "Should return nil when parent heading has no children."
  (with-temp-buffer
    (org-mode)
    (insert "* Parent\n")
    (goto-char (point-min))
    (should-not (org-directory-importer--find-subheading "src"))))

(ert-deftest test-find-subheading-skips-deeper-descendants ()
  "Should only search direct children, not deeper descendants."
  (with-temp-buffer
    (org-mode)
    (insert "* Parent\n** child/\n*** deep/\n")
    (goto-char (point-min))
    ;; "deep" is a grandchild, should not be found as direct child
    (should-not (org-directory-importer--find-subheading "deep"))))

;;; --- validate-import-preconditions ---

(ert-deftest test-validate-preconditions-not-a-directory ()
  "Should error when path is not a directory."
  (let ((tmp-file (make-temp-file "test-validate")))
    (unwind-protect
        (should-error
         (org-directory-importer--validate-import-preconditions tmp-file)
         :type 'user-error)
      (delete-file tmp-file))))

(ert-deftest test-validate-preconditions-not-org-mode ()
  "Should error when buffer is not in Org mode."
  (let ((tmp-dir (make-temp-file "test-validate" t)))
    (unwind-protect
        (with-temp-buffer
          (fundamental-mode)
          (should-error
           (org-directory-importer--validate-import-preconditions tmp-dir)
           :type 'user-error))
      (delete-directory tmp-dir))))

(ert-deftest test-validate-preconditions-passes-valid ()
  "Should not error with valid directory and Org-mode buffer."
  (let ((tmp-dir (make-temp-file "test-validate" t)))
    (unwind-protect
        (with-temp-buffer
          (org-mode)
          (let ((org-directory-importer-tangle-path-type 'absolute))
            (org-directory-importer--validate-import-preconditions tmp-dir)))
      (delete-directory tmp-dir))))

;;; --- transient menus ---

(ert-deftest test-transient-menu-defined ()
  "Main transient menu should be defined."
  (should (fboundp 'org-directory-importer-menu)))

(ert-deftest test-transient-import-menu-defined ()
  "Import transient menu should be defined."
  (should (fboundp 'org-directory-importer-import-menu)))

(ert-deftest test-transient-manage-menu-defined ()
  "Manage transient menu should be defined."
  (should (fboundp 'org-directory-importer-manage-menu)))

;;; --- minor mode ---

(ert-deftest test-minor-mode-activates-in-org ()
  "Minor mode should activate in Org-mode buffers."
  (with-temp-buffer
    (org-mode)
    (org-directory-importer-mode 1)
    (should org-directory-importer-mode)))

(ert-deftest test-minor-mode-rejects-non-org ()
  "Minor mode should reject activation outside Org-mode."
  (with-temp-buffer
    (fundamental-mode)
    (should-error
     (org-directory-importer-mode 1)
     :type 'user-error)))

(ert-deftest test-minor-mode-deactivates ()
  "Minor mode should deactivate cleanly."
  (with-temp-buffer
    (org-mode)
    (org-directory-importer-mode 1)
    (org-directory-importer-mode -1)
    (should-not org-directory-importer-mode)))

(ert-deftest test-minor-mode-keymap-has-binding ()
  "Minor mode keymap should have C-c C-M-i bound."
  (should (eq (lookup-key org-directory-importer-mode-map (kbd "C-c C-M-i"))
              'org-directory-importer-menu)))

(provide 'test-helpers)
;;; test-helpers.el ends here
