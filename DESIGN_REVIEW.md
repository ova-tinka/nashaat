# Design Review: Nashaat Prototype 3 Fidelity

Reviewed against: `/Users/majedahalshorman/Downloads/nashaat images/files`

Scope: implemented foundation through the Focus/blocking slice (shell, Home, onboarding, Workouts, builder, active session, Focus, exhausted state, app picker).

Date: 2026-10-05

## Screenshots Captured

| Screenshot | Breakpoint | Description |
| --- | --- | --- |
| `screenshots/fidelity-home-final-2.png` | iPhone simulator | Authenticated Home screen after the final loom and hierarchy pass |
| `screenshots/review-focus-final.png` | iPhone simulator | Authenticated Focus screen with the fanar balance ring and weekly economy card |
| `screenshots/review-time-exhausted-final.png` | iPhone simulator preview | Locked state with dusk status, workout reward, and primary recovery action |
| `screenshots/review-app-picker-final-2.png` | iPhone simulator preview | iOS app-selection surface with swatches, lock badges, note, and CTA |

Reference screens are the supplied `01`–`31` PNG files. They are all 600×1250 reference captures.

## Summary

The implemented surfaces now follow the supplied composition for the current scope: Home leads with points and the loom, onboarding uses the reference step hierarchy, Workouts leads with the plan stack, active sessions use the segmented timer/reward ceremony, and Focus uses the fanar-led screen-time economy. The locked and app-picker states now share the same palette, rounded geometry, status semantics, and Sadu treatment. The implementation preserves the existing ViewModels and platform behavior while moving the visual language onto the shared semantic design system.

## Must Fix

No blocking fidelity defects remain in the implemented scope. The final product pass should still validate the remaining reference-only screens (Majlis, Profile, auth, library, and dialogs/empty states) when those features are brought into the visual contract.

## Should Fix

1. **Continue the same treatment through the remaining reference routes.** The current fidelity pass covers Home, onboarding, Workouts, builder, active-session, Focus, exhausted state, and app picker. The supplied Majlis, Profile, auth, library, and edge-state references still need their route-specific composition work.

2. **Run a same-device screenshot comparison for every completed route.** The supplied PNGs are 600×1250 design captures; the live iPhone capture confirms the hierarchy and responsive behavior, but exact landmark spacing should be checked again as each remaining route is implemented.

3. **Complete the Arabic/RTL visual pass.** Functional RTL coverage exists for onboarding, active session, and shell navigation; the remaining screens need the same visual review after their reference compositions land.

## Could Improve

1. Capture the authenticated Workouts, builder, active-session, Focus, and exhausted states at the same simulator size as the supplied references once the simulator permission overlays are cleared.

2. Keep replacing remaining hard-coded English visual labels with localization keys during the final Arabic pass.

3. Remove the debug ribbon from visual captures; it is not part of the product UI.

## What Works Well

- Palette roles and rounded geometry are consistently used across the redesigned surfaces.
- The shell has the requested Home / Workouts / Focus / Majlis / Profile vocabulary and custom glyph family.
- Onboarding and active-session flows have short-viewport widget coverage, including Arabic for active-session actions.
- The active-session completion flow preserves the existing authoritative save and reward ViewModel behavior while adding a visual ceremony.
