# Legacy GameSeagull Audit

## Evidence

| Item | Finding |
| --- | --- |
| Archive | `GameSeagull-main.zip` |
| SHA-256 | `4cd0f8b9e47d49913fcebd5614e84ad99e755862185847eba0b0e726622c97e5` |
| Shape | 27 entries: 20 regular files and 7 directories |
| Uncompressed size | 68,215 bytes |
| Integrity | ZIP integrity check passed |
| Extraction safety | No absolute path, `..` component, backslash path, or symbolic link |
| Inspection | Every regular file inspected; all four property lists validated; all three PNG files decoded |
| Missing from archive | Compiled tweak, target-game binary, entitlements, tests, CI, privacy metadata, and license |

The archive was extracted outside the CuePilot repository. The archive, its
source, icons, private declarations, and assets must not enter CuePilot.

## Executive finding

GameSeagull 2.1 is a Theos/Logos jailbreak tweak. MobileSubstrate injects it
when the private bundle `com.gamerdelights.gamepigeon.ext` loads. It depends on
private runtime classes and selectors, private KVC state, Substrate or
libhooker hooks, one ARM64 memory patch, private Preferences APIs, and
cross-container access.

The legacy 8-ball feature is not a billiards solver. It contains no image
acquisition, table or ball detection, pocket geometry, legal-shot engine,
ghost-ball construction, collision model, candidate ranking, power guidance,
cue-ball position planning, or match strategy.

Its 8-ball behavior is limited to:

1. making both private `PoolBall.isStripes` and `PoolBall.isSolid` return true;
2. writing the private pool-scene `mode` value to `"n"`;
3. cycling the private canvas stroke hue;
4. repeatedly setting the private `move_white` value to true;
5. replacing a float immediate in the private `mMove` implementation for three
   pool scene classes.

The patch extends a trajectory line already implemented by the target game. It
does not calculate a good, legal, safe, or strategically useful shot.

## Build and runtime architecture

- Theos target: `iphone:clang:latest:14.0`
- Main sources: `Tweak.x` and `Utils.m`, compiled with ARC
- Private framework: `Preferences`
- Additional framework: Cephei
- Preference bundle: `GameSeagullPrefs`
- Injection filter: `com.gamerdelights.gamepigeon.ext`
- Restart target: `MobileSMS`
- Package: `com.fiore.gameseagull` 2.1, `iphoneos-arm`
- Dependencies: MobileSubstrate, `ws.hbang.common (>= 1.17)`, and iOS firmware
  14.0 or later

The tweak tries rootful or rootless `libhooker` first and falls back to
`MSHookMemory`. Its release script builds both rootful and rootless Debian
packages. Preferences are read once into process-global state; the Settings
Apply action terminates `MobileSMS` so the tweak is reinjected with new values.

## Verified ARM64 8-ball patch

When `kExtendLines` is enabled, the constructor resolves `PoolScene`,
`PoolScene2`, and `PoolScene3`, finds their private `mMove` implementation,
searches the next `0x1000` bytes for `08 4e a8 52`, and writes
`0x52a9cdc8`, stored as `c8 cd a9 52` on little-endian ARM64.

Independent disassembly produced:

```text
08 4e a8 52  ->  mov w8, #0x42700000
c8 cd a9 52  ->  mov w8, #0x4e6e0000
```

| Bytes | Word | `imm16` | Shift | Destination | Value |
| --- | ---: | ---: | ---: | --- | ---: |
| `08 4e a8 52` | `0x52a84e08` | `0x4270` | 16 bits | `w8` | `0x42700000` |
| `c8 cd a9 52` | `0x52a9cdc8` | `0x4e6e` | 16 bits | `w8` | `0x4e6e0000` |

As IEEE-754 binary32 values:

- `0x42700000` is exactly `60.0f`.
- `0x4e6e0000` is exactly `998,244,352.0f`.

This proves the byte-level replacement. The target game's compiled `mMove`
implementation was not present, so the archive alone cannot prove every use of
that register value in every game release. The selector context, preference
label, changelog, and absence of solver code support the line-distance
interpretation.

## Feature inventory

| Area | Legacy behavior |
| --- | --- |
| Archery | Zeroes wind, resets the visible shot timer through private state, and forces a target distance of 50 |
| 8-ball | Extends a built-in line, forces line-related predicates, disables a private mode, recolors the line, and enables cue-ball movement |
| Darts | Forces a score and replaces a dart target with one of 62 hard-coded coordinates |
| Tanks | Replaces wind with zero |
| Mini Golf | Forces private inside/hole predicates true |
| Cup Pong | Kills every cup or synthesizes a shot while temporarily replacing physics force values |
| Anagrams | Reveals private word data or calls private word-entry and win methods |
| Word Hunt | Reveals and filters private word data |
| Sea Battle | Forces private enemy-ship sprites visible |
| Game icons | Replaces displayed win counts for 25 game identifiers |

## Unsupported dependencies

The implementation relies on:

- Logos runtime injection;
- MobileSubstrate and optional libhooker memory or method hooks;
- Theos root-path translation;
- Apple-private Preferences classes;
- private `LSBundleProxy` container lookup;
- direct access to another application's preference file;
- private game classes, selectors, fields, and KVC keys;
- `/usr/bin/killall` to terminate `MobileSMS`.

These behaviors are incompatible with a normal sandboxed App Store or
TestFlight application.

## High-risk defects

1. A missing method signature can wrap the computed offset and lead to a
   four-byte write at address zero.
2. The signature scan reads a fixed 4 KiB region rather than a bounded method
   body.
3. The intended return-instruction stop condition is ineffective.
4. The scanner performs potentially unaligned `uint32_t` reads.
5. The patch has no unique-match validation, version guard, write verification,
   rollback, or post-write instruction-cache check.
6. The patch assumes stable little-endian ARM64 machine code and register
   allocation.
7. Word Hunt removes entries from a mutable array during fast enumeration.
8. Cup Pong may mutate its live cup collection during fast enumeration.
9. Each automated Cup Pong shot installs another process-wide method hook.
10. Cup Pong assumes the altered physics force is consumed synchronously.

Additional defects include a Darts selection typo, stale scene-global state,
duplicate-letter handling errors, unvalidated win values, cached preferences
without synchronization, fixed-coordinate injected controls, unsafe view
presentation, per-frame redundant writes, guessed private object layouts, and
non-deterministic release scripting.

## Clean-room decision

The archive contains no license. CuePilot treats it only as behavioral evidence.
CuePilot must not contain or translate:

- the archive or extracted files;
- legacy source or hook structure;
- seagull icons or other assets;
- private class, selector, field, or KVC inventories;
- copied Darts coordinates or Cup Pong formulas;
- branding or rewritten injection logic.

CuePilot replaces mutable hidden-state behavior with original analysis of
visible pixels, public Apple APIs, deterministic geometry, an original rules
engine, and user-controlled actions.
