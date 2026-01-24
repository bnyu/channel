///|
/// Suspend the current async task and register callbacks until `ok_cont` or
/// `err_cont` is triggered.
///
/// - `cb` receives two callbacks: success and error.
/// - When the error callback is invoked, the task raises `E`.
async fn[T, E : Error] async_suspend(
  cb : ((T) -> Unit, (E) -> Unit) -> Unit,
) -> T raise E = "%async.suspend"

///|
/// Schedule and run a non-throwing async task on the runtime.
fn run_async(f : async () -> Unit noraise) = "%async.run"

///|
/// A coroutine node in the receive wait list.
priv struct RecvWaitCoro[T] {
  ok_cont : async (T) -> Unit noraise
  err_cont : (ChannelClosedError) -> Unit
}

///|
/// A coroutine node in the send wait list.
priv struct SendWaitCoro[T] {
  item : T
  ok_cont : async () -> Unit noraise
  err_cont : (ChannelClosedError) -> Unit
}

///|
/// Alias for the receive wait list.
type RecvWaitList[T] = LinkList[RecvWaitCoro[T]]

///|
/// Alias for the send wait list.
type SendWaitList[T] = LinkList[SendWaitCoro[T]]

///|
/// An async channel that supports bounded/unbounded buffering.
///
/// - `capacity = -1` means unbounded.
/// - `capacity >= 0` means bounded.
/// - Bounded channel use a ring buffer.
/// - Unbounded channel use a linked list.
struct Channel[T] {
  unbounded : LinkList[T]? // only for unbounded channel
  buffer : Array[T?] // only for bounded channel
  capacity : Int
  mut size : Int
  mut recv_index : Int
  mut send_index : Int
  mut closed : ChannelClosedError?
  recv_waitlist : RecvWaitList[T]
  send_waitlist : SendWaitList[T]
}

///|
/// Error raised when the channel is closed.
pub suberror ChannelClosedError derive(Show)

///|
/// Error type for `try_send`.
pub enum TrySendError {
  Closed(ChannelClosedError)
  Full
} derive(Show)

///|
/// Error type for `try_receive`.
pub enum TryRecvError {
  Closed(ChannelClosedError)
  Empty
} derive(Show)

///|
/// Create a channel.
///
/// - `capacity = -1`: unbounded channel.
/// - `capacity >= 0`: bounded channel (0 means unbuffered).
pub fn[T] Channel::new(capacity? : Int = 0) -> Channel[T] {
  match capacity {
    -1 => Channel::unbound()
    n if n >= 0 => Channel::bound(n)
    _ => panic()
  }
}

///|
/// Create a bounded channel.
///
/// `capacity` must be non-negative, otherwise it panics.
pub fn[T] Channel::bound(capacity : Int) -> Channel[T] {
  if capacity < 0 {
    panic()
  }
  {
    buffer: Array::make(capacity, None),
    unbounded: None,
    capacity,
    size: 0,
    recv_index: 0,
    send_index: 0,
    closed: None,
    recv_waitlist: RecvWaitList::new(),
    send_waitlist: SendWaitList::new(),
  }
}

///|
/// Create an unbounded channel.
/// Send to an unbounded channel will never blocks.
pub fn[T] Channel::unbound() -> Channel[T] {
  {
    buffer: Array::make(0, None),
    unbounded: Some(LinkList::new()),
    capacity: -1,
    size: 0,
    recv_index: 0,
    send_index: 0,
    closed: None,
    recv_waitlist: RecvWaitList::new(),
    send_waitlist: SendWaitList::new(),
  }
}

///|
/// Dequeue one element from the unbounded list.
fn[T] Channel::dequeue_list(chan : Channel[T]) -> T? {
  match chan.unbounded {
    Some(list) =>
      match list.dequeue() {
        Some(v) => {
          chan.size -= 1
          Some(v)
        }
        None => None
      }
    None => None
  }
}

///|
/// Enqueue one element into the unbounded list.
fn[T] Channel::enqueue_list(chan : Channel[T], data : T) -> Unit {
  match chan.unbounded {
    Some(list) => {
      chan.size += 1
      list.enqueue(data)
    }
    None => panic()
  }
}

///|
/// Dequeue one element from the bounded ring buffer.
fn[T] Channel::dequeue_buff(chan : Channel[T]) -> T {
  chan.size -= 1
  let data = chan.buffer[chan.recv_index].unwrap()
  chan.buffer[chan.recv_index] = None
  chan.recv_index += 1
  if chan.recv_index >= chan.capacity {
    chan.recv_index = 0
  }
  data
}

///|
/// Enqueue one element into the bounded ring buffer.
fn[T] Channel::enqueue_buff(chan : Channel[T], data : T) -> Unit {
  chan.size += 1
  chan.buffer[chan.send_index] = Some(data)
  chan.send_index += 1
  if chan.send_index >= chan.capacity {
    chan.send_index = 0
  }
}

