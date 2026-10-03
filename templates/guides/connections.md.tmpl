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

If SSH flakiness persists, giving the domain controller more CPU/RAM is usually the most
effective fix — the slow runs tend to cluster when the host is busy with replication or
Group Policy processing.

## Timeouts

`timeout_seconds` (default 30) bounds both the connection and each remote command. A
command that never returns — a stuck session, for example — fails after the timeout
instead of blocking the apply indefinitely. Group Policy imports over SSH are the slowest
operations; raise `timeout_seconds` if you import large GPOs against a loaded host.

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
