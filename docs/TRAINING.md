# Tennis XP defaults and evidence

The latest user decision excludes exercise fatigue entirely. This feature only awards Fitness/Nimble XP. It never calls exerciseRepeat, changes metabolism, accesses BodyDamage, or sets endurance. Vanilla running and other unrelated actions retain their normal effects.

## Rate and eligibility

Default raw requests per real minute of eligible rally time are Fitness20 and Nimble3. The server tracks each real participant independently, after an accepted serve/return, and stops crediting after six simulation seconds without another accepted stroke. Waiting, paused, finished, unequipped, dead, out-of-court or disconnected participants do not earn XP. Automatic solo-target strokes do not award a human XP. A server stall does not yield catch-up XP. Whole seconds are credited; a subsecond remainder is dropped when its session ends or its player object is replaced.

FitnessXPMultiplier and NimbleXPMultiplier are independent double sandbox settings, default1, range0–100. Zero skips that XP call. Fractions are supported. Current settings apply at each payout. Native addXp is used on server/SP only, retaining native XP modifiers and nutrition checks. The XP layer adds no Lifestyle dependency and changes no upstream files.

## Installed native level costs

TrainingNativeTest calls installed PerkFactory.init and checks both getXpForLevel and cumulative getTotalXpForLevel. Values below are XP for that one level increase, not cumulative totals:

| Increase | Fitness | Nimble |
|---|---:|---:|
|0→1|1500|75|
|1→2|3000|150|
|2→3|6000|300|
|3→4|9000|750|
|4→5|18000|1500|
|5→6|30000|3000|
|6→7|60000|4500|
|7→8|90000|6000|
|8→9|120000|7500|
|9→10|150000|9000|

Native XP code applies a0.25 factor to ordinary unboosted Nimble; Fitness is excluded from that reduction. Consequently default tennis gives approximately0.75 actual Nimble XP/minute for an unboosted character with otherwise standard settings. Fitness5→6 would require1500 eligible minutes (25 hours) at20/minute; Nimble0→1 requires100 eligible minutes at0.75/minute. These are arithmetic comparisons, not live timing promises. Existing XP progress, starting skill boosts, native sandbox modifiers and character conditions change them.

## Lifestyle comparison and rationale

Read-only installed source: Steam Workshop108600/3403870858/mods/Lifestyle/common/media. B42 uses the common implementation.

- shared/TimedActions/LSYogaAction.lua381–401: each successful pose requests Fitness=ceil(totalXP), Nimble=ceil(totalXP/3), multiplied by separate yoga sandbox values.
- totalXP=(min(efficiency+equipmentBoost,6)+ceil(ZenLevel/2))*poseXP. Beginner basic poseXP2.5 and a basic mat with aid enabled yield Fitness5/Nimble2 per pose before native modifiers.
- LSYogaAction.lua321–336 and client/aGTLSCheck.lua14–18: calculated normal-speed pose cadence is about27.5 real seconds, giving pose-only rates10.9 Fitness/4.36 Nimble per minute. Concluding rest and random completion bonus affect whole-session rates; this is not a stopwatch measurement or every yoga level's rate.
- Native shared/Definitions/FitnessExercises.lua and shared/TimedActions/ISFitnessAction.lua plus Fitness bytecode: squats base4 Fitness XP per repetition and nominal3000ms server loop, approximately80 raw XP/minute before speed adjustments.

Tennis20 Fitness/minute is one quarter of that nominal squat rate and somewhat above beginner yoga, reflecting active play. Nimble3/minute is deliberately below beginner mat yoga; users seeking faster progression can raise its independent multiplier. Both are starting balance choices, not claims of equivalent physical workloads. Yoga's muscle recovery and metabolic changes are not copied.

## Verification limits

The installed JVM verifies XP costs/API signatures; Kahlua mocks verify rate arithmetic, zero/partial/multiple settings and server eligibility. Live SP and two-client XP displays and native modifiers still require gameplay validation. Source tests do not prove live network award delivery.
