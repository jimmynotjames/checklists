.PHONY: system tool-versions-check format format-changed lint lint-changed i18n-check i18n-sync i18n-sync-check uitest-check doc-check build test-unit test-ui test-only test-scripts gate verify-secrets hooks-install initialize-sims sim-udid sim-show sim-run sim-status sim-shutdown sim-clean simulator-slots-check simulator-slots-sync simulator-slots-status

system:
	bash scripts/system-setup.sh

# -- Formatting and linting ---------------------------------------------------
# *-changed targets are what `make gate` runs. Repo-wide format/lint are manual
# only — AGENTS.md §"Lint policy".
tool-versions-check:
	bash scripts/check-tool-versions.sh

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

# -- Localization -------------------------------------------------------------
# Repo-wide on purpose, and the documented exception to AGENTS.md §"Lint policy":
# check_translations validates the catalog, check_source_strings enforces a repo
# invariant (no unkeyed user-facing copy), distinct_pairs catches paired strings
# translated identically, and untranslated_copies catches English left in a translated
# slot. None is a style lint of Swift files; all take under a second.
i18n-check:
	python3 scripts/check_translations.py
	python3 scripts/check_source_strings.py
	python3 scripts/translate_audit/distinct_pairs.py
	python3 scripts/translate_audit/untranslated_copies.py

# Merge the last `make build`'s extracted strings into the catalog, as a build in Xcode does:
# Swift `comment:` changes, new keys, and `stale` for keys gone from Swift. Needs that build.
i18n-sync:
	python3 scripts/translate_catalog/sync_catalog.py

# The gate's form: fails when i18n-sync would change the catalog.
i18n-sync-check:
	python3 scripts/translate_catalog/sync_catalog.py --check

# Static checks; the UI tests themselves are opt-in (AGENTS.md §"Build and test").
uitest-check:
	python3 scripts/check_ui_test_keyboard.py
	python3 scripts/screenshot_content/generate_seeds.py --check

# Repo-wide except its added-lines history scan; see scripts/check_doc_pointers.py.
doc-check:
	python3 scripts/check_doc_pointers.py

# -- Build and test -----------------------------------------------------------
build:
	bash scripts/build.sh

# Opt-in: AGENTS.md §"Build and test".
test-unit:
	bash scripts/test-unit.sh

test-ui:
	bash scripts/test-ui.sh

# make test-only ONLY=<target>/<Class>[/<test>] [ITERATIONS=3]
test-only:
	bash scripts/test-only.sh "$(ONLY)" $(ITERATIONS)

test-scripts:
	bash scripts/test-scripts.sh

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
	@bash scripts/sim.sh init

sim-udid:
	@bash scripts/sim.sh udid

sim-show:
	@bash scripts/sim.sh show

sim-run:
	@bash scripts/sim.sh run

sim-status:
	@bash scripts/sim.sh status

sim-shutdown:
	@bash scripts/sim.sh shutdown

sim-clean:
	@bash scripts/sim.sh clean

# -- Simulator slots ----------------------------------------------------------
# The machine-wide pool lives in ~/dev/simulator-slots; scripts/simulator-slots is this repo's
# copy (AGENTS.md §"Simulator slots").
simulator-slots-check:
	python3 scripts/simulator-slots/simulator_slots.py sync-check --into scripts/simulator-slots

simulator-slots-sync:
	python3 scripts/simulator-slots/simulator_slots.py sync --into scripts/simulator-slots

simulator-slots-status:
	@python3 scripts/simulator-slots/simulator_slots.py status
