package ad

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
)

// LoadBackupGPOFiles reads every file under rootPath/backupName recursively, on the
// machine running Terraform, and returns them relative to that folder with forward
// slashes, ready to embed in the ensure payload. The folder is a GPMC backup set: it
// contains one or more {GUID} subfolders, each a single Backup-GPO snapshot.
func LoadBackupGPOFiles(rootPath, backupName string) ([]BackupGPOFile, error) {
	base := filepath.Join(rootPath, backupName)

	info, err := os.Stat(base)
	if err != nil {
		return nil, fmt.Errorf("reading backup GPO folder %q: %w", base, err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("%q is not a directory", base)
	}

	var files []BackupGPOFile
	err = filepath.WalkDir(base, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		rel, err := filepath.Rel(base, p)
		if err != nil {
			return err
		}

		content, err := os.ReadFile(p)
		if err != nil {
			return fmt.Errorf("reading %q: %w", p, err)
		}

		files = append(files, BackupGPOFile{
			Path:    filepath.ToSlash(rel),
			Content: base64.StdEncoding.EncodeToString(content),
		})
		return nil
	})
	if err != nil {
		return nil, err
	}

	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
	return files, nil
}

// HashBackupGPOContent fingerprints the files and migration table that will be sent to
// Import-GPO. The resource plans a re-import whenever this changes, which is how local
// edits to the backup folder or the migrations block are detected: the folder itself is
// not a Terraform-managed value Terraform can diff on its own.
func HashBackupGPOContent(files []BackupGPOFile, migrations []BackupGPOMigration) string {
	sortedFiles := append([]BackupGPOFile(nil), files...)
	sort.Slice(sortedFiles, func(i, j int) bool { return sortedFiles[i].Path < sortedFiles[j].Path })

	sortedMigrations := append([]BackupGPOMigration(nil), migrations...)
	sort.Slice(sortedMigrations, func(i, j int) bool {
		if sortedMigrations[i].Source != sortedMigrations[j].Source {
			return sortedMigrations[i].Source < sortedMigrations[j].Source
		}
		return sortedMigrations[i].Destination < sortedMigrations[j].Destination
	})

	h := sha256.New()
	for _, f := range sortedFiles {
		io.WriteString(h, f.Path)
		h.Write([]byte{0})
		io.WriteString(h, f.Content)
		h.Write([]byte{0})
	}
	for _, m := range sortedMigrations {
		io.WriteString(h, m.Source)
		h.Write([]byte{0})
		io.WriteString(h, m.Destination)
		h.Write([]byte{0})
		if m.SameAsSource {
			h.Write([]byte{1})
		}
		h.Write([]byte{0})
		io.WriteString(h, m.Type)
		h.Write([]byte{0})
	}

	return hex.EncodeToString(h.Sum(nil))
}
