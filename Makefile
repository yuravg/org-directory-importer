.PHONY: help test test-all test-interactive test-gitignore test-binary test-language \
        test-roundtrip test-edge-cases test-update test-import-file test-refresh-block compile lint checkdoc ci clean

.DEFAULT_GOAL := help

# Package information
PACKAGE := org-directory-importer.el
VERSION := $(shell perl -ne 'if (/^;;\s*Version:\s*(\S+)/) {print $$1; last}' $(PACKAGE))
TEST_COUNT := $(shell grep -ch 'ert-deftest' tests/*.el 2>/dev/null | awk '{s+=$$1} END{print s+0}')
TEST_FILES := tests/test-gitignore.el \
              tests/test-binary-detection.el \
              tests/test-language-detection.el \
              tests/test-roundtrip.el \
              tests/test-edge-cases.el \
              tests/test-update.el \
              tests/test-import-file.el \
              tests/test-refresh-block.el

# Count ert-deftest forms in a test file
# Usage: $(call test-count,tests/test-foo.el)
test-count = $$(grep -c 'ert-deftest' $(1))

# Emacs command
EMACS ?= emacs
BATCH := $(EMACS) -batch
BATCH_ERT_PKG := $(EMACS) -batch -l ert -l $(PACKAGE)

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------

help:
	@echo "org-directory-importer v$(VERSION) - Makefile targets"
	@echo ""
	@printf "Testing: (%s tests total)\n" "$(TEST_COUNT)"
	@echo "  make test              Run all tests via test-suite.el (fast)"
	@echo "  make test-all          Run all individual test files (verbose)"
	@echo "  make test-interactive  Run tests in interactive Emacs"
	@echo ""
	@echo "Individual test files:"
	@printf "  make %-18s Run %-28s (%s tests)\n" \
	  "test-gitignore"     "gitignore pattern tests"       "$(call test-count,tests/test-gitignore.el)" \
	  "test-binary"        "binary detection tests"        "$(call test-count,tests/test-binary-detection.el)" \
	  "test-language"      "language mapping tests"         "$(call test-count,tests/test-language-detection.el)" \
	  "test-roundtrip"     "import/tangle roundtrip test"   "$(call test-count,tests/test-roundtrip.el)" \
	  "test-edge-cases"    "edge case tests"               "$(call test-count,tests/test-edge-cases.el)" \
	  "test-update"        "incremental update tests"      "$(call test-count,tests/test-update.el)" \
	  "test-import-file"   "single file import tests"      "$(call test-count,tests/test-import-file.el)" \
	  "test-refresh-block" "refresh-block tests"           "$(call test-count,tests/test-refresh-block.el)"
	@echo ""
	@echo "Quality checks:"
	@echo "  make compile           Byte-compile the package"
	@echo "  make lint              Run package-lint checks"
	@echo "  make checkdoc          Check documentation strings"
	@echo ""
	@echo "CI/CD:"
	@echo "  make ci                Run all checks (compile + lint + checkdoc + test)"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean             Remove byte-compiled files"
	@echo ""

help1:
	@echo "TEST_COUNT = $(TEST_COUNT)"

#------------------------------------------------------------------------------
# Testing
#------------------------------------------------------------------------------

# Run all tests via test-suite.el (fastest method)
test:
	@echo "Running all tests via test-suite.el..."
	@$(BATCH) -l ert -l tests/test-suite.el

# Run all individual test files (more verbose output)
test-all: test-gitignore test-binary test-language test-roundtrip test-edge-cases test-update test-import-file test-refresh-block
	@echo ""
	@echo "✓ All test suites passed!"

# Individual test targets
test-gitignore:
	@echo "Running gitignore tests..."
	@$(BATCH_ERT_PKG) -l tests/test-gitignore.el -f ert-run-tests-batch-and-exit

test-binary:
	@echo "Running binary detection tests..."
	@$(BATCH_ERT_PKG) -l tests/test-binary-detection.el -f ert-run-tests-batch-and-exit

test-language:
	@echo "Running language detection tests..."
	@$(BATCH_ERT_PKG) -l tests/test-language-detection.el -f ert-run-tests-batch-and-exit

test-roundtrip:
	@echo "Running roundtrip tests..."
	@$(BATCH_ERT_PKG) -l tests/test-roundtrip.el -f ert-run-tests-batch-and-exit

test-edge-cases:
	@echo "Running edge case tests..."
	@$(BATCH_ERT_PKG) -l tests/test-edge-cases.el -f ert-run-tests-batch-and-exit

test-update:
	@echo "Running update tests..."
	@$(BATCH_ERT_PKG) -l tests/test-update.el -f ert-run-tests-batch-and-exit

test-import-file:
	@echo "Running import-file tests..."
	@$(BATCH_ERT_PKG) -l tests/test-import-file.el -f ert-run-tests-batch-and-exit

test-refresh-block:
	@echo "Running refresh-block tests..."
	@$(BATCH_ERT_PKG) -l tests/test-refresh-block.el -f ert-run-tests-batch-and-exit

# Run tests interactively in Emacs
test-interactive:
	@echo "Starting interactive test session..."
	@$(EMACS) -l tests/test-suite.el

#------------------------------------------------------------------------------
# Quality Checks
#------------------------------------------------------------------------------

# Byte-compile the package
compile:
	@echo "Byte-compiling $(PACKAGE)..."
	@$(BATCH) -f batch-byte-compile $(PACKAGE)
	@echo "✓ Compilation successful"

# Run package-lint checks
lint:
	@echo "Running package-lint checks..."
	@$(BATCH) \
	  --eval "(require 'package)" \
	  --eval "(push '(\"melpa\" . \"https://melpa.org/packages/\") package-archives)" \
	  --eval "(package-initialize)" \
	  --eval "(unless (package-installed-p 'package-lint) \
	            (package-refresh-contents) \
	            (package-install 'package-lint))" \
	  --eval "(require 'package-lint)" \
	  -f package-lint-batch-and-exit $(PACKAGE)

# Check documentation strings
checkdoc:
	@echo "Running checkdoc..."
	@$(BATCH) --eval "\
	(progn \
	  (require 'checkdoc) \
	  (let ((checkdoc-diagnostic-buffer \"*chk*\")) \
	    (checkdoc-file \"$(PACKAGE)\") \
	    (when (get-buffer \"*chk*\") \
	      (with-current-buffer \"*chk*\" \
	        (unless (zerop (buffer-size)) \
	          (message \"%s\" (buffer-string)) \
	          (kill-emacs 1))))))"

#------------------------------------------------------------------------------
# CI/CD
#------------------------------------------------------------------------------

# Run all quality checks (suitable for CI)
ci: clean compile lint checkdoc test
	@echo ""
	@echo "✓ All CI checks passed!"
	@echo "  - Byte compilation: OK"
	@echo "  - Documentation: OK"
	@echo "  - Tests: $(TEST_COUNT)/$(TEST_COUNT) passing"

#------------------------------------------------------------------------------
# Maintenance
#------------------------------------------------------------------------------

# Clean byte-compiled files
clean:
	@echo "Cleaning byte-compiled files..."
	@find . -name "*.elc" -delete
	@echo "✓ Clean complete"
