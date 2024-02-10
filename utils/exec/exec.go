package exec

import (
	"bytes"
	"fmt"
	"io"
	osExec "os/exec"
)

// Result contains the result of executing a command
type Result struct {
	Stdout string
	Stderr string
	Err    error
}

// WithStdin executes a shell command and captures stdout and stderr
func WithStdin(command string, stdin string) Result {
	// Create a new command to execute
	cmd := osExec.Command("sh", "-c", command)

	// Create pipes for capturing stdout and stderr
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return Result{Err: fmt.Errorf("error creating stdout pipe: %v", err)}
	}
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return Result{Err: fmt.Errorf("error creating stderr pipe: %v", err)}
	}

	stdinWriter, err := cmd.StdinPipe()
	if err != nil {
		return Result{Err: fmt.Errorf("error getting stdin pipe: %v", err)}
	}

	// Start the command
	if err := cmd.Start(); err != nil {
		return Result{Err: fmt.Errorf("error starting command: %v", err)}
	}

	// Write stdin to the command's stdin
	if stdin != "" {
		_, err = io.WriteString(stdinWriter, stdin)
		if err != nil {
			return Result{Err: fmt.Errorf("error writing to stdin: %v", err)}
		}
	}
	stdinWriter.Close()

	// Capture stdout and stderr separately
	var stdoutBuf, stderrBuf bytes.Buffer
	go io.Copy(&stdoutBuf, stdoutPipe)
	go io.Copy(&stderrBuf, stderrPipe)

	// Wait for the command to finish
	if err := cmd.Wait(); err != nil {
		return Result{
			Stdout: stdoutBuf.String(),
			Stderr: stderrBuf.String(),
			Err:    fmt.Errorf("command finished with error: %v", err),
		}
	}

	// Return captured stdout and stderr
	return Result{
		Stdout: stdoutBuf.String(),
		Stderr: stderrBuf.String(),
	}
}
