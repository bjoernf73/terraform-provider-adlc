---
page_title: "Connecting over WinRM and SSH"
subcategory: "Guides"
description: |-
  How the provider reaches the Windows host: choosing a transport, configuring WinRM
  (basic, NTLM, Kerberos) and SSH (password, key), and the limitations observed with
  OpenSSH on Windows.
---

# Connecting over WinRM and SSH

Every operation the provider performs is a PowerShell command executed on a remote
Windows host. There is no native LDAP client. The provider therefore needs a working
remote-execution transport, and the host needs the `ActiveDirectory` (and, for Group
Policy, `GroupPolicy`) modules installed.

Two transports are supported, selected with `transport`:

| Transport | Mechanisms | Default port |
| --- | --- | --- |
| `winrm` | `basic`, `ntlm`, `kerberos` | 5985 (HTTP), 5986 (HTTPS) |
| `ssh` | password, private key | 22 |

As a rule of thumb: inside the domain, WinRM with Kerberos or SSH are both good. From a
runner outside the domain, prefer WinRM over **HTTPS** or SSH — never WinRM over plain
HTTP across a trust boundary.

## WinRM

### Basic

The simplest option, intended for inside-domain use over HTTP, or over HTTPS when the
host presents a trusted certificate:

```hcl
provider "adlc" {
  transport = "winrm"
  host      = "dc1.contoso.local"
  username  = "CONTOSO\\svc-adlc"
  password  = var.password
}
```

Add `winrm_use_tls = true` for HTTPS (port 5986). `insecure = true` skips certificate
validation — acceptable only for lab use; prefer a trusted certificate.

### NTLM

```hcl
provider "adlc" {
  transport  = "winrm"
  host       = "dc1.contoso.local"
  winrm_auth = "ntlm"
  username   = "CONTOSO\\svc-adlc"
  password   = var.password
}
```

NTLM authenticates per connection, and the server closes connections between operations.
A pooled connection can therefore be rejected with a transient `401`; the provider
retries these automatically (the script never ran, so a retry is safe).

### Kerberos

Kerberos needs a little more wiring because the Kerberos library the provider uses does
**not** read the Windows ticket cache — it authenticates with an explicit username,
password and realm, and it needs a `krb5.conf` file, which Windows does not ship.

```hcl
provider "adlc" {
  transport            = "winrm"
  host                 = "dc1.contoso.local"
  winrm_auth           = "kerberos"
  winrm_kerberos_realm = "CONTOSO.LOCAL"
  username             = "svc-adlc"
  password             = var.password
}
```

What you must provide:

- **`winrm_kerberos_realm`** — required. The realm is upper-cased for you, so
  `contoso.local` and `CONTOSO.LOCAL` are equivalent.
- **`password`** — required. The Windows ticket cache is not used; authentication is
  always username + password against the realm.
- **`username`** — give it bare (`svc-adlc`). A NetBIOS or UPN form
  (`CONTOSO\svc-adlc`, `svc-adlc@contoso.local`) also works; the provider strips the
  prefix/suffix, since the realm is supplied separately.

What the provider does for you:

- **Generates a `krb5.conf`** when `winrm_kerberos_config_path` is not set, using the
  realm and the target host as the KDC (`dns_lookup_kdc = true`), written to a per-realm
  temp file. On a domain-joined machine this works out of the box.
- **Defaults the SPN** to `HTTP/<host>`.

Optional overrides:

| Setting | Purpose |
| --- | --- |
| `winrm_kerberos_config_path` | Use your own `krb5.conf` instead of the generated one. |
| `winrm_kerberos_spn` | Override the service principal name (default `HTTP/<host>`). |
| `winrm_kerberos_ccache_path` | Point at an existing credential cache. |

If the host named in `host` is not itself a KDC, supply a `krb5.conf` via
`winrm_kerberos_config_path` whose `[realms]` block lists a reachable KDC.

## SSH

SSH uses the Windows OpenSSH server. Authenticate with a password or a private key:

```hcl
provider "adlc" {
  transport           = "ssh"
  host                = "dc1.contoso.local"
  username            = "svc-adlc"
  ssh_private_key_pem = var.ssh_key
}
```

Host key verification is required unless `insecure = true`. Provide the expected key
one of these ways:

| Setting | Purpose |
| --- | --- |
| `ssh_known_hosts_path` | A `known_hosts` file to verify against. |
| `ssh_host_key` | The host public key in `authorized_keys` format. |
| *(neither)* | Falls back to `~/.ssh/known_hosts` if present. |
| `insecure = true` | Skips verification entirely (lab only). |

### Observed limitations with OpenSSH on Windows

Win32-OpenSSH is noticeably less robust than WinRM for this workload, and it is worth
knowing why:

