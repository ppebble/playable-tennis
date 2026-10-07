# Tennis trajectory and court bounds

## Cause and model

The old launch solver set flight time to horizontal distance / nominal speed, then solved vertical velocity to land exactly at the marker. With gravity 9.8, a longer flight therefore created a much higher lob. The ground reflection retained 78% of downward speed, so the tall incoming arc also produced an excessively high rebound. This is a numerical cause, independently of visual frame rate.

For a representative diagonal serve on the former maximum 14 x 30 court (quarter-width server, speed 9, launch height 1.4), the analytical values are:

| Quantity | Previous | Revised |
|---|---:|---:|
| First flight time | 2.323 s | 1.152 s |
| Initial apex | 7.329 | 2.400 |
| Rebound apex | 4.459 | 1.100 |
| Rebound flight until second bounce | 1.908 s | 0.948 s |
| First bounce to baseline | 1.203 s | 0.750 s |
| Height at baseline | 4.155 | 0.726 |

These are calculations for the model, not measurements of live game visuals. The hit envelope is 0.15 to 2.4 height units: the old serve is above it near the baseline. The revised rebound spends about 0.88 seconds inside that height envelope, with at least 0.85 seconds verified by the fixed-step simulator.

For launch height z and apex limit H=2.4, the maximum flight duration is `(sqrt(2*g*(H-z)) + sqrt(2*g*H))/g`. Apply that cap after the net-clearance duration calculation. An impossible very low stroke immediately beside the net can still hit the net; clearance must not override the height cap. BallSpeed remains nominal because trajectory assistance may increase flight speed on a long court. It is not a strict horizontal speed limit.

Tennis ground contact sets vertical speed to `sqrt(2*g*1.1)`. Horizontal velocity is preserved or reduced proportionally so there are at least 0.75 seconds from the bounce to the receiving baseline. This is deliberately assisted game physics, including fixed rebound height, rather than a material restitution simulation. Wall practice keeps its existing reflection and bounce rules unchanged.

## Landing and court proportions

A rally marker is the actual first ground contact, now 45% of the distance from the net to the opponent baseline. It was 64%. On an 18-20 tile court this moves the first bounce from 5.76-6.40 tiles behind the net to 4.05-4.50 tiles, leaving 4.95-5.50 tiles for the rebound. A fraction of the entire hitter-to-target path would sometimes put contact on the hitter's side or near the net, so that is not used. Serves remain 32% into the opposing half, inside the diagonal service box.

New registrations accept width 8-10 and length 18-20 tiles. The length range leaves both a visible incoming flight and roughly five tiles of return space after a rally bounce; a 12-tile court only leaves 3.3 tiles. Narrowing the length spread from 18 tiles to 2 also reduces variation in timing. Existing court geometry is not changed, and the previous 6 x 12 and 14 x 30 extremes remain covered by trajectory tests.

Width is a playability choice, not a claim about official court scale or measured player speed. Aim reaches +/-30% of width. With the default 1.8 tile racket radius, center-to-wide-aim movement is 0.6-1.2 tiles for width 8-10, versus 2.4 tiles at width 14. Moving between opposite aim extremes, after accounting for reach at both ends, is 1.2-2.4 tiles versus 4.8 tiles. At an explicitly assumed lateral speed of 3 tiles/second that means 0.4-0.8 seconds versus 1.6 seconds. Actual character speed depends on game state and needs playtesting. The selected bounds require movement while keeping the opposite-side travel closer to a rebound's available time.

## Verification boundaries

Game Kahlua tests cover both server directions, low/default/high nominal speeds, new minimum/maximum and previous extremes, legal serve landing, actual first-bounce markers, apex and rebound bounds, at least 0.85 seconds of return height, human returns from the receiving marker. Extreme crosscourt shots have at least 0.6 seconds within court plus default racket reach after the first bounce. Later movement beyond a sideline can still produce a legitimate unreturned winner.

Near-net contacts at heights 0.15, 0.5, 1.2 and 2.4 verify that net clearance never breaks the apex cap. Existing wall continuity tests remain intact. These tests prove simulation behavior; they do not prove live client-server timing, input comfort, or displayed smoothness.
