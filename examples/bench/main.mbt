///|
async fn seq(g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @channel.Channel::new(capacity=cap)
  g
  .spawn(async fn() {
    for i in 0..<MESSAGES {
      chan.send(i)
    }
    for i in 0..<MESSAGES {
      let _ = chan.receive()

    }
  })
  .wait()
}

///|
async fn spsc(g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @channel.Channel::new(capacity=cap)
  g.spawn_bg(async fn() {
    for i in 0..<MESSAGES {
      chan.send(i)
    }
  })
  let c = g.spawn(async fn() {
    for i in 0..<MESSAGES {
      let _ = chan.receive()

    }
  })
  c.wait()
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
  g
  .spawn(async fn() {
    for _ in 0..<WORKERS {
      let _ = done.receive()
      let _ = done.receive()

    }
  })
  .wait()
}

///|
async fn run(
  name : String,
  kind : String,
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
    let pad = " ".repeat((17 - name.length()).max(0))
    let pad2 = " ".repeat((17 - kind.length()).max(0))
    println("\{name}\{pad} Moonbit \{kind}\{pad2} \{sec} sec")
  } catch {
    e => println("run \{name} error: \{e}")
  }
}

///|
const MESSAGES : Int = 5 * 1000 * 1000

///|
const WORKERS : Int = 4

///|
async fn main {
  run("bounded0_mpmc", "Channel", mpmc, 0)
  run("bounded0_mpsc", "Channel", mpsc, 0)
  run("bounded0_spsc", "Channel", spsc, 0)
  run("bounded1_mpmc", "Channel", mpmc, 1)
  run("bounded1_mpsc", "Channel", mpsc, 1)
  run("bounded1_spsc", "Channel", spsc, 1)
  run("bounded_mpmc", "Channel", mpmc, MESSAGES)
  run("bounded_mpsc", "Channel", mpsc, MESSAGES)
  run("bounded_seq", "Channel", seq, MESSAGES)
  run("bounded_spsc", "Channel", spsc, MESSAGES)

  // run("bounded0_mpmc", "@async/Queue", aq_mpmc, 0)
  // run("bounded0_mpsc", "@async/Queue", aq_mpsc, 0)
  // run("bounded0_spsc", "@async/Queue", aq_spsc, 0)
  run("bounded1_mpmc", "@async/Queue", aq_mpmc, 1)
  run("bounded1_mpsc", "@async/Queue", aq_mpsc, 1)
  run("bounded1_spsc", "@async/Queue", aq_spsc, 1)
  run("bounded_mpmc", "@async/Queue", aq_mpmc, MESSAGES)
  run("bounded_mpsc", "@async/Queue", aq_mpsc, MESSAGES)
  run("bounded_seq", "@async/Queue", aq_seq, MESSAGES)
  run("bounded_spsc", "@async/Queue", aq_spsc, MESSAGES)
}
