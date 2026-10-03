package client

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/bjoernf73/terraform-provider-adlc/internal/config"
	"github.com/bjoernf73/terraform-provider-adlc/internal/powershell"
	"github.com/bjoernf73/terraform-provider-adlc/internal/transport"
)

// transientScriptErrorAttempts covers a known-transient SSPI hiccup: AD cmdlets such as
// Get-ADDomain occasionally fail with "A local error has occurred" under concurrent WinRM
// load. The client mutex should prevent this from this process; retrying is a narrow
// defense against other concurrent callers (for example two CI jobs against one DC).
const transientScriptErrorAttempts = 3

func isTransientScriptError(errText string) bool {
	return strings.Contains(errText, "A local error has occurred")
}

// usesGroupPolicyModule reports whether a composed script loads the GroupPolicy module. That
// module is not native to PowerShell 7; under pwsh it loads through the Windows PowerShell
// Compatibility layer, which warns and returns deserialized objects. Such scripts run under
// the GPO PowerShell path (Windows PowerShell) instead, where the module is native.
func usesGroupPolicyModule(script string) bool {
	return strings.Contains(script, "Import-Module GroupPolicy")
}

type Client struct {
	config config.Config
	runner transport.Runner

	// mu serializes every remote operation. Terraform runs independent resources
	// concurrently (parallelism 10 by default), but concurrent WinRM shells over the
	// same NTLM-authenticated connection are unreliable and fail with errors such as
	// "A local error has occurred". ref/terraform-provider-ad works around the same
	// issue with a mutex in its provider config; we do the same rather than relying
	// on the caller to serialize calls.
	mu sync.Mutex
}

func New(cfg config.Config) (*Client, error) {
	runner, err := transport.NewRunner(cfg)
	if err != nil {
		return nil, err
	}

	return &Client{
		config: cfg,
		runner: runner,
	}, nil
}

func (c *Client) Config() config.Config {
	return c.config
}

func (c *Client) RunPowerShell(ctx context.Context, script string) (transport.Result, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	var lastResult transport.Result
	var lastErr error

	for attempt := 1; attempt <= transientScriptErrorAttempts; attempt++ {
		result, err := c.runPowerShellOnce(ctx, script)
		if err == nil || !isTransientScriptError(err.Error()) {
			return result, err
		}

		lastResult, lastErr = result, err

		if attempt == transientScriptErrorAttempts {
			break
		}

		select {
		case <-ctx.Done():
			return result, ctx.Err()
		case <-time.After(time.Duration(attempt) * time.Second):
		}
	}

	return lastResult, lastErr
}

func (c *Client) runPowerShellOnce(ctx context.Context, script string) (transport.Result, error) {
	powerShellPath := c.config.PowerShellPath
	if usesGroupPolicyModule(script) && strings.TrimSpace(c.config.GPOPowerShellPath) != "" {
		powerShellPath = c.config.GPOPowerShellPath
	}

	command, err := powershell.BuildCommand(powerShellPath)
	if err != nil {
		return transport.Result{}, err
	}

	stdin, err := powershell.EncodeScript(script)
	if err != nil {
		return transport.Result{}, err
	}

	result, err := c.runner.Run(ctx, command, stdin)
	result.Stderr = powershell.DecodeCLIXML(result.Stderr)

	if err != nil {
		return result, fmt.Errorf("running remote PowerShell: %w", err)
	}

	if result.ExitCode != 0 {
		errText := strings.TrimSpace(result.Stderr)
		if errText == "" {
			errText = strings.TrimSpace(result.Stdout)
		}

		return result, fmt.Errorf("remote PowerShell exited with code %d: %s", result.ExitCode, errText)
	}

	return result, nil
}

func (c *Client) RunPowerShellJSON(ctx context.Context, script string, target any) error {
	result, err := c.RunPowerShell(ctx, script)
	if err != nil {
		return err
	}

	if strings.TrimSpace(result.Stdout) == "" {
		// The operation scripts always emit a JSON document on success, so an empty stdout
		// means the output never came back. Surface the remote's exit code and stderr (already
		// CLIXML-decoded) instead of swallowing them, so the real cause - a GroupPolicy module
		// warning, a permissions error, or a WinRM shell being recycled under its memory quota -
		// is visible rather than hidden behind a bare "no JSON output".
		detail := strings.TrimSpace(result.Stderr)
		if detail == "" {
			detail = "nothing on stdout or stderr"
		}
		return fmt.Errorf("remote PowerShell returned no JSON output (exit code %d): %s", result.ExitCode, detail)
	}

	if err := json.Unmarshal([]byte(result.Stdout), target); err != nil {
		return fmt.Errorf("decoding remote JSON output: %w; output: %s", err, result.Stdout)
	}

	return nil
}
