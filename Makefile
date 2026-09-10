.PHONY: system format format-check format-changed lint lint-changed build test-unit test-ui gate verify-secrets hooks-install initialize-sims sim-status sim-shutdown sim-clean

system:
	bash scripts/system-setup.sh

# -- Formatting and linting ---------------------------------------------------
# The *-changed targets are what `make gate` runs: they touch only the Swift files
# this branch changed. The repo-wide targets below are deliberate manual escape
# hatches — this tree carries ~96 pre-existing SwiftLint violations and 30/31 files
# needing reformat, so running them repo-wide rewrites the whole codebase.
# See scripts/changed-swift-files.sh.

# Repo-wide rewrite. Manual only — NOT part of the gate.
format:
	swiftformat .

# Repo-wide check-only (no rewrite). Manual only — NOT part of the gate.
format-check:
	swiftformat --lint .

# Repo-wide strict lint. Manual only — NOT part of the gate. Expect ~96 violations
# on the untouched legacy tree; this target is for tracking that number down over time.
lint:
	swiftlint lint --strict

# Rewrite only the Swift files this branch changed.
format-changed:
	@files=$$(bash scripts/changed-swift-files.sh); \
	if [ -z "$$files" ]; then echo "format-changed: no changed Swift files"; else \
	  echo "$$files" | tr '\n' ' ' | xargs swiftformat; fi

# Autocorrect then strict-lint only the Swift files this branch changed.
lint-changed:
	@files=$$(bash scripts/changed-swift-files.sh); \
	if [ -z "$$files" ]; then echo "lint-changed: no changed Swift files"; else \
	  echo "$$files" | tr '\n' ' ' | xargs swiftlint --fix --quiet && \
	  echo "$$files" | tr '\n' ' ' | xargs swiftlint lint --strict --quiet; fi

# -- Build and test -----------------------------------------------------------
build:
	bash scripts/build.sh

# Tests are OPT-IN and not part of the gate. Runs against disposable in-memory
# ModelContainers (see checklistsTests/Helpers/TestModelContainer.swift); nothing here
# touches the simulator's real on-disk store. See scripts/test-unit.sh.
test-unit:
	bash scripts/test-unit.sh

test-ui:
	bash scripts/test-ui.sh

# Full gate (format-changed -> lint-changed -> build) in one command, logged to
# tmp/gate.log, stopping at the first failure. See scripts/gate.sh for why this
# single-command form exists (avoids the subshell/`; echo` permission prompt).
gate:
	bash scripts/gate.sh

# Release ship guard. Fails if config/Secrets.local.xcconfig is missing or the Mixpanel
# prod token is still the committed placeholder. Run this before archiving for TestFlight
# or the App Store — Fastlane currently provides read-only ASC tools; CI is disabled.
# Deliberately NOT part of `make gate`: a fresh clone has no local secrets file.
verify-secrets:
	bash scripts/verify_release_secrets.sh

hooks-install:
	lefthook install

initialize-sims:
	@ROOT="$(CURDIR)" bash -c 'source "$(CURDIR)/scripts/_sim_sandbox.sh"'

# -- Scoped simulator management (affects only this repo's device) --
# These targets operate on the single UDID stored in .build/sim/device.udid.
# Never use `pkill Simulator`, `killall Simulator`, or bare `simctl shutdown/erase all`
# — those commands affect every simulator on the machine.

_UDID_FILE := $(CURDIR)/.build/sim/device.udid

sim-status:
	@if [ -f "$(_UDID_FILE)" ]; then \
		udid=$$(cat "$(_UDID_FILE)"); \
		xcrun simctl list devices | grep "$$udid" || echo "(device $$udid not found in default set)"; \
	else \
		echo "(not initialized — run make initialize-sims)"; \
	fi

sim-shutdown:
	@if [ -f "$(_UDID_FILE)" ]; then \
		udid=$$(cat "$(_UDID_FILE)"); \
		xcrun simctl shutdown "$$udid" 2>/dev/null \
			&& echo "sim-sandbox: simulator $$udid shut down" \
			|| echo "sim-sandbox: simulator $$udid already shut down or not found"; \
	else \
		echo "sim-sandbox: not initialized"; \
	fi

sim-clean:
	@python3 scripts/sim_clean.py --slug-from-file "$(_UDID_FILE)" || true
	rm -rf .build/sim
	@echo "sim-sandbox: .build/sim removed"
