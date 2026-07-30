# Legacy Feature Parity

Parity means a clean-room companion behavior based on visible information and
public APIs. It does not mean reproducing injection, hidden-state access, score
falsification, or automated input.

Status values describe the intended CuePilot disposition. They do not claim
that a replacement has passed runtime testing.

| Legacy behavior | Classification | CuePilot treatment | Runtime status |
| --- | --- | --- | --- |
| Extend the built-in 8-ball trajectory line | Partially replaceable | Draw an original detected trajectory and robust aim corridor in CuePilot's own PiP or Mac surface | Pending |
| Force all 8-ball lines visible | Partially replaceable | Generate guidance from visible frames without changing ball predicates | Pending |
| Disable 8-ball hard mode | Impossible on stock iOS; removed | Do not alter hidden game modes | Removed by design |
| Recolor the target game's line | Removed; cosmetically replaceable | Optional semantic colors may appear only in CuePilot | Pending |
| Always allow cue-ball movement | Impossible on stock iOS; removed | Do not alter game rules or private state | Removed by design |
| Archery no-wind mutation | Partially replaceable | Detect visible wind and recommend counter-aim | Deferred |
| Archery timer mutation | Impossible on stock iOS; removed | Do not alter the timer | Removed by design |
| Archery fixed target distance | Partially replaceable | Detect visible distance and calibrate advice | Deferred |
| Darts one-shot score mutation | Impossible on stock iOS; removed | Do not falsify score | Removed by design |
| Darts target injection | Partially replaceable | Detect the board and recommend a visible legal target | Deferred |
| Tanks no-wind mutation | Partially replaceable | Detect visible wind and distance and recommend counter-aim | Deferred |
| Mini Golf forced hole predicates | Partially replaceable | Provide path, bank, and speed guidance | Deferred |
| Cup Pong kill-all-cups | Impossible on stock iOS; removed | Do not change cup state | Removed by design |
| Cup Pong synthetic auto-shot | Partially replaceable | Estimate a visible trajectory and target without controlling input | Deferred |
| Anagrams word reveal | Fully replaceable as a companion | On-device OCR, original dictionary solving, ranking, and path display | Deferred |
| Word Hunt word reveal | Fully replaceable as a companion | On-device grid detection, original solver, ranking, and path display | Deferred |
| Anagrams auto-entry and forced win | Impossible within product policy; removed | Never inject words or synthesize touches | Removed by design |
| Reveal hidden Sea Battle ships | Impossible to reproduce honestly; removed | Use a legal probability heatmap from observed hits, misses, and remaining ships | Deferred |
| Spoof displayed win counts | Removed | Never falsify another application's statistics | Removed by design |

## Priority

The first release is centered on lawful 8-ball assistance:

1. screenshot analysis and manual correction;
2. legal shot generation and rules enforcement;
3. robust alignment and power guidance;
4. signed iPhone ReplayKit/PiP feasibility;
5. signed macOS ScreenCaptureKit overlay feasibility;
6. secondary tools only after the primary workflow has evidence-backed tests.

No secondary module should be labeled complete or beta until its implementation
exists and has basic automated and runtime coverage.
