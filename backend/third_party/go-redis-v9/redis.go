package redis

import (
	"context"
	"errors"
	"time"
)

var errStubRedisUnavailable = errors.New("redis stub: client unavailable")

// Options is a minimal compatibility type for code that constructs a Redis client.
type Options struct {
	Addr     string
	Password string
	DB       int
}

// Client is a minimal offline-compatible Redis client surface.
type Client struct{}

// NewClient returns a minimal client compatible with github.com/redis/go-redis/v9.
func NewClient(_ *Options) *Client {
	return &Client{}
}

// StringSliceCmd models the result command returned by BLPop.
type StringSliceCmd struct {
	val []string
	err error
}

// Result returns the command value and error.
func (c *StringSliceCmd) Result() ([]string, error) {
	return c.val, c.err
}

// IntCmd models the result command returned by RPush.
type IntCmd struct {
	val int64
	err error
}

// Result returns the command value and error.
func (c *IntCmd) Result() (int64, error) {
	return c.val, c.err
}

// Err returns the command error.
func (c *IntCmd) Err() error {
	return c.err
}

// BLPop is a placeholder implementation for offline builds and tests.
func (c *Client) BLPop(_ context.Context, _ time.Duration, _ ...string) *StringSliceCmd {
	return &StringSliceCmd{err: errStubRedisUnavailable}
}

// RPush is a placeholder implementation for offline builds and tests.
func (c *Client) RPush(_ context.Context, _ string, _ ...interface{}) *IntCmd {
	return &IntCmd{err: errStubRedisUnavailable}
}

// --- v0.5 stub extensions (allow main.go to compile) ---

// StatusCmd is a stub mimic of go-redis StatusCmd.
type StatusCmd struct{ err error }

// Err returns the underlying error (always nil for stub).
func (s *StatusCmd) Err() error { return s.err }

// Result returns PONG when Err is nil, mirroring go-redis Ping semantics.
func (s *StatusCmd) Result() (string, error) {
	if s.err != nil {
		return "", s.err
	}
	return "PONG", nil
}

// ParseURL accepts redis://host:port[/db] and returns default Options.
// The stub does not validate the URL beyond required for compile.
func ParseURL(_ string) (*Options, error) {
	return &Options{Addr: "localhost:6379"}, nil
}

// Ping returns a successful StatusCmd (stub always healthy).
func (c *Client) Ping(_ context.Context) *StatusCmd {
	return &StatusCmd{err: nil}
}

// Close is a no-op for the stub.
func (c *Client) Close() error { return nil }
