# Publishing

The module is published to the PowerShell Gallery by the tag-gated `.github/workflows/publish.yml`.

## Release steps

1. Bump `ModuleVersion` in `src/MyWebApi/MyWebApi.psd1`.
2. Update release notes in the manifest `PrivateData.PSData.ReleaseNotes`.
3. Commit, then tag: `git tag v0.1.0 && git push --tags` (push only after the remote is approved).
4. The `publish.yml` workflow restores `lib/`, runs `build.ps1`, and calls `Publish-PSResource` using the `PSGALLERY_API_KEY` secret from the `psgallery` environment.

## First-time setup

- Create a PowerShell Gallery account, generate an API key scoped to publish.
- Store it as the `PSGALLERY_API_KEY` secret in the GitHub `psgallery` environment.
