package pass

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/1800alex/webpass/utils/exec"
)

type DiskStore struct {
	path         string
	syncInterval time.Duration

	gitMu  sync.Mutex
	ctx    context.Context
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

func NewStore(path string, syncInterval time.Duration) Store {
	return &DiskStore{path: path, syncInterval: syncInterval}
}

func NewDefaultStore() Store {
	return NewStore(defaultStorePath(), 5*time.Minute)
}

//  git clone git@softserve:icecream1.git /home/test/.password-store

func defaultStorePath() string {
	if path := os.Getenv("PASSWORD_STORE_DIR"); path != "" {
		return path
	}
	return filepath.Join(os.Getenv("HOME"), ".password-store")
}

func (s *DiskStore) Path() string {
	return s.path
}

func (s *DiskStore) Exists(item string) bool {
	_, err := os.Stat(filepath.Join(s.path, item))
	return err == nil
}

func (s *DiskStore) Init(ctx context.Context) error {
	s.ctx, s.cancel = context.WithCancel(ctx)

	s.wg.Add(1)
	go func() {
		defer s.wg.Done()

		s.Sync()

		for {
			select {
			case <-s.ctx.Done():
				return
			case <-time.After(s.syncInterval):
				s.Sync()
			}
		}
	}()

	return nil
}

func (s *DiskStore) Sync() error {
	s.gitMu.Lock()
	defer s.gitMu.Unlock()

	res := s.git([]string{"pull"}...)

	return res.Err
}

func (s *DiskStore) List() ([]string, error) {
	var list []string

	err := filepath.Walk(s.path, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if path == s.path {
			return nil
		}
		if name := info.Name(); len(name) > 0 && name[0] == '.' {
			if info.IsDir() {
				return filepath.SkipDir
			} else {
				return nil
			}
		}
		if info.IsDir() {
			return nil
		}

		item, err := filepath.Rel(s.path, path)
		if err != nil {
			return err
		}

		list = append(list, item)
		return nil
	})

	return list, err
}

func (s *DiskStore) itemPath(item string) (string, error) {
	p := filepath.Join(s.path, item)
	if !filepath.HasPrefix(p, s.path) {
		// Make sure the requested item is *in* the password store
		return "", errors.New("invalid item path")
	}
	return p, nil
}

func (s *DiskStore) Open(item string) (io.ReadCloser, error) {
	p, err := s.itemPath(item)
	if err != nil {
		return nil, err
	}

	f, err := os.Open(p)
	if os.IsNotExist(err) {
		return nil, ErrNotFound
	}
	return f, err
}

func (s *DiskStore) Decrypt(item string, passphrase string) (string, error) {
	p, err := s.itemPath(item)
	if err != nil {
		return "", err
	}

	_, err = os.Stat(p)
	if err != nil {
		return "", err
	}

	result := exec.WithStdin(fmt.Sprintf("gpg --pinentry-mode loopback --passphrase-fd 0 -d \"%q\"", p), passphrase)
	if result.Err != nil {
		fmt.Println("result.Err", result.Err)
		fmt.Println("result.Stdout", result.Stdout)
		fmt.Println("result.Stderr", result.Stderr)
		return "", result.Err
	}

	return result.Stdout, nil
}

func (s *DiskStore) Create(item string) (io.WriteCloser, error) {
	p, err := s.itemPath(item)
	if err != nil {
		return nil, err
	}

	return os.Create(p)
}

func (s *DiskStore) git(args ...string) exec.Result {
	s.gitMu.Lock()
	defer s.gitMu.Unlock()
	return exec.WithStdin(fmt.Sprintf("git -C \"%s\" %s", s.path, strings.Join(args, " ")), "")
}
