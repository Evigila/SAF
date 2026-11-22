# Standardize SAF release versions

Recorded in America/Sao_Paulo (UTC-03:00).

Add a managed release skill and shared requirements for channel suffixes, version increments, and user confirmation of release copy. SAF 2.0.1-alpha.1 introduces version parsing and ordering for those channels, with historical numeric versions still readable by updated handlers. The publisher checks major/minor and release-channel approval while preparing the manifest. Git publication remains separate.

Existing SAF 2.0.0 installations require one trusted bootstrap refresh before syncing this alpha. The updated bootstrap preserves project configuration and installation/audit state until the ordinary synchronization step.