- **The command always runs under `cmd.exe`.** The Windows OpenSSH server launches the
  remote command through its configured default shell, which is `cmd.exe` unless the
  `DefaultShell` registry value is changed. The provider accounts for this: the real
  script is streamed on **stdin** (gzipped and base64-encoded) rather than placed on the
  command line, so `cmd.exe`'s ~8191-character command-line limit never applies. You do
  not need to change `DefaultShell`.
- **The stdin pipe is occasionally torn down mid-command.** Under load — or sometimes
  for no obvious reason — the server-side stdin pipe to the child process breaks. On the
  server this shows up in the *PowerShellCore/Operational* event log as
  *"An error has occurred in PowerShell IPC listening thread … The pipe has been
  ended."* This is a transport-level fault, not a provider bug, and it can fail an apply
  even when the host is otherwise idle.
- **The provider retries transport-level failures.** Dial failures, abnormal
  terminations and timeouts are retried up to three times with exponential backoff, which
  absorbs the intermittent pipe break. A *clean non-zero exit* (a genuine remote/AD
  error) is **never** retried, so non-idempotent operations are not re-run.

### Known upstream issue: intermittent connection delays

Win32-OpenSSH has a documented, still-open bug where establishing a session stalls for
**15–120 seconds** at random
([PowerShell/Win32-OpenSSH#2425](https://github.com/PowerShell/Win32-OpenSSH/issues/2425)).
The stall happens while the server spawns the `sshd-session.exe` subprocess — before the
SSH protocol or your command even starts — and it reproduces across OpenSSH 9.1, 9.2 and
10.0. Notably:

- It is **not** resource exhaustion: it occurs with CPU under 10% and RAM to spare, so
  adding CPU/RAM may not help.
- It correlates with **idle periods**: the first connection after a quiet spell is the
  slow one, then connections are fast again for a while. This matches the slow runs that
  cluster right after a bulk delete or an idle gap.
- A reported workaround is to create a local user named `sshd` on the server (see the
  linked issue and #1817); the underlying cause appears to involve an `lsass` timeout
  during subprocess creation, so a domain controller — where `lsass` is already busy —
  can feel it more.

The provider copes with this by enforcing `timeout_seconds` and retrying transport-level
failures (above). Setting `timeout_seconds` to **120** or more clears the worst of the
delay band so a stalled connect is retried rather than failing the apply.

## Timeouts

`timeout_seconds` (default 30) bounds both the connection and each remote command. A
command that never returns — a stuck session, for example — fails after the timeout
instead of blocking the apply indefinitely. Group Policy imports over SSH are the slowest
operations; raise `timeout_seconds` if you import large GPOs against a loaded host.

## Scaling to large configurations

Every operation is a separate remote PowerShell process: the provider opens a shell,
streams the script on stdin, reads the result, and closes the shell. Terraform runs these
in parallel — ten at a time by default — so a large configuration, where hundreds of
objects are refreshed on every `plan`, opens hundreds of short-lived WinRM (or SSH) shells
against a single domain controller.

The usual symptom of overload is a sporadic `dial tcp ...:5986: i/o timeout` (or a
truncated-stdin error) on one resource while the rest succeed, after which a re-run or a
serial apply works. That pattern is **concurrency contention, not bandwidth**: the payloads
are small (a few KB each, gzipped), but the number of concurrent shells and the domain
controller's WinRM limits are the real ceiling.

If you hit this on a large directory, in order of effort:

- **Lower Terraform's parallelism.** `terraform apply -parallelism=3` (or even `1`) is the
  single biggest lever and needs no configuration change. It trades wall-clock time for a
  far lower concurrent-shell count.
- **Raise `timeout_seconds`.** A busy controller answers more slowly under load;
  `timeout_seconds = 120` gives each request room before it is retried.
- **Raise the host's WinRM limits.** Inspect them with `winrm get winrm/config`; the ones
  that bite first are `MaxShellsPerUser`, `MaxConcurrentOperationsPerUser` and
  `MaxMemoryPerShellMB`. The defaults are easily exhausted by parallel applies.

The provider also retries transient transport failures automatically: network timeouts,
connection resets, dropped connections, and an undelivered script payload (empty stdin) are
retried up to three times with backoff, the same way a stale-connection `401` is. A clean
non-zero exit — a genuine Active Directory error — is never retried. Retries absorb the
occasional blip but are not a substitute for lowering parallelism on a genuinely overloaded
host.

## Troubleshooting

The provider writes diagnostic logs through Terraform's logger, not to the Windows event
log. To capture them — including SSH retry warnings — set the standard Terraform log
variables on the machine running Terraform:

```sh
export TF_LOG=DEBUG
export TF_LOG_PATH=./adlc.log
terraform apply
```

A retried SSH command logs a warning with the attempt number, the backoff and the
underlying error, so you can see whether the retry mechanism is engaging and how often.
