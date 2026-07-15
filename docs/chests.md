# Treasure chest tiers

Treasure rooms spawn one locked chest. Opening a chest consumes one key. The
chest tier controls both its appearance and reward rarity.

## Tier distribution

- Wooden chest: weight 60, common tier.
- Silver chest: weight 30, uncommon tier.
- Red chest: weight 10, rare tier.

All weights are configurable on the first-floor scene. A weight of zero removes
that tier from the random selection.

## Rewards

- Wooden chests have a 55% chance to drop health. Otherwise they select a
  common relic.
- Silver chests prioritize uncommon relics, with a configurable 80% upgraded
  rarity chance. Their fallback is a common relic.
- Red chests prioritize rare relics with the same upgraded rarity chance. Their
  fallbacks are uncommon and then common relics.
- If no eligible relic remains in the run, the chest drops health.

## Current relic rarity

- Common: Wind Boots, Far Eye.
- Uncommon: Crimson Blade.
- Rare: Iron Heart.

## Visual atlas

Source: `assets/sprites/items/chests/fantasy_rpg_toony_chests_32x32.png`

Each tier uses four vertical opening frames, each 32×32 pixels. A model keeps
the same `x` coordinate while its frame advances by 32 pixels on the `y` axis:

- Red origin: `(0, 0)`.
- Wooden origin: `(96, 128)`.
- Silver origin: `(192, 128)`.
