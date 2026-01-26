///|
const MESSAGES : Int = 5 * 1000 * 1000

///|
const WORKERS : Int = 4

///|
async fn seq(_g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @channel.Channel::new(capacity=cap)
  for i in 0..<MESSAGES {
    chan.send(i)
  }
  for i in 0..<MESSAGES {
    let _ = chan.receive()

  }
}

///|
async fn spsc(g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @channel.Channel::new(capacity=cap)
  let producer = g.spawn(async fn() {
    for i in 0..<MESSAGES {
      chan.send(i)
    }
  })
  let consumer = g.spawn(async fn() {
    for i in 0..<MESSAGES {
      let _ = chan.receive()

    }
  })
  producer.wait()
  consumer.wait()
}

///|
async fn mpsc(g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @channel.Channel::new(capacity=cap)
  for _ in 0..<WORKERS {
    g.spawn_bg(async fn() {
      let msgs_per_worker = MESSAGES / WORKERS
      for i in 0..<msgs_per_worker {
        chan.send(i)
      }
    })
  }
  let consumer = g.spawn(async fn() {
    for i in 0..<MESSAGES {
      let _ = chan.receive()

    }
  })
  consumer.wait()
}

///|
async fn mpmc(g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @channel.Channel::new(capacity=cap)
  let done = @channel.Channel::new()
  for _ in 0..<WORKERS {
    g.spawn_bg(async fn() {
      let msgs_per_worker = MESSAGES / WORKERS
      for i in 0..<msgs_per_worker {
        chan.send(i)
      }
      done.send(())
    })
  }
  for _ in 0..<WORKERS {
    g.spawn_bg(async fn() {
      let msgs_per_worker = MESSAGES / WORKERS
      for i in 0..<msgs_per_worker {
        let _ = chan.receive()

      }
      done.send(())
    })
  }
  for _ in 0..<WORKERS {
    let _ = done.receive()
    let _ = done.receive()

  }
}

///|
async fn run(
  name : String,
  f : async (@async.TaskGroup[Unit], Int) -> Unit,
  cap : Int,
) -> Unit {
  try {
    let start = @async.now()
    @async.with_task_group(fn(root) {
      let task = root.spawn(async fn() { f(root, cap) })
      task.wait()
    })
    let end = @async.now()
    let sec = (end - start).to_double() / 1000.0
    let pad = " ".repeat((25 - name.length()).max(0))
    println("\{name}\{pad} Moonbit Channel   \{sec} sec")
  } catch {
    e => println("run \{name} error: \{e}")
  }
}

///|
async fn main {
  run("bounded0_mpmc", mpmc, 0)
  run("bounded0_mpsc", mpsc, 0)
  run("bounded0_spsc", spsc, 0)
  run("bounded1_mpmc", mpmc, 1)
  run("bounded1_mpsc", mpsc, 1)
  run("bounded1_spsc", spsc, 1)
  run("bounded_mpmc", mpmc, MESSAGES)
  run("bounded_mpsc", mpsc, MESSAGES)
  run("bounded_seq", seq, MESSAGES)
  run("bounded_spsc", spsc, MESSAGES)
}
