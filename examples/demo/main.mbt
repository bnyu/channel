///|
fn run_async(f : async () -> Unit noraise) = "%async.run"

///|
fn main {
  let chan = @channel.Channel::new(capacity=2)

  // non-blocking send/receive
  let _ = chan.try_send(0)
  let _ = chan.try_send(1)
  let r = chan.try_receive().unwrap()
  println("try received: \{r}") // 0 (FIFO)

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
