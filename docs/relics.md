# Tower Champion relic catalog

Relics are collectible upgrades that remain active until the current run ends.
They reset when a new run starts, and the same relic cannot be collected twice
during one run.

## Current acquisition sources

- The first-floor sanctuary offers one random relic on a pedestal and one
  health pickup.
- The treasure room contains a chest that consumes one key and reveals one
  random relic.

## Crimson Blade

- ID: `crimson_blade`
- Identification color: red
- Rarity: uncommon
- Effect: adds 5 damage to every sword attack.
- Current value: `attack_damage_add = 5`
- Balance note: improves damage breakpoints against tougher enemies while
  remaining small enough to combine with future permanent upgrades.

## Wind Boots

- ID: `wind_boots`
- Identification color: cyan-blue
- Rarity: common
- Effect: increases player movement speed by 15%.
- Current value: `speed_multiplier = 1.15`
- Balance note: improves mobility, dodging, and exploration without directly
  increasing damage.

## Far Eye

- ID: `far_eye`
- Identification color: purple
- Rarity: common
- Effect: increases sword range by 24 units and hitbox width by 8 units.
- Current values: `attack_range_add = 24`, `attack_width_add = 8`
- Balance note: makes multi-target hits and safer attacks easier, especially
  against ranged enemies.

## Iron Heart

- ID: `iron_heart`
- Identification color: golden orange
- Rarity: rare
- Effect: increases maximum health by 15 and immediately heals 15 health.
- Current values: `max_health_add = 15`, `heal_amount = 15`
- Balance note: healing cannot exceed the new maximum health.

## Technical rules

- The runtime catalog is stored in `items/relics/relic_catalog.gd`.
- `RelicComponent` applies effects to the player.
- The HUD lists collected relics using localized names.
- Effects from different relics are cumulative.
- Duplicate relics are rejected.
- Restarting the scene creates a new player and clears the previous run state.

## Future relic ideas

- Reduce sword attack interval.
- Increase sword knockback.
- Add critical-hit chance.
- Launch a projectile while attacking at full health.
- Block one hit per room.
- Heal after completing a configurable number of encounters.
