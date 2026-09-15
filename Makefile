.PHONY: system format format-changed lint lint-changed build test-unit test-ui gate verify-secrets hooks-install initialize-sims sim-status sim-shutdown sim-clean

system:
	bash scripts/system-setup.sh

# -- Formatting and linting ---------------------------------------------------
# *-changed targets are what `make gate` runs. Repo-wide format/lint are manual
# only — AGENTS.md §"Lint policy".
format:
	swiftformat .

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

# Opt-in, not in the gate. See scripts/test-unit.sh.
test-unit:
	bash scripts/test-unit.sh

test-ui:
	bash scripts/test-ui.sh

# One command so the whole gate is a single allowlisted call; see scripts/gate.sh.
gate:
	bash scripts/gate.sh

# Release ship guard. Fails if config/Secrets.local.xcconfig is missing or the Mixpanel
# prod token is still the committed placeholder. Not part of make gate: a fresh clone
# has no local secrets file.
verify-secrets:
	bash scripts/verify_release_secrets.sh

hooks-install:
	lefthook install

initialize-sims:
	@ROOT="$(CURDIR)" bash -c 'source "$(CURDIR)/scripts/_sim_sandbox.sh"'

# Scoped to the UDID in .build/sim/device.udid only.

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
