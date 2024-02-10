package pass

import (
	"context"
	"errors"
	"io"
)

var ErrNotFound = errors.New("pass: not found")

type Store interface {
	Init(ctx context.Context) error
	Sync() error
	Path() string
	Exists(item string) bool
	List() ([]string, error)
	Open(name string) (io.ReadCloser, error)
	Decrypt(item string, passphrase string) (string, error)
	Create(name string) (io.WriteCloser, error)
}
