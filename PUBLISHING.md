# Publishing

The module is published to the PowerShell Gallery by the tag-gated `.github/workflows/publish.yml`.

## Release steps

1. Bump `ModuleVersion` in `src/MyWebApi/MyWebApi.psd1`, and the expected version in `ci/fixed-artifact-consumer.ps1` (the release probe refuses any other version).
2. Update release notes in the manifest `PrivateData.PSData.ReleaseNotes`.
3. Run `./build.ps1`; it must pass.
4. Commit, then tag and push only that tag: `git tag -a v0.3.0 -m "MyWebApi 0.3.0" && git push origin v0.3.0`.
5. The `publish.yml` workflow (environment `psgallery`) checks that the tag matches the manifest (`ci/Assert-ReleaseTag.ps1`), restores `lib/`, runs `build.ps1`, builds the nupkg (`ci/Build-Release.ps1`), verifies it against the fake server (`ci/Verify-Release.ps1`), audits it (`ci/Audit-Release.ps1`: dependency vulnerabilities, gitleaks, SBOM), and pushes that exact tested nupkg with `dotnet nuget push` using the `PSGALLERY_API_KEY` secret.

## First-time setup

- Create a PowerShell Gallery account, generate an API key scoped to publish.
- Store it as the `PSGALLERY_API_KEY` secret in the GitHub `psgallery` environment.
