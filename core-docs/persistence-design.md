# Persistence

**Status: SwiftData, local-only.** The app persists with SwiftData as of the Realm→SwiftData
migration (Stage 1). CloudKit sync is designed for but switched off (`ProductionContainerFactory.cloudKitEnabled = false`) — turning it on is Stage 2, a separate change.

This document is canonical for the data model, the constraints it was designed against, the
one-time legacy import, sort-key ordering, and the startup/failure UX. The sibling
[`analytics-design.md`](analytics-design.md) is canonical for analytics; this file does not repeat
it.

## Model

Two `@Model` types, both in `checklists/checklists/DataModels/`:

- **`Checklist`** (`Checklist.swift`) — `id`, `name`, `notes`, `sortKey`, and `itemsStorage`, the
  `@Relationship(deleteRule: .cascade, inverse: \Item.checklist)` to its items. App code never reads
  `itemsStorage` directly; the `items` computed property re-sorts it by `sortKey` (falling back to
  `id` to keep ties total and stable) on every read, because a to-many relationship is an unordered
  set as far as CloudKit is concerned.
- **`Item`** (`Item.swift`) — `id`, `name`, `notes`, `sortKey`, `statusRaw` (an `Int`; `status` is a
  computed `Item.Status` wrapper so it stays filterable in a `#Predicate` and legible in the
  CloudKit dashboard), and `checklist`, the inverse of `itemsStorage`.

Both are declared under `SchemaV1` (`DataModels/SchemaV1.swift`) and registered with
`ChecklistsMigrationPlan` (`DataModels/ChecklistsMigrationPlan.swift`), whose `stages` array is
empty today — `SchemaV1` is the first SwiftData schema, so there is nothing to migrate *from*
within SwiftData yet. See "CloudKit rules" below for what changing either model now costs.

### What the old Realm schema had that these don't

- **`Group`** — a singleton object that existed only to hold checklists in an ordered `List` (see
  `checklists/checklists/DataModels/LegacyRealmSchema.swift` for the schema it shipped). A singleton
  is exactly the shape CloudKit cannot express: two devices that each create their "one" `Group`
  before their first sync end up with two of them and no principled way to pick a winner. Dropped
  entirely — ordering now lives on each record via `sortKey` (see "Sort keys" below).
- **`sortNumber`** — the old array-index-shaped ordering field `Group.checklists`/`Checklist.items`
  made redundant once ordering moved off the collection and onto the record.
- **`lastModified`** — present on the Realm schema, never read anywhere in the app. Not carried
  forward; nothing depended on it.

## CloudKit rules

`SchemaV1` is written to already satisfy CloudKit's constraints on a `ModelConfiguration`, even
though CloudKit sync itself is off in this stage. Turning it on later should require no schema
change:

- **No unique constraints** (`@Attribute(.unique)`) anywhere. CloudKit has no way to enforce
  uniqueness across devices that write while offline, so a unique attribute in SwiftData's schema
  makes `ModelContainer` creation with a CloudKit configuration throw outright.
- **Every relationship is optional, with an explicit inverse.** `Checklist.itemsStorage` and
  `Item.checklist` are both optional `@Relationship` properties. CloudKit syncs a record graph in
  pieces, so a child record can legitimately arrive before its parent (or vice versa); a
  non-optional relationship would be unsatisfiable during that window.
- **Every non-optional attribute has a default value** (`= ""`, `= UUID().uuidString`, `= 0.0`, …).
  CloudKit record decoding fills in the default rather than failing when a field is briefly absent.
- **No ordered relationships** — CloudKit relationships are unordered sets, full stop. Hence
  `sortKey` instead of relying on array position; see "Sort keys" below.
- **No `.deny` delete rule.** `Checklist.itemsStorage` uses `.cascade`; a `.deny` rule can leave a
  parent record permanently undeletable if a sync merge lands a child CloudKit has not told this
  device to delete yet.
- **The production CloudKit schema is additive-only once deployed.** A record type or field that has
  reached production can never be removed or renamed — only added to. From that point on, any model
  change is a new `VersionedSchema` (`SchemaV2`, …) plus a `MigrationStage` in
  `ChecklistsMigrationPlan.stages` plus a migration test, never an edit to `SchemaV1` in place. See
  the doc comment atop `DataModels/SchemaV1.swift`, and the "SwiftData schema migration"
  cross-cutting check in `.claude/skills/create-pr/SKILL.md`.

## Legacy import

`Persistence/LegacyRealmImporter.swift` copies a pre-migration install's Realm store into SwiftData
**once**, and is not itself a `SchemaMigrationPlan` stage — that mechanism moves data between two
versions of *one* SwiftData schema, while this moves data between two entirely different persistence
frameworks.

