Use case Id: UC25    Coach Mode / B2B Gym Partnerships

**Brief Description**
Gyms purchase discounted multi-seat licenses through Nashaat. A Gym Owner creates a gym account, sets the maximum number of coaches, and invites coaches by email. Each coach can view the workout history, screen time trends, and streak data of their assigned athletes, and can recommend or assign workout plans to them. Athletes receive an invitation and must accept before a coach can view their data. RBAC enforces the hierarchy: Gym Owner > Coach > Athlete.

**Primary actors**
Gym Owner, Coach, Athlete (Registered User), Supabase Backend

**Preconditions:**
1. The Gym Owner has purchased a B2B multi-seat license (via UC23).
2. A gym_accounts record exists for the gym with a valid subscription.
3. Coaches and athletes are registered Nashaat users.
4. The gym has not exceeded max_coaches.

**Post-conditions:**
1. coach_athlete_relationships records exist for each accepted coach–athlete pairing.
2. Coaches can view (read-only) assigned athletes' workout_logs, screen_time_transactions, and streak data.
3. Assigned workout plans are saved in workout_plans with the athlete as the owner.
4. Athletes retain full control over their own data and can revoke coach access at any time.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. Gym Owner creates a gym account and purchases a multi-seat license. | 2. Subsystem creates a gym_accounts record and a coaching_profiles record for the owner. |
| 3. Gym Owner invites coaches by email from the Gym Management screen. | 4. Subsystem sends invitation emails; creates coaching_profiles records with status pending. |
| 5. Coach accepts invitation. | 6. Subsystem links coaching_profiles to gym_accounts and activates the coach's coaching profile. |
| 7. Coach invites athletes by username or email. | 8. Subsystem sends invitations; creates coach_athlete_relationships records with status pending. |
| 9. Athlete accepts coach invitation. | 10. Subsystem sets coach_athlete_relationships.status to active; coach can now view athlete's data. |
| 11. Coach views athlete dashboard (workout history, screen time, streaks). | 12. Subsystem returns read-only athlete data filtered to the coach's assigned athletes only. |
| 13. Coach assigns or recommends a workout plan to an athlete. | 14. Subsystem creates a workout_plans record linked to the athlete; sends notification to the athlete (UC12). |

**Alternative flows:**
4a. Gym has reached max_coaches: subsystem blocks the invite and shows "Upgrade your gym plan to add more coaches".
9a. Athlete declines coach invitation: subsystem sets status to inactive; coach does not gain access to athlete data.
11a. Coach attempts to view non-assigned athlete: subsystem returns 403; no data is exposed.
14a. Athlete declines assigned plan: the plan remains in workout_plans but is marked as declined; coach is notified.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. Gym Owner > Coach > Athlete RBAC enforced server-side via RLS; coach read-only access to athlete data — no write access except plan assignment; athlete can revoke coach access at any time; B2B billing via Stripe per-seat pricing (UC23); coaching_profiles.is_verified flag for credentialed coaches; gym license limits enforced at invite time; coach dashboard loads within 3 seconds for up to 50 athletes. />
