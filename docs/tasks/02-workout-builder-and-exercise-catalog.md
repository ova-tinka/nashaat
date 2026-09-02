# Task 2 — Improve the manual workout builder and exercise catalog

**Assigned to:** Developer 2  
**Type:** Feature requirements and user-flow handoff  
**Status:** Ready for research

## Purpose

Make manual workout creation quick, understandable, and useful for beginners and returning users. Users should be able to find an exercise, understand how to perform it, configure it for a plan, arrange the plan, save it, and start the workout without unnecessary friction.

Exercise information should be good enough to support a safe, informed choice: demonstration media, targeted muscles, equipment, difficulty, measurement type, instructions, and practical tips.

## Existing product context

The current workout area already includes an exercise library, exercise detail screen, manual builder, active session, and AI-generation entry point:

- [Workout routes](../../lib/app/app-router.dart)
- [Workout feature](../../lib/features/workout/)
- [Workout-plan use case](../diagrams/use-case-specs/04-manage-workout-plan.md)
- [Exercise entity](../../lib/core/entities/exercise-entity.dart)
- [Exercise catalog documentation](../db/exercise-catalog.md)
- [Base database schema](../db/schema.sql)
- [Exercise-field migration](../db/migration-exercise-schema.sql)

The current data model already supports exercise descriptions, a primary muscle group, measurement type, a media reference, system/custom exercises, difficulty, multiple muscle groups, and ordered instruction steps. The current catalog documentation uses Free Exercise DB as a seed source and does not currently import demonstration media. Treat this as existing context, not as a final provider decision.

## Research assignment

1. Test the current builder and library as a user would. Record where a user has to guess, repeat information, lose progress, or leave the flow to understand an exercise.
2. Review at least three workout-builder or fitness-library products. Focus on search, filtering, exercise previews, configuring sets/reps/time, reordering, editing, and saving.
3. Research practical exercise-data sources. Compare Supabase-seeded data, a remote API, and a hybrid cache. Check data completeness, image/GIF/video rights, attribution, rate limits, stable identifiers, cost, and failure behavior.
4. Recommend the simplest source strategy that can be supported by this app. The recommendation must include a fallback when media or the provider is unavailable.
5. Identify the minimum metadata users actually need. Do not make the builder heavy by displaying every possible field everywhere.
6. Keep a short research log with links, findings, the selected source strategy, and unresolved risks.

## Concept-art assignment

Use an image generator to create concept screens for the selected experience. Keep the concepts focused on information hierarchy and interaction—not exact copy or production-ready assets.

Create concepts for at least:

- Exercise library with search, filters, and exercise cards
- Exercise detail with demonstration media and a visual representation of target muscles
- Empty manual-builder state
- Builder with selected exercises and visible ordering
- Exercise configuration for sets/reps/weight, time, distance, or rest as appropriate
- Reordering, editing, removing, and replacing an exercise
- Plan review/save state and validation feedback
- Custom exercise creation

Suggested prompt pattern:

> Mobile workout-builder UI concept for Nashaat. Show [screen and primary action]. Include exercise cards, clear sets/reps/time controls, [muscle-target visual], demonstration media area, accessible contrast, and a calm but motivating fitness visual style. Use no logos, copyrighted characters, or readable fake text. Concept art for product planning, not a final screenshot.

Save the prompts with the concepts and record which decisions are approved for implementation.

## Feature requirements

### Finding and understanding exercises

- Users can browse the exercise catalog and search by name.
- Users can filter or sort by relevant metadata such as target muscle, difficulty, equipment, and measurement type when that data is available.
- Exercise cards show enough information to choose confidently without making the list dense.
- Tapping an exercise opens a detail view with:
  - Demonstration GIF, image, or video when available
  - A graceful placeholder and text instructions when media is unavailable
  - Target muscle groups, represented with clear labels and a simple visual highlight where practical
  - Difficulty
  - Equipment
  - Measurement type and the fields the builder will request
  - Short description
  - Ordered steps
  - Form cues, safety notes, or common mistakes when reliable data exists
- Media must not autoplay in a way that causes unexpected sound, excessive data use, or a blocked interaction.

### Creating a manual plan

