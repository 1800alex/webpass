package main

import (
	"context"
	"flag"
	"os"

	"github.com/1800alex/webpass"
	"github.com/1800alex/webpass/config"
	"github.com/labstack/echo"
	"github.com/labstack/gommon/log"
)

var configPath = flag.String("config", "config.json", "path to config file")

func main() {
	flag.Parse()

	e := echo.New()
	e.Logger.SetLevel(log.DEBUG)

	addr := ":8080"
	if port := os.Getenv("PORT"); port != "" {
		addr = ":" + port
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Catch SIGIN and SIGTERM to gracefully shutdown
	go func() {
		sig := make(chan os.Signal, 1)
		<-sig
		cancel()
	}()

	cfg, err := config.Open(*configPath)
	if os.IsNotExist(err) {
		cfg = config.New()
	} else if err != nil {
		e.Logger.Fatal(err)
	}

	be, err := cfg.Backend(ctx)
	if err != nil {
		e.Logger.Fatal(err)
	}

	s := webpass.NewServer(be)
	s.Addr = addr

	e.Logger.Fatal(s.Start(e))
	<-ctx.Done()
}
