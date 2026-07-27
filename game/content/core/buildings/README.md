# Authored building content

Every new building is a version 6 `*.gdbuilding.json`. Subdirectories are
content categories only; IDs remain pack-wide and must be unique.

## Runtime access contract

- `anchors[]` with `role: "door"` are the only source of building entrances.
- A constructible building needs at least one door that permits `builder`.
- Staff and couriers use doors that permit `staff`.
- Visitors and residents use doors that permit `visitor`.
- An empty `allow` list permits every audience. Once `allow` is non-empty it is
  a whitelist, so include `builder` explicitly when construction must reach it.
- New authored files never receive hard-coded entrance fallback. A missing or
  incorrectly masked door is therefore visible immediately in diagnostics.

Run the transition audit after adding or editing content:

```sh
godot --headless --path . --script res://tests/repro/diag_building_content_transition.gd
```

`READY` means the file has an authored door usable during construction. Feature-
specific checks such as housing zones, storage intake/output and workplace slots
belong in their content suites.
