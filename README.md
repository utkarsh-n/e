# e

A native SwiftUI math playground for iPhone and iPad on iOS 26 or later. Touch, hear, and explore the connections between e, proportional change, rotation, sound, and chance.

The first experiment opens at k = 1 and t = 1, so the amount is already e = 2.71828…. Drag time, change the rate, and watch the curve, tangent, and readout respond together.

## Play

| Experiment | What to try |
| --- | --- |
| Grow & fade | Scrub an exponential curve. Compare unrestricted growth, expected surviving atoms, and cooling chai. |
| A fading note | Pluck a tone. Change its pitch and exponential decay; the optional tactile envelope fades with it. |
| Imaginary turns | Drag around the unit circle. Stop at π and reach eⁱπ + 1 = 0. |
| Equal steps | Play or scrub thirteen notes from A3 to A4. Twelve equal semitone ratios double the frequency. |
| A growing spiral | Unwind two turns and adjust the proportional expansion. Equal angles multiply the radius by equal factors. |
| The hat surprise | Run uniform shuffles, find fixed points, and compare measured no-match frequency, exact finite-crowd probability, and 1/e. |
| Order in randomness | Collect sums of twelve independent uniform contributions. Compare the measured density histogram with the standard normal reference. |
| Becoming e | Split a year into smaller compounding steps. Watch (1 + 1/n)ⁿ approach e. |
| The waiting game | Run a Poisson arrival clock. Compare actual event history with exponential waiting survival. |

**Play** holds the active experiment. **Connections** chooses among all nine labs. **Discoveries** saves connections when you reach actual experiment conditions: a half-turn, a doubled pitch, enough sampled trials, or another stated milestone. Progress and feedback preferences save locally.

## Feel and hear

Sound is off until you enable it. Notes use synthesized PCM audio and play in Silent Mode when Sound is enabled, through the selected system audio output. Notes mix with other audio and stop when the app becomes inactive. Touch feedback, touch strength, and the fading note's continuous feel are configurable independently. Haptics need supported hardware.

The fading waveform is drawn at 2.5 Hz so it remains visible; audio uses the selected pitch. Haptics represent amplitude, rather than vibrating at the audible frequency. Canvas gestures have slider/button and VoiceOver alternatives. Automatic work pauses when leaving Play or when the app becomes inactive.

## Mathematics and design

Plots, labels, and results are computed natively. Field notes explain each model's assumptions and link its source. A finite shuffle probability is shown separately from its limiting value; a density is distinguished from a probability; the bell experiment's twelve-uniform sum is labeled as an approximation.

The visual design uses dark matte instrument content, restrained glowing traces, meaningful mint/amber/lilac accents, readable numbers, and native glass actions.

The app has no accounts, tracking, networking, third-party packages, or sensor permissions. Experiments work offline. Opening a source link uses your browser.

## Build and test

[project.yml](project.yml) is the XcodeGen source. [Euler.xcodeproj](Euler.xcodeproj) is included. The display name is **e**; the build scheme is **Euler**. Configure your own signing team for a physical device.

Use the validation helper from the project directory:

```sh
cd /path/to/e
bash Tools/validate.sh
```

The [helper](Tools/validate.sh) runs the math tests with temporary caches, copies only App, Sources, UITests, and project.yml into a fresh `/tmp` directory, generates the Xcode project there, and builds for Simulator. It avoids copying existing build artifacts. Pass a simulator identifier to run the UI suite and then install/launch the app:

```sh
bash Tools/validate.sh "<simulator-id>"
```

The math core is shared between the app's framework and a dependency-free Swift package. Core tests cover growth/decay, damped signals, phasors, tuning, spirals, exact derangements and shuffling, normal density/sampling, compounding, and exponential waits. For a core-only run:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/e-math-clang-modules SWIFTPM_MODULECACHE_OVERRIDE=/tmp/e-math-swift-modules swift test --disable-sandbox --scratch-path /tmp/e-math-build --cache-path /tmp/e-math-cache --config-path /tmp/e-math-config --security-path /tmp/e-math-security
```

On this Mac, an Xcode build reading the Documents checkout stalled inside NSFileCoordinator; a process sample confirmed it. The helper keeps Xcode's source copy and outputs outside Documents. Source edits belong in the original project. For a signed device run, open the temporary Euler project in Xcode and choose the device and signing team.

Test launches accept `--ui-testing` to clear an isolated preference suite and disable feedback, and `--lab` followed by `grow`, `resonate`, `rotate`, `tune`, `spiral`, `shuffle`, `bell`, `compound`, or `wait`.

Debug builds also accept `--feedback-check`: once the app is active for 700 ms, it requests a two-second 220 Hz note with decay 0.9 and a matching tactile envelope. It restores the previous in-memory feedback settings without writing preferences, and saves engine/rendering facts to `Documents/feedback-check.json`. The report does not establish that a person heard or felt the cue.
