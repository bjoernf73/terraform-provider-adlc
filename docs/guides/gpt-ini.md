---
page_title: "Group Policy versions and GPT.INI"
subcategory: "Guides"
description: |-
  How a GPO's version is stored in AD and SYSVOL, why the two must stay equal, how the
  computer and user versions are packed into one number, and why GPT.INI must be UTF-8
  without a BOM.
---

# Group Policy versions and GPT.INI

Every Group Policy Object carries a **version number** the Group Policy engine uses to decide
whether a client needs to re-apply it. That number is stored in **two places that must agree**:

- **Active Directory** — the `versionNumber` attribute on the GPO's `groupPolicyContainer`
  object (`CN={GUID},CN=Policies,CN=System,DC=...`).
- **SYSVOL** — the `Version` entry in `GPT.INI` at the root of the GPO's policy folder
  (`\\<domain>\SysVol\<domain>\Policies\{GUID}\GPT.INI`).

GPMC shows both side by side — `Computer version: N (AD), N (SYSVOL)`. When they diverge, GPMC
flags a version mismatch and clients can skip or mis-apply the policy.

## GPT.INI format

A standard `GPT.INI` is a tiny INI file with one section and one key:

```ini
[General]
Version=65537
```

That is the complete, correct content for a domain GPO. **No settings live in GPT.INI** — the
actual policy is in separate files (`Machine\Registry.pol`, `User\Registry.pol`,
`Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf`, GPP XML, scripts, and so on). `GPT.INI` is
only the version watermark.

## The version is a single packed number

`Version` is **one 32-bit integer** that packs two 16-bit counters:

- the **low 16 bits** are the **computer** version
- the **high 16 bits** are the **user** version

```text
Version = userVersion * 65536 + computerVersion
```

To read the two halves back out:

```powershell
$computerVersion = $Version % 65536                  # low word
$userVersion     = [math]::Floor($Version / 65536)   # high word
```

| computer | user | packed `Version` |
| --- | --- | --- |
| 1 | 0 | 1 |
| 9 | 0 | 9 |
| 0 | 1 | 65536 |
| 1 | 1 | 65537 |
| 19 | 19 | 1245203 |

A small number like `9` is therefore correct for a machine-only GPO (computer 9, user 0); the
number only grows past `65535` once the user side has been edited.

## AD and SYSVOL hold the same number

The `GPT.INI` `Version` is **the same value** as the AD `versionNumber` attribute — not a
derived or separate number. `adlc_json_gpo` keeps them in lockstep: when it writes new SYSVOL
content it reads the current `versionNumber` from AD, raises the side whose settings changed
(a computer-side change is `+1`, a user-side change is `+65536`), writes the new value back to
`versionNumber`, and writes the identical number into `GPT.INI`. That bump is what makes clients
re-apply the GPO on the next `gpupdate`.

`adlc_backup_gpo` leaves this to `Import-GPO`, which writes both the AD attribute and `GPT.INI`
itself.

## GPT.INI must be UTF-8 **without** a BOM

This is the part that silently breaks things. `GPT.INI` must be plain **UTF-8 without a byte
order mark**. If the file is written with a BOM (the three bytes `EF BB BF` at the start), the
Group Policy engine cannot parse the leading `[General]` line, so it reads the **SYSVOL version
as `0`**.

The AD `versionNumber` is unaffected — it is an attribute, not the file — so you end up with a
permanent split that GPMC reports as, for example:

```text
Computer version: 17 (AD), 0 (SYSVOL)
```

Because AD and SYSVOL no longer match, the GPO looks perpetually out of date, and in Terraform it
surfaces as a never-settling diff on `computer_sysvol_version` / `user_sysvol_version` (they keep
reading `0`). The fix is simply to write `GPT.INI` without a BOM, which is what this provider
does.
