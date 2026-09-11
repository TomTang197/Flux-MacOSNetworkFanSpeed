# Thermal sensor selection

The SMC catalog is selected by chip generation before any reads. M1, M2, M3,
M4, and M5 do not share a combined core table: the same key can describe a
different tier on another generation. In particular, M3 `Tf*` keys include
both CPU and GPU channels, so a prefix alone cannot determine their category.

The catalog's key mappings were checked against
[Stats' sensor definitions](https://github.com/exelban/stats/blob/master/Modules/Sensors/values.swift).
They are community hardware mappings, not an Apple-documented SMC API.

M4 Pro uses the alternate `Te06`, `Te0T`, and `Tp0H` assignments reported for
Mac16,8 in [Stats issue 3270](https://github.com/exelban/stats/issues/3270).
That report explicitly limits its verification to M4 Pro; its assignments are
not copied to M4 Max. The thermal view displays physical core counts from
`hw.perflevel*.physicalcpu` separately from readable sensor channels.

The temperature UI shows CPU/GPU summaries, die/package readings, and localized
system sensors. Individual CPU/GPU channel lists are hidden; sampling and fan-rule
inputs still use the full set of available readings described below.

## M5

- Base M5 uses super and efficiency cores.
- M5 Pro and M5 Max use super and performance cores.
- macOS may still name these performance levels `Performance` / `Efficiency`;
  topology discovery translates the two levels according to the M5 variant.
- The base M5 `Te*` candidates have no verified per-core mapping in this
  project. They retain raw channel names instead of invented E-core indices.
- Unknown generations and unverified variants do not inherit a different
  generation's core map. M5 has software regression coverage but still needs
  device validation here.

The core combinations are described in
[Apple's M5 Pro and M5 Max announcement](https://www.apple.com/newsroom/2026/03/apple-debuts-m5-pro-and-m5-max-to-supercharge-the-most-demanding-pro-workflows/).

## CPU temperature and fan-rule input

When a performance or super-core channel is readable, CPU temperature averages
the valid core channels. Die/package aggregates remain visible separately so
they are not counted again in that core average.

When no performance or super-core channel is readable, CPU temperature prefers
valid die/package readings. This avoids using efficiency-only readings to
represent load on unreadable performance cores. If aggregate readings are also
unavailable, readable efficiency channels, then remaining CPU channels, provide
fallbacks. Each average retains the oldest participating sample timestamp.

Fan rules continue to use the higher of the CPU and GPU averages, rather than
the maximum individual sensor. A displayed average represents the available
channels, not a measurement of every physical CPU core.

## M4 Max observations (2026-09-11)

The local machine reports 12 performance and 4 efficiency cores. Its legacy
`Tp*` readings are excluded by the M4 Max catalog. `Te05` and `Te0S` are readable
efficiency channels. Additional live `Te06`, `Te0T`, `Te04`, and `Te0R` channels
are retained with raw labels because their precise core assignments are not
verified. Sensor-channel counts must not be presented as physical-core counts.

An extended 25-sample capture after building the app showed `TCMb` changing
between 40.0 and 50.23°C and `TCMz` between 40.0 and 73.86°C. These are live
readings; a short sequence at exactly 40°C is not sufficient evidence to remove
them. The implementation does not apply a global 40°C rejection rule.

## Validation

Run `swift test` for the catalog, topology, aggregation, freshness, and control
policy regressions. `AeroPulseSensorCatalog` includes the application's actual
catalog in these tests. Build the `AeroPulse` Xcode scheme as well: Swift package
tests alone do not compile `FanMonitor` or the SwiftUI views.
