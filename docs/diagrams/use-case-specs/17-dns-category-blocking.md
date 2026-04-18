Use case Id: UC17    DNS-Based Web Blocking by Category

**Brief Description**
A VIP user blocks entire categories of websites (e.g., Social Media, Gaming, Adult Content, News, Streaming) rather than individual URLs. Each category maps to a curated domain list maintained by Nashaat. Enforcement is applied at the DNS level, making it stronger than browser extensions and effective across all browsers and apps on the device.

**Primary actors**
Authenticated User (VIP)

**Preconditions:**
1. The user is authenticated and holds a VIP subscription.
2. The device has an active internet connection.
3. The Nashaat app has DNS filtering permissions configured on the device.
4. The DNS Filtering Service is reachable.

**Post-conditions:**
1. Selected categories are saved in the user_category_rules table with status active.
2. The DNS Filtering Service has been notified of the updated rules for the user's device.
3. All domains belonging to blocked categories resolve to a block page or fail to resolve.
4. The user can view, pause, or remove category rules at any time.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. VIP user navigates to Blocking Settings and selects "Block by Category". | 2. Subsystem displays a list of available categories (Social Media, Gaming, Adult Content, News, Streaming, etc.) with domain count and icons; highlights categories already active. |
| 3. User selects one or more categories and taps "Apply". | 4. Subsystem saves the selections to user_category_rules (status active) and dispatches updated rules to the DNS Filtering Service. |
| 5. — | 6. DNS Filtering Service acknowledges receipt; subsystem shows confirmation. Blocked categories display a lock icon. |
| 7. User attempts to access a blocked domain on any browser. | 8. DNS resolver returns a block response; browser shows Nashaat block page with category name and remaining screen time. |

**Alternative flows:**
2a. User is on Free tier: subsystem shows upgrade prompt; category blocking is VIP-only.
4a. DNS Filtering Service unreachable: subsystem queues the rule update and shows "Changes will apply once connectivity is restored"; local DNS profile is used as fallback.
4b. User selects a category already partially covered by existing individual blocking rules: subsystem merges rules without duplication.
6a. User pauses a category: subsystem sets status to paused in user_category_rules and notifies DNS Filtering Service; blocking ceases until resumed.
6b. User removes a category: subsystem deletes the user_category_rule row and notifies DNS Filtering Service to remove the associated domains.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. category domain lists updated by Nashaat team; DNS enforcement applies across all browsers and native apps; rule propagation to DNS service under 5 seconds; VIP gate enforced server-side; categories shown with domain count and representative icon; max 10 active category rules per user; user_category_rules.status must be one of active/paused. />
