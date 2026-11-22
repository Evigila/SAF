# Relocate SAF metadata and launchers

Recorded in America/Sao_Paulo (UTC-03:00).

SAF 2.1.0-release groups its manifest, project configuration, and lock under .agents/saf/. It deploys both SAF management launchers under scripts/ while retaining the root AGENTS.md and project debug.bat. Handler protocol 4 requires the new layout and keeps configuration and state schemas unchanged. A protocol 3 consumer can preserve its config and lock by moving them before bootstrapping. First Sync then checks old managed root files against the recorded baseline before retiring them.

Release preparation now asks for the version increment and channel before selecting a version, followed by a separate confirmation of the release copy before committing or publishing.
