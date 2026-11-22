---
name: prepare-release
description: Select a suffixed version, prepare release copy for approval, and verify authorized Git tags or package publication under SAF.
---

# Prepare a release

1. Read the [release rules](../../../docs-ai/common/rules.md#release-versioning-and-approvals), project version declarations, relevant Git tags, and the project's release workflow. Establish the current version from those sources. Check for a tag or artifact collision at the proposed version before proceeding.
2. Propose the full version and channel. Keep major and minor unchanged unless explicitly approved or already specified by the user for this release. Within the current line use the next patch or advance the current alpha or beta iteration. Obtain explicit approval for the release channel before publishing it.
3. Prepare and verify the local release candidate. Compare the project version, intended tag, package identities, and actual changes. Prepare the public release title and body, or use the user's wording verbatim if provided.
4. Show the version, title, and full body to the user and wait for confirmation before creating a release commit, tag, push, or published release. If the user supplies replacement wording, use it verbatim. Obtain any outstanding version, channel, or publication approval in the same confirmation.
5. After approval, perform only the confirmed release actions. Verify the resulting tag and any distribution or release entry against the approved version and copy. Report any failed or pending publication separately from local preparation.
