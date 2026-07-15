# Project structure and code conventions

Tower Champion follows a domain-based structure:

- `actors/`: player and enemy scenes and behavior.
- `combat/`: projectiles and shared combat feedback.
- `components/`: reusable actor components such as health and run inventory.
- `items/`: pickups, relics, keys, and chests.
- `world/`: floors, rooms, exits, and test environments.
- `ui/`: HUD and minimap behavior.
- `assets/`: imported art, audio, and other source assets.
- `localization/`: player-facing translations.
- `tests/`: smoke tests grouped by the domain they validate.
- `docs/`: technical and design documentation.

## Language conventions

- File names, folders, code identifiers, comments, logs, errors, and technical
  documentation use English.
- English is the source and fallback locale.
- Every player-facing string uses a translation key.
- Portuguese translations use the `pt_BR` locale in
  `localization/translations.csv`.
- Tests set their locale explicitly when asserting translated UI text.

## Godot conventions

- Keep a scene and its main script in the same domain folder.
- Keep `.uid` files beside their scripts when moving resources.
- Reserve `class_name` for reusable types referenced across domains.
- Do not add new gameplay files to the repository root.
- Update every `res://` reference when moving a resource.
- Run all smoke tests after structural or localization changes.
