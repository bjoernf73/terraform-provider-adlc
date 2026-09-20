package ad

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"sort"
)

// LoadJsonGPOFile reads the JSON GPO file from rootPath, on the machine running
// Terraform, as-is (no parsing): the free-text ####key#### replacements run against the
// raw text before it is ever parsed as JSON, both here and on re-import.
func LoadJsonGPOFile(path string) (string, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("reading json GPO file %q: %w", path, err)
	}

	return string(content), nil
}

// HashJsonGPOContent fingerprints the JSON file and replacements that will be sent to
// Ensure. The resource plans a re-import whenever this changes, since the file itself is
// not a Terraform-managed value Terraform can diff on its own - same reasoning as
// HashBackupGPOContent.
func HashJsonGPOContent(json string, replacements map[string]string) string {
	keys := make([]string, 0, len(replacements))
	for k := range replacements {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	h := sha256.New()
	h.Write([]byte(json))
	h.Write([]byte{0})
	for _, k := range keys {
		h.Write([]byte(k))
		h.Write([]byte{0})
		h.Write([]byte(replacements[k]))
		h.Write([]byte{0})
	}

	return hex.EncodeToString(h.Sum(nil))
}
