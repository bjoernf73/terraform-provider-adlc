package ad

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
)

// SysvolFile is a local source file sent to the remote SYSVOL tree. Path is relative
// to the resource source directory and always uses forward slashes.
type SysvolFile struct {
	Path    string `json:"path"`
	Content string `json:"content,omitempty"`
	SHA256  string `json:"sha256"`
}

func LoadSysvolFiles(sourcePath string) ([]SysvolFile, error) {
	info, err := os.Stat(sourcePath)
	if err != nil {
		return nil, fmt.Errorf("reading source directory %q: %w", sourcePath, err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("%q is not a directory", sourcePath)
	}

	files := make([]SysvolFile, 0)
	err = filepath.WalkDir(sourcePath, func(filePath string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			return nil
		}
		if !entry.Type().IsRegular() {
			return fmt.Errorf("%q is not a regular file", filePath)
		}

		relativePath, err := filepath.Rel(sourcePath, filePath)
		if err != nil {
			return err
		}
		content, err := os.ReadFile(filePath)
		if err != nil {
			return fmt.Errorf("reading %q: %w", filePath, err)
		}
		digest := sha256.Sum256(content)
		files = append(files, SysvolFile{
			Path:    filepath.ToSlash(relativePath),
			Content: base64.StdEncoding.EncodeToString(content),
			SHA256:  hex.EncodeToString(digest[:]),
		})
		return nil
	})
	if err != nil {
		return nil, err
	}

	sort.Slice(files, func(left, right int) bool { return files[left].Path < files[right].Path })
	return files, nil
}

func HashSysvolFiles(files []SysvolFile) string {
	sorted := append([]SysvolFile(nil), files...)
	sort.Slice(sorted, func(left, right int) bool { return sorted[left].Path < sorted[right].Path })

	hash := sha256.New()
	for _, file := range sorted {
		hash.Write([]byte(file.Path))
		hash.Write([]byte{0})
		hash.Write([]byte(file.SHA256))
		hash.Write([]byte{0})
	}
	return hex.EncodeToString(hash.Sum(nil))
}