Three properties hold, in priority order (see the type's own doc comment for the full reasoning):

1. **It never loses data.** The Realm file is never deleted by this release, here or anywhere else.
   If anything fails, the original store is untouched and the import simply runs again next launch.
2. **It is idempotent.** Records are upserted by their existing `id` (`upsert(_:into:)`), so a rerun
   after a crash or a failed flag write adds nothing and changes nothing.
3. **It verifies before declaring success.** `verify(_:in:)` reads every copied checklist and item
   back out of SwiftData before `LegacyRealmImporter.completedFlagKey` is set. A partial import
   leaves the flag unset and is retried, rather than being silently accepted as complete.

Checklist order comes from the old `LegacyGroup.checklists` `List`, since that was the only record of
display order in the Realm schema; any checklist reachable in the store but not linked from the
`Group` (which should not happen, but would be invisible and unrecoverable if dropped) is appended
at the end rather than discarded. A store with no `Group` object at all — predating v1.1.0, which
shipped the `Group` object in 2021 — imports nothing but still completes normally; upgrading from
that old a build is out of scope by decision.

**The Realm file is retained this release and deleted in v1.3.** Because it's a plain file, deleting
it needs no Realm API at all — a future change removes it with `FileManager.default.removeItem(at:)`
once enough of the install base has had a release cycle to complete its one-time import. See "Realm
removal plan" below for what comes after that.

## Sort keys

`Persistence/SortKeyReorder.swift` holds the ordering arithmetic, kept as pure functions
independent of SwiftData so it can be tested without a container (`SortKeyReorderTests`).

CloudKit relationships are unordered sets (see "CloudKit rules"), so "the order the user last
arranged things in" has to be stored as data on each record rather than inferred from array
position — `Checklist.sortKey` and `Item.sortKey`, both `Double`s, ascending.

**Midpoint insertion, not renumbering.** Moving or inserting a record assigns it the key exactly
between its two new neighbours (`SortKeyReorder.key(forInsertingAt:in:)`), so a reorder rewrites the
one record that moved rather than renumbering everyone after it. That matters once sync is on: a
renumber would turn every reorder into a diff across the whole list instead of one changed record.
The cost is that repeated insertions at the same spot keep halving the available gap; once a gap
shrinks below `SortKeyReorder.epsilon` (`1e-6`), the key function returns `nil` and the caller
(`Persistence/Reordering.swift`) renormalizes the whole list back to evenly spaced integers
(`1, 2, 3, …`, via `SortKeyReorder.renormalize`) and asks again — always splittable immediately
afterwards, since a fresh `step`-sized (`1.0`) gap is not exhausted.

**Why not array indices**, which would be simpler: an index is a property of the collection, and
CloudKit's relationships don't preserve collection order at all — see "No ordered relationships"
above. A `sortKey` field is just another synced attribute, so it survives the trip through CloudKit
the way an implicit array position cannot.

## Startup and failure UX

`Persistence/AppStartupCoordinator.swift` owns everything between process start and the first
screen having data: opening the store, running the legacy import, seeding a brand-new install. It's
kept out of `SceneDelegate` so the whole sequence is one testable, retryable unit rather than
scattered init-time side effects.

**Coordinator order**, inside `AppStartupCoordinator.run()`:

1. Build the `ModelContainer` (`LaunchModeContainerFactory.make`, defaulting to
   `ProductionContainerFactory.make` outside of tests — see below).
2. `LegacyRealmImporter.importIfNeeded(into:)`.
3. `SampleData.insertFirstTimeLaunchDataIfNeeded(into:)` — a no-op if the import (or a prior launch)
   already populated the store.
4. Install the result as `PersistenceController.shared`.

Steps 2–3 are skipped entirely under `LaunchModeContainerFactory.isRunningTests` — automated tests
get an already-seeded in-memory container (`InMemoryModelContainer.makeSeeded()`), where running the
Realm importer would be both wrong (there is no Realm file) and slow.

**The migration screen appears only on the launch that actually imports.** `SceneDelegate.scene(_:willConnectTo:options:)`
checks `AppStartupCoordinator.willImportLegacyData` *before* running startup, and only then puts
`LoadingViewController` up as the root view controller while `AppStartupCoordinator` runs on a
background `Task`. Every other launch — which is almost all of them, since the import runs at most
once per device — goes straight to the checklist list exactly as before.

**The screen has a 1.5-second floor** (`SceneDelegate.minimumMigrationScreenDuration`). The copy
itself takes a small fraction of that for any realistic amount of data, so without a floor the
screen would flash by unread; the floor exists purely so a user who is about to see the app's
launch experience change (and, once Stage 2 ships, learn that iCloud sync is now in play) actually
gets to read the message.

**A retryable failure screen, never `fatalError`.** If container creation, the legacy import, or the
first-launch seed throws, `AppStartupCoordinator.run()` returns `.failed(ContainerCreationFailure)`
instead of propagating the error, and `SceneDelegate` shows `ContainerFailureViewController` with a
Retry button wired back to `AppStartupCoordinator().run()`. Nothing has been deleted at that point —
in particular the Realm file, per "Legacy import" above — so retrying is a real chance of recovery,
unlike the Realm-era `DBManager`, which called `fatalError` on any open failure and turned a
transient disk problem into a crash report with no recovery path.

## Sync status

Placeholder — filled in when CloudKit is enabled. `ContainerBacking` (`Persistence/ContainerBacking.swift`)
already distinguishes `.cloudKit` from `.localFallback` as the backing a launch ended up on, and
`Persistence/RemoteChangeObserver.swift` already coalesces `NSPersistentStoreRemoteChange`
notifications into a single callback — both wired up now, inert until `ProductionContainerFactory.cloudKitEnabled`
flips to `true`, so that the screens that need to refresh from a remote change already have a single,
tested place to do it from.

## CloudKit ops record

Placeholder — the CloudKit container id, environment (development/production) promotion process,
and dashboard/schema-deploy runbook belong here once Stage 2 sets them up.

## Realm removal plan

- **v1.3**: `LegacyRealmImporter`'s Realm file is deleted from disk (see "Legacy import" above).
  This does not touch the `RealmSwift` package dependency — it only removes the on-disk file left
  over from before the user's device ever ran a SwiftData build.
- **Dropping the `RealmSwift` package dependency itself is a later, separate decision**, made only
  once enough of the install base is confidently past v1.1.0 (the last Realm-only release). Anyone
  who upgrades directly from v1.1.0 straight to a build without `RealmSwift` linked at all would have
  no reader for their old store and nothing to import from — silent data loss on upgrade, not a
  crash. That is a materially different risk than deleting an already-imported file, which is why the
  two are separate decisions on separate timelines.
