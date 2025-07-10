import gleam/string

const jpeg_extensions = ["jpg", "jpeg"]

const png_extensions = ["png"]

pub fn is_jpeg(in: String) -> Bool {
  check_extension(in, jpeg_extensions)
}

pub fn is_png(in: String) -> Bool {
  check_extension(in, png_extensions)
}

fn check_extension(in: String, ext: List(String)) -> Bool {
  case ext {
    [] -> False
    [x, ..rest] -> {
      case in |> string.lowercase() |> string.ends_with(x) {
        True -> True
        False -> check_extension(in, rest)
      }
    }
  }
}
