package powershell

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/bjoernf73/terraform-provider-adlc/internal/config"
	"github.com/bjoernf73/terraform-provider-adlc/internal/transport"
)

// Probe emits a one-line JSON marker that identifies the edition that ran it. If the
// script body never executes (the stdin-delivery bug), stdout is empty and exit is 0.
const stdinProbeScript = `[pscustomobject]@{ ok = $true; edition = $PSVersionTable.PSEdition } | ConvertTo-Json -Compress`

// Candidate bootstraps that read the gzipped+base64 script from stdin. The current
// production bootstrap uses [Console]::In.ReadToEnd(), which returns "" under
// powershell.exe over WinRM (wsmprovhost). The candidates read the raw standard-input
// stream instead.
const stdinBootstrapOpenStandardInput = `$ErrorActionPreference='Stop';` +
	`if($null -ne $PSStyle){$PSStyle.OutputRendering='PlainText'};` +
	`$sr=New-Object System.IO.StreamReader([Console]::OpenStandardInput(),[System.Text.Encoding]::ASCII);` +
	`$encoded=$sr.ReadToEnd();` +
	`$bytes=[System.Convert]::FromBase64String($encoded.Trim());` +
	`$stream=New-Object System.IO.MemoryStream(,$bytes);` +
	`$gzip=New-Object System.IO.Compression.GZipStream($stream,[System.IO.Compression.CompressionMode]::Decompress);` +
	`$reader=New-Object System.IO.StreamReader($gzip,[System.Text.Encoding]::UTF8);` +
	`$script=$reader.ReadToEnd();$reader.Close();` +
	`Invoke-Expression $script`

const stdinBootstrapInputVar = `$ErrorActionPreference='Stop';` +
	`if($null -ne $PSStyle){$PSStyle.OutputRendering='PlainText'};` +
	`$encoded=($input | Out-String);` +
	`$bytes=[System.Convert]::FromBase64String($encoded.Trim());` +
	`$stream=New-Object System.IO.MemoryStream(,$bytes);` +
	`$gzip=New-Object System.IO.Compression.GZipStream($stream,[System.IO.Compression.CompressionMode]::Decompress);` +
	`$reader=New-Object System.IO.StreamReader($gzip,[System.Text.Encoding]::UTF8);` +
	`$script=$reader.ReadToEnd();$reader.Close();` +
	`Invoke-Expression $script`

func buildBootstrapCommand(powerShellPath, bootstrap string) string {
	return fmt.Sprintf(`"%s" -NoLogo -NoProfile -NonInteractive -EncodedCommand %s`, powerShellPath, encodeUTF16LEBase64(bootstrap))
}

func reproRunner(t *testing.T) transport.Runner {
	t.Helper()

	host := os.Getenv("ADLC_HOST")
	if host == "" {
		t.Skip("ADLC_HOST not set")
	}

	port := 5985
	if raw := os.Getenv("ADLC_PORT"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil {
			t.Fatalf("invalid ADLC_PORT: %v", err)
		}
		port = parsed
	}

	auth := os.Getenv("ADLC_WINRM_AUTH")
	if auth == "" {
		auth = "ntlm"
	}

	cfg := config.Config{
		Host:               host,
		Port:               port,
		Transport:          "winrm",
		Username:           os.Getenv("ADLC_USERNAME"),
		Password:           os.Getenv("ADLC_PASSWORD"),
		Insecure:           os.Getenv("ADLC_INSECURE") == "true",
		PowerShellPath:     "pwsh",
		Timeout:            30 * time.Second,
		WinRMUseTLS:        os.Getenv("ADLC_WINRM_USE_TLS") == "true",
		WinRMAuth:          auth,
		WinRMKerberosRealm: os.Getenv("ADLC_WINRM_KERBEROS_REALM"),
	}

	runner, err := transport.NewWinRMRunner(cfg)
	if err != nil {
		t.Fatalf("creating runner: %v", err)
	}

	return runner
}

func reproSSHRunner(t *testing.T) transport.Runner {
	t.Helper()

	host := os.Getenv("ADLC_HOST")
	if host == "" {
		t.Skip("ADLC_HOST not set")
	}
	if os.Getenv("ADLC_PASSWORD") == "" {
		t.Skip("ADLC_PASSWORD not set; SSH repro needs password auth")
	}

	port := 22
	if raw := os.Getenv("ADLC_SSH_PORT"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil {
			t.Fatalf("invalid ADLC_SSH_PORT: %v", err)
		}
		port = parsed
	}

	cfg := config.Config{
		Host:           host,
		Port:           port,
		Transport:      "ssh",
		Username:       os.Getenv("ADLC_USERNAME"),
		Password:       os.Getenv("ADLC_PASSWORD"),
		Insecure:       true, // test only: skip host key verification
		PowerShellPath: "pwsh",
		Timeout:        30 * time.Second,
	}

	runner, err := transport.NewSSHRunner(cfg)
	if err != nil {
		t.Fatalf("creating ssh runner: %v", err)
	}

	return runner
}

