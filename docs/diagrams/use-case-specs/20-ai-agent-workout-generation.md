Use case Id: UC20    AI Agent Workout Generation

**Brief Description**
A multi-turn AI agent conducts a conversational interview with the user, asking about fitness goals, current fitness level, available equipment, injuries or limitations, and weekly schedule. Based on the responses, the AI uses tool calls to query the Exercise Library and generate a complete, personalized workout plan. The user reviews the AI-generated draft before confirming. The current AiGenerationScreen is a partial implementation; the full agentic multi-turn flow is a future enhancement.

**Primary actors**
Authenticated User, AI Service (Claude API), Exercise Library

**Preconditions:**
1. The user is authenticated.
2. The AI Service (Claude API) is reachable.
3. The Exercise Library contains exercises indexed by muscle group, equipment, and difficulty.
4. The user does not have an active ongoing AI generation session.

**Post-conditions:**
1. A new workout plan is saved in workout_plans with source = ai_generated.
2. The plan is linked to the user's profile and immediately available in Manage Workout Plan (UC04).
3. The conversation transcript is discarded after plan generation (not stored).
4. If the user declines the draft, no workout_plan record is created.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User opens "Generate with AI" from the Workout Plans screen. | 2. App initialises AI session; AI agent sends first message: "Let's build your perfect workout plan. What is your main fitness goal?" |
| 3. User responds to each interview question (goal, fitness level, equipment, injuries, schedule). | 4. AI agent processes each response, asks follow-up questions as needed, and builds a structured context object. |
| 5. — | 6. AI agent invokes tool call to Exercise Library to fetch exercises matching the user's equipment and goals. |
| 7. — | 8. AI agent generates a complete workout plan (name, days, exercises per day with sets/reps/rest) and presents it to the user as a formatted draft. |
| 9. User reviews the draft and taps "Confirm Plan". | 10. Subsystem saves the plan to workout_plans (source = ai_generated) and navigates user to the plan detail screen. |

**Alternative flows:**
4a. User provides conflicting information (e.g., no equipment but requests heavy lifting): AI agent flags the conflict and asks for clarification before proceeding.
8a. Exercise Library returns fewer exercises than needed: AI agent notes substitutions and explains them in the draft summary.
9a. User taps "Regenerate": AI agent discards the current draft, returns to the interview, and asks what the user would like changed.
9b. User taps "Edit manually": plan draft is passed to the manual plan editor (UC04) pre-populated with AI suggestions.
9c. User abandons mid-interview: no plan is saved; session state is discarded.
10a. Save fails due to network error: subsystem retries up to 3 times; if all fail, shows error and preserves draft in local cache so user can retry.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. interview capped at 8 questions; AI response time under 5 seconds per turn; generated plan must reference only exercises in the Exercise Library; no conversation data stored server-side; draft clearly labelled "AI-Generated"; user must explicitly confirm before saving; full multi-turn agentic flow is future — current implementation shows a single-screen AI form. />
