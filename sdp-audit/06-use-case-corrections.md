# UC17–UC26 specification corrections

Appendix A is present as `docs/use-case-specifications-appendixA (1).docx`; line-level DOCX scenario comparison was not completed in this audit. The following are implementation-grounded wording constraints, not fabricated row-by-row comparisons.

| UC | Correct wording constraint |
|---|---|
|17|“Bloom requests activation of the macOS Network Extension content filter and reports configured/ready state separately from verified traffic blocking. Browser enforcement depends on supported flow identification; Brave Private target blocking failed observed QA.” Do not call it DNS blocking without evidence of DNS interception. |
|18|“The macOS client configures native helpers/extensions; installation, approval, signing, permissions and live enforcement are required.” |
|19|“Tauri includes Windows target configuration; working Windows web blocking is not established.” |
|20|“When provider credentials/network are available, the AI service may generate a workout proposal; user reviews/saves it.” Do not imply offline or unconditional generation. |
|21|If no implementation is evidenced, mark computer-vision form checking as not implemented/future work; do not describe automated feedback as current behavior. |
|22|“Gamification outcomes are derived by backend rules where configured; verify each award and privacy rule.” |
|23|“Subscription/payment processing is not evidenced as integrated or submitted; describe as planned unless sandbox transaction proof exists.” |
|24|“Reports display computed data; measured accuracy/performance is unverified.” |
|25|“Coach/B2B flows are partial pending role/tenant and live workflow acceptance.” |
|26|“Background adaptation is not established without a demonstrated trigger, persisted result and failure handling.” |

For all ten cases, the Appendix A normal and alternate steps must be extracted and aligned against source before issuing exact replacement of every system-response cell.
