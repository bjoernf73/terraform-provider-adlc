package ad

import (
	"context"

	"github.com/henrikhalt/terraform-provider-dryad/internal/client"
)

const (
	gpRegistryPolicyParser = "gpregistrypolicyparser.ps1"
	jsonGPOCommon          = "json_gpo_common.ps1"
	jsonGPOEnsure          = "json_gpo_ensure.ps1"
)

type JsonGPOInput struct {
	TargetName   string
	JSON         string
	Replacements map[string]string
}

func (i JsonGPOInput) payload() map[string]any {
	return map[string]any{
		"target_name":  i.TargetName,
		"json_raw":     i.JSON,
		"replacements": i.Replacements,
	}
}

// JsonGPO mirrors BackupGPO: both import into an ordinary GPO, so Read/Delete and the
// version-drift watermark are identical - see ReadBackupGPO/DeleteBackupGPO, reused here
// via the shared backup_gpo_common.ps1/backup_gpo_read.ps1/backup_gpo_delete.ps1 scripts.
type JsonGPO struct {
	Exists            bool   `json:"exists"`
	GUID              string `json:"guid"`
	Name              string `json:"name"`
	DistinguishedName string `json:"distinguished_name"`
	Domain            string `json:"domain"`
	Status            string `json:"status"`

	ComputerADVersion     int64 `json:"computer_ad_version"`
	ComputerSysvolVersion int64 `json:"computer_sysvol_version"`
	UserADVersion         int64 `json:"user_ad_version"`
	UserSysvolVersion     int64 `json:"user_sysvol_version"`
}

// EnsureJsonGPO imports a JSON GPO into the target GPO, creating it if needed.
// Re-running it against an existing target overwrites its SYSVOL content in place,
// preserving the target's GUID and links, so it also serves as the update path.
func EnsureJsonGPO(ctx context.Context, c *client.Client, input JsonGPOInput) (*JsonGPO, error) {
	script, err := buildScript(c, input.payload(), commonScript, backupGPOCommon, gpRegistryPolicyParser, jsonGPOCommon, jsonGPOEnsure)
	if err != nil {
		return nil, err
	}

	var result JsonGPO
	if err := c.RunPowerShellJSON(ctx, script, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

func ReadJsonGPO(ctx context.Context, c *client.Client, guid string) (*JsonGPO, error) {
	script, err := buildScript(c, map[string]any{
		"guid": guid,
	}, commonScript, backupGPOCommon, backupGPORead)
	if err != nil {
		return nil, err
	}

	var result JsonGPO
	if err := c.RunPowerShellJSON(ctx, script, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

func DeleteJsonGPO(ctx context.Context, c *client.Client, guid string) error {
	script, err := buildScript(c, map[string]any{
		"guid": guid,
	}, commonScript, backupGPOCommon, backupGPODelete)
	if err != nil {
		return err
	}

	var result map[string]any
	return c.RunPowerShellJSON(ctx, script, &result)
}
