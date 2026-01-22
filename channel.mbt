///|
async fn[T, E : Error] async_suspend(
  cb : ((T) -> Unit, (E) -> Unit) -> Unit,
) -> T raise E = "%async.suspend"

///|
fn run_async(f : async () -> Unit noraise) = "%async.run"

///|
priv struct RecvWaitCoro[T] {
  cont : async (T) -> Unit noraise
}

///|
priv struct SendWaitCoro[T] {
  item : T
  cont : async () -> Unit noraise
}

///|
type RecvWaitList[T] = LinkList[RecvWaitCoro[T]]

///|
type SendWaitList[T] = LinkList[SendWaitCoro[T]]

///|
struct Channel[T] {
  buffer : Array[T?]
  capacity : Int
  mut size : Int
  mut recv_index : Int
  mut send_index : Int
  mut closed : Bool
  recv_waitlist : RecvWaitList[T]
  send_waitlist : SendWaitList[T]
}

///|
pub fn[T] Channel::new(capacity : Int) -> Channel[T] {
  {
    buffer: Array::make(capacity, None),
    capacity,
    size: 0,
    recv_index: 0,
    send_index: 0,
    closed: false,
    recv_waitlist: RecvWaitList::new(),
    send_waitlist: SendWaitList::new(),
  }
}

///|
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
fn[T] Channel::enqueue_buff(chan : Channel[T], data : T) -> Unit {
  chan.size += 1
  chan.buffer[chan.send_index] = Some(data)
  chan.send_index += 1
  if chan.send_index >= chan.capacity {
    chan.send_index = 0
  }
}

///|
/// full buff
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
fn[T] Channel::try_receive(chan : Channel[T]) -> T? {
  match chan.send_waitlist.dequeue() {
    Some(w) => {
      let mut data = w.item
      if chan.size > 0 { //full
        data = chan.buff_recv_and_send(data)
      }
      run_async(w.cont)
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

///|
fn[T] Channel::try_send(chan : Channel[T], data : T) -> Bool {
  if chan.closed {
    return false // maybe raise error
  }
  match chan.recv_waitlist.dequeue() {
    Some(w) => {
      let cont = async fn() noraise {
        let _ = (w.cont)(data)
        ()
      }
      run_async(cont)
      true
    }
    None =>
      if chan.size < chan.capacity {
        chan.enqueue_buff(data)
        true
      } else {
        false
      }
  }
}

///|
async fn[T] Channel::send(chan : Channel[T], data : T) -> Unit {
  if chan.is_close() {
    panic() // todo raise error
  }
  if chan.try_send(data) {
    return
  }
  async_suspend(fn(ok_cont, _err) {
    let node = SendWaitCoro::{
      item: data,
      cont: async fn() noraise { ok_cont(()) },
    }
    chan.send_waitlist.enqueue(node)
  })
}

///|
async fn[T] Channel::receive(chan : Channel[T]) -> T {
  let data_opt = chan.try_receive()
  match data_opt {
    Some(data) => return data
    None => ()
  }
  if chan.is_close() {
    panic() // todo raise error
  }
  async_suspend(fn(ok_cont, _err) {
    let node = RecvWaitCoro::{
      cont: async fn(item : T) noraise { ok_cont(item) },
    }
    chan.recv_waitlist.enqueue(node)
  })
}

///|
fn[T] Channel::is_close(chan : Channel[T]) -> Bool {
  chan.closed
}

///|
fn[T] Channel::close(chan : Channel[T]) -> Unit {
  chan.closed = true
  //todo
}
