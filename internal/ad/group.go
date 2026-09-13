package ad

import (
	"context"
	"strings"

	"github.com/henrikhalt/terraform-provider-dryad/internal/client"
)

const (
	groupCommon = "group_common.ps1"
	groupEnsure = "group_ensure.ps1"
	groupRead   = "group_read.ps1"
	groupUpdate = "group_update.ps1"
	groupDelete = "group_delete.ps1"
)

type Group struct {
	Name              string  `json:"name"`
	SamAccountName    string  `json:"sam_account_name"`
	Description       *string `json:"description"`
	Category          string  `json:"category"`
	Scope             string  `json:"scope"`
	Path              string  `json:"path"`
	PathMatch         bool    `json:"path_match"`
	ContainerDN       string  `json:"container_dn"`
	DistinguishedName string  `json:"distinguished_name"`
	GUID              string  `json:"guid"`
	SID               string  `json:"sid"`
	Exists            bool    `json:"exists"`
}

// GroupInput carries the reconcilable attributes of a group.
type GroupInput struct {
	Name           string
	SamAccountName string
	Path           string
	Description    *string
	Category       string
	Scope          string
}

func (i GroupInput) payload() map[string]any {
	return map[string]any{
		"name":             strings.TrimSpace(i.Name),
		"sam_account_name": strings.TrimSpace(i.SamAccountName),
		"path":             NormalizePath(i.Path),
		"description":      i.Description,
		"category":         i.Category,
		"scope":            i.Scope,
	}
}

func EnsureGroup(ctx context.Context, c *client.Client, input GroupInput) (*Group, error) {
	script, err := buildScript(c, input.payload(), commonScript, groupCommon, groupEnsure)
	if err != nil {
		return nil, err
	}

	var result Group
	if err := c.RunPowerShellJSON(ctx, script, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

func ReadGroup(ctx context.Context, c *client.Client, guid string, path string) (*Group, error) {
	script, err := buildScript(c, map[string]any{
		"guid": guid,
		"path": path,
	}, commonScript, groupCommon, groupRead)
	if err != nil {
		return nil, err
	}

	var result Group
	if err := c.RunPowerShellJSON(ctx, script, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

func UpdateGroup(ctx context.Context, c *client.Client, guid string, input GroupInput) (*Group, error) {
	payload := input.payload()
	payload["guid"] = guid

	script, err := buildScript(c, payload, commonScript, groupCommon, groupUpdate)
	if err != nil {
		return nil, err
	}

	var result Group
	if err := c.RunPowerShellJSON(ctx, script, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

func DeleteGroup(ctx context.Context, c *client.Client, guid string) error {
	script, err := buildScript(c, map[string]any{
		"guid": guid,
	}, commonScript, groupCommon, groupDelete)
	if err != nil {
		return err
	}

	var result map[string]any
	return c.RunPowerShellJSON(ctx, script, &result)
}
