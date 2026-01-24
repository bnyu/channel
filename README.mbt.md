# bnyu2/channel

An async FIFO channel implementation for MoonBit with bounded(buffered and rendezvous) and unbounded modes. Inspired by Golang.

## Features

- Bounded and unbounded modes for different workloads
- Async `send`/`receive` with backpressure
- Non-blocking `try_send`/`try_receive` for fast paths
- Explicit close with clear error signaling
- Asynchronous runtime independent

## Installation

Add this package to your MoonBit project and import it from your code.

```bash
moon add bnyu2/channel
```

## Usage

```moonbit
///|
fn run_async(f : async () -> Unit noraise) = "%async.run"

///|
fn main {
  let chan = @channel.Channel::new(capacity=2)

  // non-blocking send/receive
  let _ = chan.try_send(0)
  let _ = chan.try_send(1)
  let r = chan.try_receive().unwrap()
  println("try received: \{r}") // 0 FIFO

  // async send/receive
  run_async(fn() {
    println("async receiving")
    try {
      let r = chan.receive()
      println(r) // 1
      let r = chan.receive()
      println(r) // 2
      let r = chan.receive()
      println(r) // 3
      let r = chan.receive()
      println(r) // 4
      let r = chan.receive()
      println(r) // 5
      let r = chan.receive()
      println(r) // should not reach here
    } catch {
      e => println("receive error: \{e}")
    }
  })
  run_async(fn() {
    println("async sending")
    try {
      chan.send(2)
      chan.send(3)
      chan.send(4)
      chan.send(5)
      chan.close()
      println("channel closed")
    } catch {
      _ => panic()
    }
  })
}
```

## Run Demo

```bash
moon run --target wasm-gc examples/demo
```

## API Summary

- `Channel::new(capacity? : Int = 0)`
	- `capacity = -1` for unbounded channels, equal `Channel::unbound()`
	- `capacity >= 0` for bounded channels (capacity = 0 is rendezvous channel), equal `Channel::bound(capacity)`
- `Channel::try_send(data)` → `Result[Unit, TrySendError]`
- `Channel::try_receive()` → `Result[T, TryRecvError]`
- `Channel::send(data)` / `Channel::receive()` (async)
- `Channel::close()` / `Channel::is_closed()`

## License

Apache-2.0 license