// TestSSHStdinRepro is the critical cross-transport check: over SSH (the Mac's likely
// original path), does powershell.exe read the gzipped script from stdin? Compares the
// current [Console]::In bootstrap against the [Console]::OpenStandardInput() candidate.
func TestSSHStdinRepro(t *testing.T) {
	runner := reproSSHRunner(t)

	stdin, err := EncodeScript(stdinProbeScript)
	if err != nil {
		t.Fatalf("encoding probe: %v", err)
	}

	cases := []struct {
		name      string
		shell     string
		bootstrap string
	}{
		{"pwsh/console-in (current)", "pwsh", stdinBootstrap},
		{"powershell.exe/console-in (current)", "powershell.exe", stdinBootstrap},
		{"powershell.exe/open-standard-input", "powershell.exe", stdinBootstrapOpenStandardInput},
		{"pwsh/open-standard-input", "pwsh", stdinBootstrapOpenStandardInput},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			command := buildBootstrapCommand(tc.shell, tc.bootstrap)
			result, err := runner.Run(context.Background(), command, stdin)
			t.Logf("exit=%d stdout=%q stderr=%q err=%v", result.ExitCode, result.Stdout, result.Stderr, err)
		})
	}
}

// TestWinRMStdinRepro drives the real production bootstrap and the candidate bootstraps
// over the live WinRM connection under both PowerShell editions, so we can see exactly
// which stdin-reading method survives powershell.exe (wsmprovhost).
func TestWinRMStdinRepro(t *testing.T) {
	runner := reproRunner(t)

	stdin, err := EncodeScript(stdinProbeScript)
	if err != nil {
		t.Fatalf("encoding probe: %v", err)
	}

	cases := []struct {
		name      string
		shell     string
		bootstrap string
	}{
		{"pwsh/console-in (current)", "pwsh", stdinBootstrap},
		{"powershell.exe/console-in (current)", "powershell.exe", stdinBootstrap},
		{"powershell.exe/open-standard-input", "powershell.exe", stdinBootstrapOpenStandardInput},
		{"powershell.exe/input-var", "powershell.exe", stdinBootstrapInputVar},
		{"pwsh/open-standard-input", "pwsh", stdinBootstrapOpenStandardInput},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			command := buildBootstrapCommand(tc.shell, tc.bootstrap)
			result, err := runner.Run(context.Background(), command, stdin)
			t.Logf("exit=%d stdout=%q stderr=%q err=%v", result.ExitCode, result.Stdout, result.Stderr, err)
		})
	}
}

// TestWinRMStdinLargeScript rules out a size-related stdin truncation under powershell.exe:
// real GPO scripts are tens of KB, far larger than the trivial probe. It pads the probe
// with a large comment and confirms the full script still round-trips.
func TestWinRMStdinLargeScript(t *testing.T) {
	runner := reproRunner(t)

	// ~64 KB of filler comment ahead of the probe so the gzipped stdin payload is large.
	padding := strings.Repeat("# filler line to grow the script payload past any small stdin buffer\n", 1000)
	script := padding + stdinProbeScript

	stdin, err := EncodeScript(script)
	if err != nil {
		t.Fatalf("encoding probe: %v", err)
	}
	t.Logf("script bytes=%d gzip+base64 stdin bytes=%d", len(script), len(stdin))

	for _, shell := range []string{"pwsh", "powershell.exe"} {
		shell := shell
		t.Run(shell, func(t *testing.T) {
			command := buildBootstrapCommand(shell, stdinBootstrap)
			result, err := runner.Run(context.Background(), command, stdin)
			t.Logf("exit=%d stdout=%q stderr=%q err=%v", result.ExitCode, result.Stdout, result.Stderr, err)
		})
	}
}

// TestWinRMGroupPolicyEdition compares the GroupPolicy module natively under powershell.exe
// against the Windows PowerShell Compatibility layer under pwsh, over the live connection.
// This is the real use case behind the GPO trouble.
func TestWinRMGroupPolicyEdition(t *testing.T) {
	runner := reproRunner(t)

	script := `$ErrorActionPreference='Stop';` +
		`Import-Module GroupPolicy -ErrorAction Stop;` +
		`$g = Get-GPO -All | Select-Object -First 1;` +
		`[pscustomobject]@{ edition=$PSVersionTable.PSEdition; name=$g.DisplayName; computerVersion=$g.Computer.DSVersion; userVersion=$g.User.DSVersion } | ConvertTo-Json -Compress`

	stdin, err := EncodeScript(script)
	if err != nil {
		t.Fatalf("encoding probe: %v", err)
	}

	for _, shell := range []string{"pwsh", "powershell.exe"} {
		shell := shell
		t.Run(shell, func(t *testing.T) {
			command := buildBootstrapCommand(shell, stdinBootstrap)
			result, err := runner.Run(context.Background(), command, stdin)
			t.Logf("exit=%d stdout=%q stderr=%q err=%v", result.ExitCode, result.Stdout, result.Stderr, err)
		})
	}
}
