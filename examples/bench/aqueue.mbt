///|
async fn aq_seq(g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @async.Queue::new(kind=Blocking(cap))
  g
  .spawn(async fn() {
    for i in 0..<MESSAGES {
      chan.put(i)
    }
    for i in 0..<MESSAGES {
      let _ = chan.get()

    }
  })
  .wait()
}

///|
async fn aq_spsc(g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @async.Queue::new(kind=Blocking(cap))
  g.spawn_bg(async fn() {
    for i in 0..<MESSAGES {
      chan.put(i)
    }
  })
  let c = g.spawn(async fn() {
    for i in 0..<MESSAGES {
      let _ = chan.get()

    }
  })
  c.wait()
}

///|
async fn aq_mpsc(g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @async.Queue::new(kind=Blocking(cap))
  for _ in 0..<WORKERS {
    g.spawn_bg(async fn() {
      let msgs_per_worker = MESSAGES / WORKERS
      for i in 0..<msgs_per_worker {
        chan.put(i)
      }
    })
  }
  let consumer = g.spawn(async fn() {
    for i in 0..<MESSAGES {
      let _ = chan.get()

    }
  })
  consumer.wait()
}

///|
async fn aq_mpmc(g : @async.TaskGroup[Unit], cap : Int) -> Unit {
  let chan = @async.Queue::new(kind=Blocking(cap))
  let done = @async.Queue::new(kind=Blocking(1))
  for _ in 0..<WORKERS {
    g.spawn_bg(async fn() {
      let msgs_per_worker = MESSAGES / WORKERS
      for i in 0..<msgs_per_worker {
        chan.put(i)
      }
      done.put(())
    })
  }
  for _ in 0..<WORKERS {
    g.spawn_bg(async fn() {
      let msgs_per_worker = MESSAGES / WORKERS
      for i in 0..<msgs_per_worker {
        let _ = chan.get()

      }
      done.put(())
    })
  }
  g
  .spawn(async fn() {
    for _ in 0..<WORKERS {
      let _ = done.get()
      let _ = done.get()

    }
  })
  .wait()
}
