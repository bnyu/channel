///|
fn run_async(f : async () -> Unit noraise) -> Unit = "%async.run"

///|
test "demo example" {
  let chan = Channel::new(capacity=2)

  // non-blocking send/receive
  let _ = chan.try_send(0)
  let _ = chan.try_send(1)
  let r = chan.try_receive().unwrap()
  assert_eq(r, 0)

  // async send/receive
  let mut a : Int? = None
  let mut b : Int? = None
  let mut c : Int? = None
  let mut d : Int? = None
  let mut e : Int? = None
  let mut extra : Int? = None
  let mut recv_failed = false
  run_async(fn() {
    try {
      a = Some(chan.receive())
      b = Some(chan.receive())
      c = Some(chan.receive())
      d = Some(chan.receive())
      e = Some(chan.receive())
      extra = Some(chan.receive())
    } catch {
      _ => recv_failed = true
    }
  })
  run_async(fn() {
    try {
      chan.send(2)
      chan.send(3)
      chan.send(4)
      chan.send(5)
      chan.close()
    } catch {
      _ => panic()
    }
  })
  assert_eq(a, Some(1))
  assert_eq(b, Some(2))
  assert_eq(c, Some(3))
  assert_eq(d, Some(4))
  assert_eq(e, Some(5))
  assert_eq(extra, None)
  assert_eq(recv_failed, true)
}

///|
test "buffered fifo" {
  let chan = Channel::bound(2)
  let mut a : Int? = None
  let mut b : Int? = None
  run_async(fn() {
    try {
      chan.send(1)
      chan.send(2)
      a = Some(chan.receive())
      b = Some(chan.receive())
      chan.send(3)
      chan.send(4)
    } catch {
      _ => panic()
    }
  })
  assert_eq(a, Some(1))
  assert_eq(b, Some(2))
}

///|
test "rendezvous channel" {
  let chan = Channel::bound(0)
  let mut a : Int? = None
  let mut b : Int? = None
  run_async(fn() {
    try {
      chan.send(1)
      chan.send(2)
    } catch {
      _ => panic()
    }
  })
  run_async(fn() {
    try {
      a = Some(chan.receive())
      b = Some(chan.receive())
    } catch {
      _ => panic()
    }
  })
  assert_eq(a, Some(1))
  assert_eq(b, Some(2))
}

///|
test "send blocks when buffer full" {
  let chan = Channel::bound(1)
  let done = Channel::bound(1)
  let mut sender_done = false
  let mut first : Int? = None
  let mut second : Int? = None
  run_async(fn() {
    try {
      chan.send(1)
      chan.send(2)
      sender_done = true
      let _ = done.try_send(())

    } catch {
      _ => panic()
    }
  })
  assert_eq(sender_done, false)
  let r : Result[Unit, TryRecvError] = done.try_receive()
  assert_true(r is Err(e) && e is TryRecvError::Empty)
  run_async(fn() {
    try {
      first = Some(chan.receive())
      second = Some(chan.receive())
    } catch {
      _ => panic()
    }
  })
  assert_eq(sender_done, true)
  assert_eq(first, Some(1))
  assert_eq(second, Some(2))
}

///|
test "receive wakes blocked sender when buffer full" {
  let chan = Channel::bound(2)
  let done = Channel::bound(1)
  let mut sender_done = false
  let mut res : Int? = None
  let _ = chan.try_send(1)
  let _ = chan.try_send(2)
  run_async(fn() {
    try {
      chan.send(3)
      sender_done = true
      let _ = done.try_send(())

    } catch {
      _ => panic()
    }
  })
  assert_eq(sender_done, false)
  let r : Result[Unit, TryRecvError] = done.try_receive()
  assert_true(r is Err(e) && e is TryRecvError::Empty)
  run_async(fn() {
    try {
      res = Some(chan.receive())
    } catch {
      _ => panic()
    }
  })
  assert_eq(sender_done, true)
  assert_eq(res, Some(1))
  let b = chan.try_receive().unwrap()
  assert_eq(b, 2)
}

///|
test "try_send succeeds when buffer has space" {
  let chan = Channel::bound(1)
  let r = chan.try_send(10)
  assert_true(r is Ok(_))
}

///|
test "try_send returns Full when buffer full" {
  let chan = Channel::bound(1)
  let _ = chan.try_send(1)
  let r = chan.try_send(2)
  assert_true(r is Err(e) && e is TrySendError::Full)
}

///|
test "try_send returns Closed after close" {
  let chan = Channel::bound(1)
  chan.close()
  let r = chan.try_send(1)
  match r {
    Err(TrySendError::Closed(_)) => assert_eq(true, true)
    _ => assert_eq(true, false)
  }
}

