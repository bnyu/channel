# Bench

## Run CMD

```bash
go run ./examples/bench/go.go
moon run --target native ./examples/bench/main.mbt
```

## Environment

- Hardware: Apple M4 Mac mini (24G)
- OS: macOS 15.7.3
- Go: `go1.25.5 darwin/arm64`
- MoonBit: `moon 0.1.20260123 (b4c72f8 2026-01-23)`

### Go

limit to one thread

```
bounded0_mpmc             Go chan           0.349 sec
bounded0_mpsc             Go chan           0.329 sec
bounded0_spsc             Go chan           0.335 sec
bounded1_mpmc             Go chan           0.248 sec
bounded1_mpsc             Go chan           0.250 sec
bounded1_spsc             Go chan           0.248 sec
bounded_mpmc              Go chan           0.073 sec
bounded_mpsc              Go chan           0.074 sec
bounded_seq               Go chan           0.074 sec
bounded_spsc              Go chan           0.072 sec
```

default multi threads

```
bounded0_mpmc             Go chan           0.756 sec
bounded0_mpsc             Go chan           0.990 sec
bounded0_spsc             Go chan           0.574 sec
bounded1_mpmc             Go chan           0.580 sec
bounded1_mpsc             Go chan           0.762 sec
bounded1_spsc             Go chan           0.424 sec
bounded_mpmc              Go chan           0.129 sec
bounded_mpsc              Go chan           0.100 sec
bounded_seq               Go chan           0.073 sec
bounded_spsc              Go chan           0.109 sec
```

### MoonBit Channel

with (moonbitlang/async@0.16.2) runtime

```
bounded0_mpmc             Moonbit Channel   0.243 sec
bounded0_mpsc             Moonbit Channel   0.247 sec
bounded0_spsc             Moonbit Channel   0.242 sec
bounded1_mpmc             Moonbit Channel   0.244 sec
bounded1_mpsc             Moonbit Channel   0.247 sec
bounded1_spsc             Moonbit Channel   0.244 sec
bounded_mpmc              Moonbit Channel   0.213 sec
bounded_mpsc              Moonbit Channel   0.206 sec
bounded_seq               Moonbit Channel   0.206 sec
bounded_spsc              Moonbit Channel   0.205 sec
```
