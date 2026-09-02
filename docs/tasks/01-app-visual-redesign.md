# Task 1 — Research and redesign Nashaat’s complete visual experience

**Assigned to:** Developer 1  
**Type:** Product/design requirements and implementation handoff  
**Status:** Ready for research

## Purpose

Give Nashaat one coherent visual identity that makes exercise, focus, and earning screen time feel motivating and easy to understand. The redesign covers the whole existing app, not only the dashboard.

The final result should feel like one product: shared visual rules, reusable components, clear states, and consistent navigation across authentication, onboarding, workouts, blocking, social features, rewards, subscriptions, and settings.

## Existing product context

Nashaat helps users earn screen time by completing workouts. It already has a Flutter Material 3 design system under `lib/shared/design/`, including theme tokens, buttons, cards, badges, chips, progress bars, stat tiles, and empty states. The current app uses a custom light theme and has routes for authentication, onboarding, the authenticated shell, workout creation, exercise browsing, exercise details, active sessions, blocking, settings, and subscription placeholders.

Use these as the starting point rather than creating a second design system:

- [Project architecture](../structure/architecture.md)
- [Shared design files](../../lib/shared/design/)
- [Application routes](../../lib/app/app-router.dart)
- [Current feature screens](../../lib/features/)

## Research assignment

Complete the research before committing to the final direction.

1. Audit every current route and screen. Record what the screen does, its primary action, its important states, and any visual inconsistency.
2. Review at least four relevant products across fitness, habit-building, focus, and productivity. Capture useful patterns rather than copying a brand.
3. Compare navigation, onboarding, progress feedback, workout cards, blocking states, reward moments, empty states, and error handling.
4. Propose two or three visual directions. Each direction should include a short rationale, mood references, color and typography direction, image style, and risks.
5. Select one direction for Nashaat and explain why it supports the product’s exercise-to-screen-time loop.
6. Keep a small research log with links, observations, and decisions so another developer can understand the reasoning.

The research should prioritize clarity, motivation, accessibility, and a visual style that can be implemented reliably in Flutter. Avoid choosing a style only because it looks impressive in concept art.

## Concept-art assignment

Use an image generator to make visual concept screens for the selected direction. These are design exploration artifacts, not production assets or a replacement for implementing the real Flutter screens.

Create concepts for at least:

- Welcome, sign-in, and onboarding
- Dashboard/home with screen-time balance and workout progress
- Workout hub and manual workout builder
- Exercise library and exercise detail
- Active workout session and completion result
- Blocking/focus state, including the time-exhausted state
- Friends/private leaderboard
- Rewards and achievements
- Settings/subscription

For each generated concept, save the prompt and note what should or should not be carried into the real UI. Do not use generated logos, fake brand names, unreadable text, or copyrighted characters. Use the concept art to communicate layout, mood, imagery, hierarchy, and component behavior.

Suggested prompt pattern:

> Mobile fitness and focus app UI concept for Nashaat, a product where users complete workouts to earn screen time. Show [screen and primary action]. Use [chosen visual direction], clear hierarchy, accessible contrast, realistic mobile spacing, reusable cards and buttons, and no logos or readable fake text. Concept art only, not a final production screenshot.

## Feature requirements

### Visual identity

- Define a named visual direction and document the color, typography, spacing, radius, border, shadow, icon, illustration, and image principles.
- Use semantic roles such as background, surface, primary action, success, warning, error, muted text, and reward accent. Components must not depend on scattered hard-coded colors.
- Make the relationship between exercise progress and earned screen time visually obvious.
- Use imagery where it improves motivation or comprehension. Decorative images must not compete with the primary action.
- Define how the visual system behaves on small screens, large screens, and with long text.
- Preserve or intentionally redesign light/dark behavior. If dark mode remains available, it must have a deliberate treatment rather than a mechanically inverted palette.

### App-wide consistency

- Apply the new system to every current user-facing screen, including loading, empty, error, disabled, success, and confirmation states.
- Standardize page headers, bottom navigation, cards, forms, dialogs, bottom sheets, snackbars, progress indicators, and primary/secondary actions.
- Make primary actions predictable. A user should be able to tell how to start a workout, earn time, configure blocking, view friends, and inspect rewards without learning a new pattern on every screen.
- Keep navigation understandable for first-time users and returning users. Do not hide core workout or screen-time information behind decorative interactions.
- Include accessible touch targets, readable contrast, semantic labels for icons/images, and a clear non-color-only indication of status.

### Content and states

- Replace placeholder or vague copy with short, action-oriented copy where the screen’s purpose is known.
- Design first-use and empty states for no plans, no exercises, no friends, no rewards, no leaderboard membership, and no available screen time.
- Design failure states for network errors, unavailable media, failed workout saves, blocked permissions, and subscription/loading failures.
- Include feedback after important actions: saving a plan, completing a workout, earning screen time, joining a leaderboard, unlocking an achievement, and changing blocking settings.

## Core user flows to redesign

The redesign must support these existing product flows without changing their business rules:

1. **New user:** open app → sign up/sign in → complete onboarding → configure workout and blocking preferences → arrive at the dashboard.
2. **Daily workout:** dashboard → choose a plan → review exercises → start session → complete or partially complete session → see earned screen time and progress.
3. **Focus loop:** screen-time balance becomes unavailable → user sees why access is blocked → user is guided to complete a workout or use the permitted emergency path.
4. **Social motivation:** dashboard/social area → view private friends leaderboard → inspect ranking/progress → return to a workout action.
5. **Progress and recognition:** dashboard or rewards area → view streak/progress → open an achievement/reward → understand the next action needed.

## Simple technical guidance

- Extend the existing `AppTheme` and token files under `lib/shared/design/` instead of styling each screen independently.
- Reuse and improve existing shared atoms, molecules, and organisms before adding new variants.
- Follow the existing MVVM/coordinator structure and current route names unless a navigation change is justified by the research.
- Keep presentation changes separate from workout, blocking, subscription, and gamification business rules.
- Use local assets or remote media deliberately. Document licensing, loading behavior, placeholders, and caching for any new images.
- Add dependencies only when they solve a real need and the team can support them.

## Deliverables

- Research log and comparison notes
- Chosen visual direction with rationale
- Concept-art screens and the prompts used to generate them
- Updated Flutter theme tokens and reusable components
- Redesigned existing screens and states
- A short implementation note describing any navigation, asset, or accessibility decisions
- Focused visual and interaction verification on small and large device layouts

## Acceptance criteria

- The research and selected direction are documented and understandable without a live presentation.
- Concept art exists for the major flows listed above, with prompts retained.
- Existing screens use a consistent visual system and no longer look like unrelated templates.
- The redesigned app clearly communicates workout progress, screen-time balance, blocking status, and next actions.
- Loading, empty, error, success, and disabled states are designed for the major flows.
- Text and controls remain usable with long content and on small screens.
- Accessibility basics are addressed: contrast, touch targets, semantics, and status indicators.
- Existing user actions still work through the current architecture; the task does not silently remove functionality.

## Out of scope

- Inventing new workout, blocking, subscription, or gamification rules
- Replacing the app’s navigation architecture without evidence that it is necessary
- Treating AI-generated concept art as final production assets
- Adding a complex animation system before the core hierarchy and states are correct