///|
test "try_receive returns Empty when no data" {
  let chan = Channel::bound(1)
  let r : Result[Int, TryRecvError] = chan.try_receive()
  assert_true(r is Err(e) && e is TryRecvError::Empty)
}

///|
test "try_receive returns data after send" {
  let chan = Channel::bound(1)
  let _ = chan.try_send(7)
  let r = chan.try_receive()
  assert_true(r is Ok(7))
}

///|
test "try_receive returns Closed after close and empty" {
  let chan = Channel::bound(1)
  chan.close()
  let r : Result[Int, TryRecvError] = chan.try_receive()
  match r {
    Err(TryRecvError::Closed(_)) => assert_eq(true, true)
    _ => assert_eq(true, false)
  }
}

///|
test "try_receive returns data after close when not empty" {
  let chan = Channel::bound(1)
  let _ = chan.try_send(42)
  chan.close()
  let r = chan.try_receive()
  assert_true(r is Ok(42))
}

///|
test "unbounded try_send never full" {
  let chan = Channel::unbound()
  let r1 = chan.try_send(1)
  let r2 = chan.try_send(2)
  assert_true(r1 is Ok(_))
  assert_true(r2 is Ok(_))
}

///|
test "unbounded try_send returns Closed after close" {
  let chan = Channel::unbound()
  chan.close()
  let r = chan.try_send(1)
  match r {
    Err(TrySendError::Closed(_)) => assert_eq(true, true)
    _ => assert_eq(true, false)
  }
}

///|
test "unbounded try_receive returns Closed after close and empty" {
  let chan = Channel::unbound()
  chan.close()
  let r : Result[Int, TryRecvError] = chan.try_receive()
  match r {
    Err(TryRecvError::Closed(_)) => assert_eq(true, true)
    _ => assert_eq(true, false)
  }
}

///|
test "unbounded try_receive returns data after close when not empty" {
  let chan = Channel::unbound()
  let _ = chan.try_send(42)
  chan.close()
  let r = chan.try_receive()
  assert_true(r is Ok(42))
}

///|
test "handoff to waiting receiver" {
  let chan = Channel::bound(1)
  let mut got : Int? = None
  run_async(fn() {
    try {
      let v = chan.receive()
      got = Some(v)
    } catch {
      _ => panic()
    }
  })
  run_async(fn() { chan.send(42) catch { _ => panic() } })
  assert_eq(got, Some(42))
}

///|
test "try_send wakes waiting unbound receiver" {
  let chan = Channel::unbound()
  let mut r : Int? = None
  run_async(fn() {
    try {
      r = Some(chan.receive())
    } catch {
      _ => ()
    }
  })
  let _ = chan.try_send(10)
  assert_eq(r, Some(10))
}

///|
test "send wakes waiting unbound receiver" {
  let chan = Channel::unbound()
  let mut r : Int? = None
  run_async(fn() {
    try {
      r = Some(chan.receive())
    } catch {
      _ => panic()
    }
  })
  run_async(fn() { chan.send(10) catch { _ => panic() } })
  assert_eq(r, Some(10))
}

///|
test "close makes send fail" {
  let chan = Channel::bound(1)
  let mut send_failed = false
  chan.close()
  run_async(fn() { chan.send(1) catch { _ => send_failed = true } })
  assert_eq(send_failed, true)
}

///|
test "close makes receive fail when empty" {
  let chan = Channel::bound(1)
  let mut recv_failed = false
  chan.close()
  run_async(fn() {
    try {
      let _ : Int = chan.receive()

    } catch {
      _ => recv_failed = true
    }
  })
  assert_eq(recv_failed, true)
}

///|
test "close wakes waiting receiver" {
  let chan = Channel::bound(1)
  let mut recv_failed = false
  run_async(fn() {
    try {
      let _ : Int = chan.receive()

    } catch {
      _ => recv_failed = true
    }
  })
  chan.close()
  assert_eq(recv_failed, true)
}

///|
test "close wakes waiting unbound receiver" {
  let chan = Channel::unbound()
  let mut recv_failed = false
  run_async(fn() {
    try {
      let _ : Int = chan.receive()

    } catch {
      _ => recv_failed = true
    }
  })
  chan.close()
  assert_eq(recv_failed, true)
}

///|
test "close wakes waiting sender" {
  let chan = Channel::bound(0)
  let mut send_failed = false
  run_async(fn() { chan.send(1) catch { _ => send_failed = true } })
  chan.close()
  assert_eq(send_failed, true)
}
