// Package password generates random passwords for newly created Active Directory
// accounts. Generation happens client-side in Go rather than in the remote PowerShell
// script: it needs no AD access, and keeping it here makes it unit-testable without a
// live domain controller.
package password

import (
	"crypto/rand"
	"fmt"
	"math/big"
)

const (
	lower   = "abcdefghijklmnopqrstuvwxyz"
	upper   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	digits  = "0123456789"
	symbols = "!@#$%^&*()-_=+[]{}<>?"
)

// Generate returns a cryptographically random password of the given length, containing
// at least one character from each of lower, upper, digit and symbol classes so it
// satisfies Active Directory's default password complexity policy.
func Generate(length int) (string, error) {
	classes := []string{lower, upper, digits, symbols}
	if length < len(classes) {
		return "", fmt.Errorf("password length must be at least %d, got %d", len(classes), length)
	}

	all := lower + upper + digits + symbols
	result := make([]byte, length)

	// Guarantee one character from each class first, then fill the rest from the
	// combined set, then shuffle so the guaranteed characters are not always at the
	// front of the string.
	for i, class := range classes {
		c, err := randomChar(class)
		if err != nil {
			return "", err
		}
		result[i] = c
	}

	for i := len(classes); i < length; i++ {
		c, err := randomChar(all)
		if err != nil {
			return "", err
		}
		result[i] = c
	}

	if err := shuffle(result); err != nil {
		return "", err
	}

	return string(result), nil
}

func randomChar(set string) (byte, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(int64(len(set))))
	if err != nil {
		return 0, fmt.Errorf("generating random index: %w", err)
	}

	return set[n.Int64()], nil
}

// shuffle performs a cryptographically random Fisher-Yates shuffle in place.
func shuffle(b []byte) error {
	for i := len(b) - 1; i > 0; i-- {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(i+1)))
		if err != nil {
			return fmt.Errorf("shuffling password: %w", err)
		}

		j := n.Int64()
		b[i], b[j] = b[j], b[i]
	}

	return nil
}
