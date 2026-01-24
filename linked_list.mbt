///|
priv struct LinkNode[T] {
  mut prev : LinkNode[T]? // weak reference? C backend does not have GC
  mut next : LinkNode[T]?
  data : T
}

///|
fn[T] LinkNode::new(data : T) -> LinkNode[T] {
  { prev: None, next: None, data }
}

///|
priv struct LinkList[T] {
  mut head : LinkNode[T]?
  mut tail : LinkNode[T]?
}

///|
fn[T] LinkList::new() -> LinkList[T] {
  { head: None, tail: None }
}

///|
fn[T] LinkList::enqueue(list : LinkList[T], data : T) -> Unit {
  let node = LinkNode::new(data)
  let this_node = Some(node)
  match list.tail {
    Some(tail) => {
      node.prev = list.tail
      tail.next = this_node
      list.tail = this_node
    }
    None => {
      list.head = this_node
      list.tail = this_node
    }
  }
}

///|
fn[T] LinkList::dequeue(list : LinkList[T]) -> T? {
  match list.head {
    Some(head) => {
      list.head = head.next
      match list.head {
        Some(new_head) => new_head.prev = None
        None => list.tail = None
      }
      head.next = None
      Some(head.data)
    }
    None => None
  }
}

///|
/// for select implementation
fn[T] LinkList::last(list : LinkList[T]) -> LinkNode[T]? {
  list.tail
}

///|
/// for select implementation
fn[T] LinkList::remove(list : LinkList[T], node : LinkNode[T]) -> Unit {
  match (node.prev, node.next) {
    (Some(prev), Some(next)) => {
      prev.next = node.next
      next.prev = node.prev
    }
    (Some(prev), None) => {
      prev.next = None
      list.tail = Some(prev)
    }
    (None, Some(next)) => {
      next.prev = None
      list.head = Some(next)
    }
    _ => {
      list.head = None
      list.tail = None
    }
  }
}