///|
/// "Receive one, send one" when the buffer is full.
///
/// Returns the first element and writes `data` into the current receive slot (last element).
fn[T] Channel::buff_recv_and_send(chan : Channel[T], data : T) -> T {
  let recv_data = chan.buffer[chan.recv_index].unwrap()
  chan.buffer[chan.recv_index] = Some(data)
  chan.recv_index += 1
  if chan.recv_index >= chan.capacity {
    chan.recv_index = 0
  }
  chan.send_index = chan.recv_index
  recv_data
}

///|
/// Try to receive an element immediately.
///
/// - Returns `Ok(data)` if an element is available.
/// - Returns `Err(Empty)` if no element is available.
/// - Returns `Err(Closed)` if no element is available and the channel is closed.
pub fn[T] Channel::try_receive(chan : Channel[T]) -> Result[T, TryRecvError] {
  let d = if chan.capacity == -1 { // unbounded
    chan.dequeue_list()
  } else {
    match chan.send_waitlist.dequeue() {
      Some(w) => {
        let mut data = w.item
        if chan.size > 0 {
          data = chan.buff_recv_and_send(data)
        }
        run_async(w.ok_cont)
        Some(data)
      }
      None =>
        if chan.size > 0 {
          let data = chan.dequeue_buff()
          Some(data)
        } else {
          None
        }
    }
  }
  match d {
    Some(data) => Ok(data)
    None =>
      if chan.closed is Some(err) {
        Err(TryRecvError::Closed(err))
      } else {
        Err(TryRecvError::Empty)
      }
  }
}

///|
/// Try to send an element immediately.
///
/// - Returns `Ok(())` on success.
/// - Returns `Err(Full)` if the buffer is full and no receiver is waiting.
/// - Returns `Err(Closed)` if the channel is already closed.
pub fn[T] Channel::try_send(
  chan : Channel[T],
  data : T,
) -> Result[Unit, TrySendError] {
  if chan.closed is Some(err) {
    return Err(TrySendError::Closed(err))
  }
  match chan.recv_waitlist.dequeue() {
    Some(w) => {
      let cont = async fn() noraise {
        let _ = (w.ok_cont)(data)
        ()
      }
      run_async(cont)
      Ok(())
    }
    None =>
      if chan.capacity == -1 { // unbounded
        chan.enqueue_list(data)
        Ok(())
      } else if chan.size < chan.capacity {
        chan.enqueue_buff(data)
        Ok(())
      } else {
        Err(TrySendError::Full)
      }
  }
}

///|
/// Send an element asynchronously.
///
/// - If receivers are waiting or the buffer is not full, delivers the element immediately,
/// unbounded channel will never blocks.
/// - If the buffer is full and no receiver is waiting on this channel,
///  suspends until received or closed.
/// - If the channel is closed, raises `ChannelClosedError`.
pub async fn[T] Channel::send(
  chan : Channel[T],
  data : T,
) -> Unit raise ChannelClosedError {
  match chan.try_send(data) {
    Ok(_) => return
    Err(TrySendError::Closed(err)) => raise err
    Err(TrySendError::Full) => ()
  }
  async_suspend(fn(ok_cont, err_cont : (ChannelClosedError) -> Unit) {
    let node = SendWaitCoro::{
      item: data,
      ok_cont: async fn() noraise { ok_cont(()) },
      err_cont,
    }
    chan.send_waitlist.enqueue(node)
  })
}

///|
/// Receive an element asynchronously.
///
/// - If buffer is not empty or senders are waiting, receives the element immediately.
/// - If buffer is empty and no senders are waiting, suspends until an element is available or closed.
/// - If the channel is closed and buffer is empty, raises `ChannelClosedError`.
pub async fn[T] Channel::receive(
  chan : Channel[T],
) -> T raise ChannelClosedError {
  match chan.try_receive() {
    Ok(data) => return data
    Err(TryRecvError::Closed(err)) => raise err
    Err(TryRecvError::Empty) => ()
  }
  async_suspend(fn(ok_cont, err_cont : (ChannelClosedError) -> Unit) {
    let node = RecvWaitCoro::{
      ok_cont: async fn(item : T) noraise { ok_cont(item) },
      err_cont,
    }
    chan.recv_waitlist.enqueue(node)
  })
}

///|
/// Check whether the channel is already closed.
pub fn[T] Channel::is_closed(chan : Channel[T]) -> Bool {
  chan.closed is Some(_)
}

///|
/// Close the channel and wake all pending send/receive coroutines.
/// 
/// When closed, all pending send/receive operations will fail, raise `ChannelClosedError`.
/// Receives can still receive buffered elements after closed, after all buffered elements are received,
/// `try_receive` will return `Err(Closed)`, `receive` will raise `ChannelClosedError`.
/// Senders can no longer send after the channel is closed.
/// 
/// Repeated close is a no-op.
pub fn[T] Channel::close(chan : Channel[T]) -> Unit {
  if chan.is_closed() {
    return
  }
  let err = ChannelClosedError
  chan.closed = Some(err)
  while chan.send_waitlist.dequeue() is Some(w) {
    run_async(async fn() noraise { (w.err_cont)(err) })
  }
  while chan.recv_waitlist.dequeue() is Some(w) {
    run_async(async fn() noraise { (w.err_cont)(err) })
  }
}
