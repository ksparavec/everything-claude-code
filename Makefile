# Makefile for everything-claude-code manual installation
# Installs agents, commands, rules, and skills to ~/.claude
# Only installs files that are newer than the installed version

SHELL := /bin/bash
CLAUDE_DIR := $(HOME)/.claude
SRC_DIR := $(shell pwd)

# Source directories
AGENTS_SRC := $(SRC_DIR)/agents
COMMANDS_SRC := $(SRC_DIR)/commands
RULES_SRC := $(SRC_DIR)/rules
SKILLS_SRC := $(SRC_DIR)/skills

# Destination directories
AGENTS_DEST := $(CLAUDE_DIR)/agents
COMMANDS_DEST := $(CLAUDE_DIR)/commands
RULES_DEST := $(CLAUDE_DIR)/rules
SKILLS_DEST := $(CLAUDE_DIR)/skills

# File-based targets (only run if target doesn't exist)
GITIGNORE := $(CLAUDE_DIR)/.gitignore
GITDIR := $(CLAUDE_DIR)/.git

# Rsync options: archive mode, only update newer files
RSYNC_OPTS := -a --itemize-changes

.PHONY: all install install-agents install-commands install-rules install-skills \
        commit-changes clean help

# Default target
all: install

# Full installation
install: $(GITDIR) install-agents install-commands install-rules install-skills commit-changes

# Initialize git repo in ~/.claude (only if .git doesn't exist)
$(GITDIR): $(GITIGNORE)
	@printf "Initializing git repository in $(CLAUDE_DIR)... "
	@cd $(CLAUDE_DIR) && git init -q && echo "done."

# Initialize .gitignore in ~/.claude (only if doesn't exist)
$(GITIGNORE):
	@mkdir -p $(CLAUDE_DIR)
	@printf "Creating .gitignore in $(CLAUDE_DIR)... "
	@printf '%s\n' \
		'cache/' \
		'debug/' \
		'file-history/' \
		'paste-cache/' \
		'plugins/' \
		'projects/' \
		'session-env/' \
		'statsig/' \
		'todos/' \
		'history.jsonl' \
		'stats-cache.json' \
		'shell-snapshots/' \
		'.credentials.json' \
		> "$@" && echo "done."

# Install agents
install-agents: $(GITDIR)
	@mkdir -p $(AGENTS_DEST)
	@OUTPUT=$$(rsync $(RSYNC_OPTS) $(AGENTS_SRC)/ $(AGENTS_DEST)/); \
	NEW=$$(echo "$$OUTPUT" | grep -c '^>f+++' || true); \
	UPD=$$(echo "$$OUTPUT" | grep '^>f' | grep -cv '^>f+++' || true); \
	echo "agents: $$NEW new, $$UPD updated"

# Install commands
install-commands: $(GITDIR)
	@mkdir -p $(COMMANDS_DEST)
	@OUTPUT=$$(rsync $(RSYNC_OPTS) $(COMMANDS_SRC)/ $(COMMANDS_DEST)/); \
	NEW=$$(echo "$$OUTPUT" | grep -c '^>f+++' || true); \
	UPD=$$(echo "$$OUTPUT" | grep '^>f' | grep -cv '^>f+++' || true); \
	echo "commands: $$NEW new, $$UPD updated"

# Install rules
install-rules: $(GITDIR)
	@mkdir -p $(RULES_DEST)
	@OUTPUT=$$(rsync $(RSYNC_OPTS) $(RULES_SRC)/ $(RULES_DEST)/); \
	NEW=$$(echo "$$OUTPUT" | grep -c '^>f+++' || true); \
	UPD=$$(echo "$$OUTPUT" | grep '^>f' | grep -cv '^>f+++' || true); \
	echo "rules: $$NEW new, $$UPD updated"

# Install skills
install-skills: $(GITDIR)
	@mkdir -p $(SKILLS_DEST)
	@OUTPUT=$$(rsync $(RSYNC_OPTS) $(SKILLS_SRC)/ $(SKILLS_DEST)/); \
	NEW=$$(echo "$$OUTPUT" | grep -c '^>f+++' || true); \
	UPD=$$(echo "$$OUTPUT" | grep '^>f' | grep -cv '^>f+++' || true); \
	echo "skills: $$NEW new, $$UPD updated"

# Commit changes with detailed message listing each file
commit-changes:
	@cd $(CLAUDE_DIR) && \
	if [ -n "$$(git status --porcelain)" ]; then \
		printf "Committing changes in $(CLAUDE_DIR)... "; \
		git add -A; \
		ADDED=$$(git diff --cached --name-only --diff-filter=A); \
		MODIFIED=$$(git diff --cached --name-only --diff-filter=M); \
		DELETED=$$(git diff --cached --name-only --diff-filter=D); \
		ADDED_COUNT=0; [ -n "$$ADDED" ] && ADDED_COUNT=$$(echo "$$ADDED" | wc -l); \
		MODIFIED_COUNT=0; [ -n "$$MODIFIED" ] && MODIFIED_COUNT=$$(echo "$$MODIFIED" | wc -l); \
		DELETED_COUNT=0; [ -n "$$DELETED" ] && DELETED_COUNT=$$(echo "$$DELETED" | wc -l); \
		SUMMARY=""; \
		[ "$$ADDED_COUNT" -gt 0 ] && SUMMARY="$$SUMMARY +$$ADDED_COUNT"; \
		[ "$$MODIFIED_COUNT" -gt 0 ] && SUMMARY="$$SUMMARY ~$$MODIFIED_COUNT"; \
		[ "$$DELETED_COUNT" -gt 0 ] && SUMMARY="$$SUMMARY -$$DELETED_COUNT"; \
		MSG="Update from everything-claude-code ($$SUMMARY )"; \
		if [ -n "$$ADDED" ]; then \
			MSG="$$MSG\n\nNew files:"; \
			while IFS= read -r f; do \
				[ -n "$$f" ] && MSG="$$MSG\n  + $$f"; \
			done <<< "$$ADDED"; \
		fi; \
		if [ -n "$$MODIFIED" ]; then \
			MSG="$$MSG\n\nModified files:"; \
			while IFS= read -r f; do \
				[ -n "$$f" ] && MSG="$$MSG\n  ~ $$f"; \
			done <<< "$$MODIFIED"; \
		fi; \
		if [ -n "$$DELETED" ]; then \
			MSG="$$MSG\n\nDeleted files:"; \
			while IFS= read -r f; do \
				[ -n "$$f" ] && MSG="$$MSG\n  - $$f"; \
			done <<< "$$DELETED"; \
		fi; \
		echo -e "$$MSG" | git commit -q -F -; \
		echo "done."; \
	else \
		echo "No changes to commit."; \
	fi

# Clean local build artifacts (if any)
clean:
	@echo "Nothing to clean."

# Help target
help:
	@echo "everything-claude-code Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  install          Install all components (agents, commands, rules, skills)"
	@echo "  install-agents   Install agents only"
	@echo "  install-commands Install commands only"
	@echo "  install-rules    Install rules only"
	@echo "  install-skills   Install skills only"
	@echo "  help             Show this help message"
	@echo ""
	@echo "Only files newer than installed versions are copied."
	@echo "Changes are auto-committed with detailed file listing."
