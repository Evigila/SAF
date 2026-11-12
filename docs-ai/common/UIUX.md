# Shared UI and UX integration standards

## Authority and reading order

Use the affected project's design system, actual component source, styles, public contracts, and product requirements. SAF supplies no component library, visual tokens, brand, or UI runtime.

Inspect existing components and host usage, supported configuration/states, interaction/accessibility contracts, and relevant requirements. Distinguish documented requirements from inferred behavior. When required evidence is unavailable, identify the gap and continue independent work.

## Component reuse and host responsibilities

Reuse established components and supported extension points when they meet the requirement. Avoid cloning controls, competing styles/token systems, or duplicating validation, state, interaction, and localization behavior without a concrete reason.

Hosts compose interfaces and own the business/backend logic and approved configuration assigned by the actual architecture. Keep behavior, permission, and session changes within scope. Follow the project's separation of concerns rather than assuming a particular framework.

When a capability is missing, explain the gap, available approaches, compatibility, and impact. Implement an approach already covered by the task; obtain direction when it expands scope or needs an unapproved dependency. Record durable project-specific constraints in `docs-ai/current/` rather than turn them into universal SAF rules.

## Verification

Inspect component usage and supported configuration. Apply appropriate checks under [rules.md](rules.md#implementation-and-verification), and provide manual steps for user-visible behavior. Do not use Computer Use to test the project or present unperformed interaction checks as passed.