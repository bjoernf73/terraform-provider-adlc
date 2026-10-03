# GPO & gpo_links — working notes

Context for Group Policy work in this provider, kept in-repo so it travels across machines.
(There is a parallel copy in this workspace's local Copilot memory on the author's Mac; this
committed file is the portable one.)

## Resources involved
- `adlc_backup_gpo` — imports a GPMC `Backup-GPO` folder via `Import-GPO`.
- `adlc_json_gpo` — rewrites SYSVOL files directly from a JSON description. Embeds Microsoft's
  `GPRegistryPolicyParser` (`internal/ad/scripts/gpregistrypolicyparser.ps1`, MIT-licensed; see
  `THIRD_PARTY_NOTICES.md`).
- `adlc_gpo_links` — authoritative set of GPO links on one OU/domain/site.
- `adlc_gpo_permission`, `adlc_gpo_security_filter`, `adlc_gpo_wmi_filter`.
- `adlc_gpo` data source — read a GPO by display name or GUID.
- Every GPO script does `Import-Module GroupPolicy`.

## FIXED: gpo_links create path (Set-GPLink vs New-GPLink)
- Symptom: linking a GPO onto an OU with no existing link failed with
  "There is no GPO with ID {..} ... Make sure that a GPLink exists ... Parameter name: Guid".
- Cause: `internal/ad/scripts/gpo_link_ensure.ps1` used `Set-GPLink` for creation. `Set-GPLink`
  only UPDATES an existing link; `New-GPLink` CREATES one.
- Fix: capture the target's existing link GUIDs (`Get-GPInheritance`) up front, then `New-GPLink`
  for links that don't exist yet and `Set-GPLink` to update existing ones. Order / LinkEnabled /
  Enforced applied the same way; authoritative removal of undeclared links unchanged.
- Coverage: `adlc_gpo_links` now exercised in `test/e2e` (ssh job) and `test/showcase`.

## FIXED: json_gpo version not bumping (user/computer version stuck at 0)
- `versionNumber` (AD) and SYSVOL `GPT.INI` `Version` pack two counters: LOW 16 bits = computer
  version, HIGH 16 bits = user version. `+1` bumps computer, `+65536` bumps user.
- Bug: `json_gpo_ensure.ps1` only bumped the version inside the REGISTRY-settings branch, so a
  GPO whose user content was GPP/scripts (not admin templates) left the user version at 0.
- Fix: track `$machineChanged` / `$userChanged` across ALL setting types (comments, registry,
  audit, security template, scripts, GPP), then bump the matching half once at the end.

## SHELVED: native GroupPolicy under Windows PowerShell (powershell.exe)
- GroupPolicy is NOT native to pwsh 7. Under pwsh it loads via the Windows PowerShell
  Compatibility layer -> warnings + DESERIALIZED objects (nested props like `Get-GPO`
  `.Computer.DSVersion` / `.User.DSVersion` can be lossy).
- v0.0.24 added `gpo_powershell_path` (default `powershell.exe`) to route GPO scripts to 5.1.
  It BROKE every GPO op over WinRM: "remote PowerShell returned no JSON output" (exit 0, empty
  stdout, NO event-log entry => the script body never ran). The bootstrap's
  `[Console]::In.ReadToEnd()` returns "" under `powershell.exe` over WinRM (wsmprovhost);
  `pwsh` reads the same piped stdin fine.
- v0.0.25 REMOVED `gpo_powershell_path` entirely; all ops use `powershell_path` (pwsh), compat
  layer accepted for now.
- Retry plan (needs a live Windows host; cannot repro from macOS): change `stdinBootstrap` in
  `internal/powershell/command.go` to read stdin via the `$input` pipeline enumerator, OR hand
  the gzipped script off via a temp file the command reads then deletes. Verify over WinRM AND
  SSH before re-adding any opt-in setting.

## Event logging (diagnostic aid)
- Every op is wrapped in a try/catch (`internal/ad/scripts.go` `buildScript`). Failures ->
  `Write-ADLCFailure` (event 1001). Mutating success -> `Write-ADLCChange` (1000). As of
  v0.0.25, read/query success -> `Write-ADLCRead` (1002). Event log name on the target:
  `terraform-provider-adlc`.
- Key signal: the ABSENCE of an event for a failed op means the script never executed (that is
  how the powershell.exe stdin bug was identified).

## Test environment (in progress)
- Plan: log onto a MEMBER SERVER as domain admin, point the provider at the DC over WinRM/5986.
  That reproduces the real transport path where the `powershell.exe` stdin bug lives (testing a
  LOCAL powershell.exe on the DC would not — it must go through WinRM).
- Credentials as env vars (`ADLC_HOST` / `ADLC_USERNAME` / `ADLC_PASSWORD`), never in chat.
- Smoke: `go test ./internal/transport -run TestWinRMSmoke -v`, or the `TF_ACC` acceptance tests.
