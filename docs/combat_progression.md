# Combat and progression scale

## Current first-floor baseline

The combat scale uses larger values so permanent upgrades and temporary run
bonuses can grow independently without relying on fractions.

| Stat | Current value | Intended result |
| --- | ---: | --- |
| Player maximum health | 90 | Survive 8 melee hits or 9 ranged hits |
| Player sword damage | 20 | Defeat melee enemies in 3 hits |
| Melee enemy health | 60 | Durable close-range threat |
| Melee contact damage | 12 | Higher risk for allowing close contact |
| Ranged enemy health | 20 | Still defeated by one base sword hit |
| Ranged projectile damage | 10 | Lower damage balanced by range |
| Health pickup | 18 | Restore 20% of base player health |
| Crimson Blade bonus | 5 | Increase base sword damage by 25% |
| Iron Heart bonus | 15 | Increase base health by about 17% and heal it |

These are first-pass balance values. Encounter density, attack frequency, and
floor duration should be measured during playtesting before increasing enemy
damage.

## Progression model

Player attributes should eventually be calculated in three layers:

1. **Base stats** define the character or class starting values.
2. **Permanent upgrades** are purchased with retained gold outside the tower
   and apply to every future run.
3. **Run modifiers** come from relics and other temporary rewards and are lost
   on death.

The intended calculation is:

`final stat = (base stat + permanent additions + run additions) * multipliers`

Keep permanent upgrade data in a save profile rather than writing it into the
player scene. A future skill tree can initially offer maximum health, sword
damage, movement speed, healing efficiency, and gold retention. Percentage
multipliers should be applied after flat additions so upgrades remain easy to
understand.

## Gold and death loop

The future loop is: enter the tower, collect gold, die or finish the run,
retain a configured portion of the gold, purchase permanent upgrades in the
hub, and start a new generated tower.

A 50% starting retention rate is a useful first target. It creates a cost for
death while ensuring every run can contribute to progression. Gold retention
can later become its own permanent upgrade, capped below 100% until a special
late-game unlock.

## Design references

- [UnderMine stats](https://undermine.wiki.gg/wiki/Stat) separate permanent
  equipment upgrades from temporary relics, blessings, curses, and potions.
- The [UnderMine peasant](https://undermine.wiki.gg/wiki/Peasant) has 200 base
  maximum health and 14 base swing damage. [Tunic upgrades](https://undermine.wiki.gg/wiki/Upgrade/Tunic)
  add 20 maximum health, while [swing damage upgrades](https://undermine.wiki.gg/wiki/Swing_Damage)
  add 4 damage.
- [UnderMine gold integrity](https://undermine.wiki.gg/wiki/Gold_Integrity)
  starts at 50% and increases in 5 percentage point steps through permanent
  sack upgrades.
- [Rogue Legacy upgrades](https://roguelegacy.wiki.gg/wiki/Upgrades) use gold
  in the Manor to permanently improve health, damage, classes, and other
  attributes between generations.
