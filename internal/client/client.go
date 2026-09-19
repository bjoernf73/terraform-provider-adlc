package client

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/henrikhalt/terraform-provider-adlc/internal/config"
	"github.com/henrikhalt/terraform-provider-adlc/internal/powershell"
	"github.com/henrikhalt/terraform-provider-adlc/internal/transport"
)

// transientScriptErrorAttempts covers a known-transient SSPI hiccup: AD cmdlets such as
// Get-ADDomain occasionally fail with "A local error has occurred" under concurrent WinRM
// load. The client mutex should prevent this from this process; retrying is a narrow
// defense against other concurrent callers (for example two CI jobs against one DC).
const transientScriptErrorAttempts = 3

func isTransientScriptError(errText string) bool {
	return strings.Contains(errText, "A local error has occurred")
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
	command, err := powershell.BuildCommand(c.config.PowerShellPath)
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
		return fmt.Errorf("remote PowerShell returned no JSON output")
	}

	if err := json.Unmarshal([]byte(result.Stdout), target); err != nil {
		return fmt.Errorf("decoding remote JSON output: %w; output: %s", err, result.Stdout)
	}

	return nil
}
