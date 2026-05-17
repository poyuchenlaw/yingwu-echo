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
