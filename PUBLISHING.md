# Publishing

The module is published to the PowerShell Gallery by the tag-gated `.github/workflows/publish.yml`.

## Release steps

1. Bump `ModuleVersion` in `src/MyWebApi/MyWebApi.psd1`, and the expected version in `ci/fixed-artifact-consumer.ps1` (the release probe refuses any other version).
2. Update release notes in the manifest `PrivateData.PSData.ReleaseNotes`.
3. Run `./build.ps1`; it must pass.
4. Open a pull request to `main` with the change and the version bump, and merge it once CI is green — `main` accepts changes only through a pull request with passing CI.
5. Tag the merged commit on `main` and push only that tag: `git tag -a v0.3.0 -m "MyWebApi 0.3.0" && git push origin v0.3.0`.
6. The `publish.yml` workflow (environment `psgallery`) checks that the tag matches the manifest (`ci/Assert-ReleaseTag.ps1`), restores `lib/`, runs `build.ps1`, builds the nupkg (`ci/Build-Release.ps1`), verifies it against the fake server (`ci/Verify-Release.ps1`), audits it (`ci/Audit-Release.ps1`: dependency vulnerabilities, gitleaks, SBOM), and pushes that exact tested nupkg with `dotnet nuget push` using the `PSGALLERY_API_KEY` secret.

## First-time setup

- Create a PowerShell Gallery account, generate an API key scoped to publish.
- Store it as the `PSGALLERY_API_KEY` secret in the GitHub `psgallery` environment.

## Release gate

- Only repository admins can create `v*` tags; nobody can move or delete one (repository rulesets), so a published version always points at the commit it was built from.
- `main` accepts changes only through a pull request whose CI passed. Merging that pull request is the review of what will be released.
- The first job of `publish.yml` (`Release gate`) refuses a tag whose commit is not on `main` or has no successful CI run; nothing is built or published then. Fix it by merging the commit into `main` and tagging the merged commit — a refused tag cannot be moved, so the next version number is used.
