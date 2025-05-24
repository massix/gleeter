import envoy
import gleam/io

pub fn debug_print(msg: String) -> Nil {
  case envoy.get("GLEETER_DEBUG") {
    Ok(_) -> io.println(msg)
    Error(_) -> Nil
  }
}

pub fn debug_print_x(obj: x, msg: String) -> x {
  case envoy.get("GLEETER_DEBUG") {
    Ok(_) -> io.println(msg)
    Error(_) -> Nil
  }

  obj
}
