package transport

import (
	"bytes"
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/masterzen/winrm"

	"github.com/henrikhalt/terraform-provider-dryad/internal/config"
)

type winrmRunner struct {
	newClient func() (*winrm.Client, error)
	endpoint  string
	auth      string
}

// winrmAuthAttempts covers transient 401s: NTLM authenticates a connection, and the
// server closes connections between operations, so a stale pooled connection can be
// rejected. A 401 means the script never ran, so retrying is safe.
const winrmAuthAttempts = 3

func NewWinRMRunner(cfg config.Config) (Runner, error) {
	endpoint := winrm.NewEndpoint(
		cfg.Host,
		cfg.Port,
		cfg.WinRMUseTLS,
		cfg.Insecure,
		nil,
		nil,
		nil,
		cfg.Timeout,
	)

	// DefaultParameters is a package-level pointer; copy it before mutating.
	params := *winrm.DefaultParameters
	switch strings.ToLower(cfg.WinRMAuth) {
	case "", "basic":
	case "ntlm":
		params.TransportDecorator = func() winrm.Transporter {
			return &winrm.ClientNTLM{}
		}
	case "kerberos":
		proto := "http"
		if cfg.WinRMUseTLS {
			proto = "https"
		}

		spn := cfg.WinRMKerberosSPN
		if spn == "" {
			spn = fmt.Sprintf("HTTP/%s", cfg.Host)
		}

		params.TransportDecorator = func() winrm.Transporter {
			return &winrm.ClientKerberos{
				Username:  cfg.Username,
				Password:  cfg.Password,
				Realm:     cfg.WinRMKerberosRealm,
				Hostname:  cfg.Host,
				Port:      cfg.Port,
				Proto:     proto,
				SPN:       spn,
				KrbConf:   cfg.WinRMKerberosConfig,
				KrbCCache: cfg.WinRMKerberosCCache,
			}
		}
	default:
		return nil, fmt.Errorf("unsupported WinRM auth %q", cfg.WinRMAuth)
	}

	newClient := func() (*winrm.Client, error) {
		client, err := winrm.NewClientWithParameters(endpoint, cfg.Username, cfg.Password, &params)
		if err != nil {
			return nil, fmt.Errorf("creating WinRM client: %w", err)
		}

		return client, nil
	}

	if _, err := newClient(); err != nil {
		return nil, err
	}

	scheme := "http"
	if cfg.WinRMUseTLS {
		scheme = "https"
	}

	auth := strings.ToLower(cfg.WinRMAuth)
	if auth == "" {
		auth = "basic"
	}

	return &winrmRunner{
		newClient: newClient,
		endpoint:  fmt.Sprintf("%s://%s:%d/wsman", scheme, cfg.Host, cfg.Port),
		auth:      auth,
	}, nil
}

func (r *winrmRunner) Run(ctx context.Context, command string, stdin string) (Result, error) {
	var lastResult Result
	var lastErr error

	for attempt := 1; attempt <= winrmAuthAttempts; attempt++ {
		result, err := r.run(ctx, command, stdin)
		if err == nil || !isAuthFailure(err) {
			return result, err
		}

		lastResult, lastErr = result, err

		if attempt == winrmAuthAttempts {
			break
		}

		select {
		case <-ctx.Done():
			return result, ctx.Err()
		case <-time.After(time.Duration(attempt) * time.Second):
		}
	}

	return lastResult, fmt.Errorf("winrm authentication failed against %s using %s auth after %d attempts: %w", r.endpoint, r.auth, winrmAuthAttempts, lastErr)
}

func (r *winrmRunner) run(ctx context.Context, command string, stdin string) (Result, error) {
	// A fresh client per attempt gets a fresh connection pool.
	client, err := r.newClient()
	if err != nil {
		return Result{}, err
	}

	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode, err := client.RunWithContextWithInput(ctx, command, &stdout, &stderr, strings.NewReader(stdin))
	result := Result{
		Stdout:   stdout.String(),
		Stderr:   stderr.String(),
		ExitCode: exitCode,
	}

	if err != nil {
		if isAuthFailure(err) {
			return result, err
		}

		return result, fmt.Errorf("winrm request to %s failed: %w", r.endpoint, err)
	}

	return result, nil
}

func isAuthFailure(err error) bool {
	return err != nil && strings.Contains(err.Error(), "401")
}