- An authenticated user can start a manual plan from the workout area.
- The user can enter a plan title and optional description, choose scheduled days, and add exercises from the catalog.
- The builder clearly shows the current exercise count, estimated workout shape/duration where available, and the next required action.
- Each selected exercise can be configured according to its measurement type. The UI should not ask for weight when an exercise only needs time, and should not hide required inputs.
- The user can reorder exercises, edit their configuration, replace an exercise, remove an exercise, and add notes where useful.
- The plan can be reviewed before saving. The review must show the actual order and configuration that will be used during the active session.
- Saving must preserve the selected exercises and their configuration so the active session can use the plan without re-fetching or reinterpreting the user’s choices.
- The user can edit an existing manual plan and can delete it through a clear confirmation flow. Historical workout logs must remain intact.

### Custom exercises

- If a suitable exercise is not in the catalog, the user can create a custom exercise without abandoning the plan.
- Custom exercises should support the same essential fields as catalog exercises, with optional demonstration media.
- The UI must distinguish system exercises from the user’s custom exercises.
- Custom exercise data must not accidentally become visible to other users unless sharing is explicitly supported.

### Validation and resilience

- A plan cannot be saved without a valid title and at least one exercise.
- Invalid values such as zero or negative duration, reps, sets, or rest are explained next to the relevant field.
- Unsaved changes are protected when the user backs out or navigates away.
- Save failures preserve the user’s draft and provide retry feedback.
- Empty catalog, unavailable media, slow network, API failure, and partially populated exercise records each have usable states.
- The feature remains usable with no external media provider response.

## User flows

### Create and save a manual workout

Workout area → Create manual plan → enter title/description and scheduled days → Add exercise → search/filter library → preview exercise detail → add exercise → configure measurement fields → repeat or reorder → review plan → save → confirmation → start now or return to workout list.

### Edit an existing plan

Workout list → open plan → Edit → change schedule, order, exercises, or values → review changes → save → confirmation. If the plan is scheduled for today, explain whether the change affects the next active session according to the existing product rule.

### Create a custom exercise

Builder → Add exercise → no suitable result → Create custom exercise → enter name and essential instructions/measurement fields → optionally add media → save custom exercise → return to the builder with it selected.

### Learn before adding

Exercise library → choose exercise → view media, muscle targets, equipment, steps, and measurement type → add to plan or return to library. A missing GIF must not make the exercise unusable.

### Recover from a failed save

Builder with unsaved draft → save → network or server failure → show the reason and retry action → keep draft intact → save succeeds → continue to confirmation.

## Simple technical guidance

- Keep the existing feature-based MVVM/coordinator structure and current workout routes unless research shows a clear usability problem.
- Reuse the existing `ExerciseEntity`, workout-plan model, repository interfaces, and shared design components where they fit.
- The current exercise schema has `media_id`, `measurement_type`, `muscle_group`, and catalog extensions for `difficulty_level`, `muscle_groups`, and `steps`. If equipment, media variants, safety notes, or additional fields are needed, document the smallest data change required.
- Decide whether exercise media is stored in Supabase Storage, referenced from a licensed provider, or cached from an external API. Do not make the UI depend on one provider’s response shape.
- Prefer stable catalog data and a local/Supabase fallback over fetching the complete exercise catalog on every screen.
- Do not store secrets or provider keys in the Flutter client.
- Keep the plan’s saved exercise configuration compatible with the active workout and workout-log flows.

## Deliverables

- Research log and source/provider comparison
- Chosen exercise-data and media strategy, including licensing and fallback behavior
- Concept-art screens and image-generator prompts
- Improved manual builder, library, and detail flows
- Required model/schema/migration notes, if any
- Updated empty, loading, error, and validation states
- Focused tests or reproducible manual checks for create, edit, custom exercise, media failure, and save failure

## Acceptance criteria

- A user can create a useful manual plan without leaving the builder to understand an exercise.
- Exercise cards and details expose demonstration media, target muscles, difficulty, equipment, measurement type, and instructions when available.
- Target muscles are represented clearly through labels and an understandable visual treatment where the selected concept supports it.
- Users can add, configure, reorder, edit, replace, and remove exercises before saving.
- Custom exercises work without contaminating the system catalog or other users’ data.
- Invalid input and failed saves do not silently discard the draft.
- Missing or unavailable media does not block exercise selection or workout creation.
- Saved plans start the correct active workout with the same exercise order and configuration the user reviewed.
- The selected data source is documented with rights, reliability, and fallback considerations.

## Out of scope

- AI workout generation changes
- Medical diagnosis, injury treatment, or personalized clinical advice
- Computer-vision form checking
- Building a full content-management console unless the chosen data strategy genuinely requires one
