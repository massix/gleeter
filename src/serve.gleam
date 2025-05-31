import birl
import birl/duration
import cache
import debug.{debug_print}
import gleam/bytes_tree
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option
import gleam/result
import gleam/uri
import kitty/graphics
import messua
import messua/err
import messua/handle
import messua/ok
import messua/rr
import png
import version
import xkcd/api

type StatefulRequest =
  rr.MRequest(cache.Cache)

fn wrap_nil0(f: fn() -> Result(x, y)) -> Result(x, Nil) {
  f() |> result.map_error(fn(_) { Nil })
}

fn wrap_nil1(f: fn(x) -> Result(y, z), p: x) -> Result(y, Nil) {
  f(p)
  |> result.map_error(fn(_) { Nil })
}

fn wrap_nil2(f: fn(x, y) -> Result(z, w), p1: x, p2: y) -> Result(z, Nil) {
  f(p1, p2)
  |> result.map_error(fn(_) { Nil })
}

fn print_duration(start: birl.Time, end: birl.Time) -> Nil {
  let duration =
    birl.difference(end, start) |> duration.blur_to(duration.MilliSecond)
  debug_print("Duration: " <> int.to_string(duration) <> "ms")
}

fn handle_random(cache: cache.Cache) -> Result(cache.ComicWithData, Nil) {
  debug_print("Handling random")
  let start = birl.now()
  use api.Xkcd(number:, ..) <- result.try(api.get_latest |> wrap_nil0())
  let random = int.random(number + 1)

  let result = case cache.get_comic(cache, random) {
    option.Some(cwd) -> Ok(cwd)
    option.None -> {
      debug_print("Not found in cache: " <> int.to_string(random))
      use xkcd <- result.try(api.get_comic |> wrap_nil1(random))
      use body <- result.try(api.get_image |> wrap_nil1(xkcd))
      use result <- result.try(
        graphics.to_kitty_protocol_string |> wrap_nil2(body, 4096),
      )

      cache.insert_comic(cache, xkcd)
      |> cache.insert_image(xkcd.number, result, body)

      debug_print("Found comic: " <> int.to_string(xkcd.number))

      Ok(cache.ComicWithData(xkcd, result, body))
    }
  }

  print_duration(start, birl.now())
  result
}

fn handle_latest() -> Result(cache.ComicWithData, Nil) {
  debug_print("Handling latest")
  let start = birl.now()
  use latest <- result.try(api.get_latest |> wrap_nil0)
  use body <- result.try(api.get_image |> wrap_nil1(latest))
  use result <- result.try(
    graphics.to_kitty_protocol_string |> wrap_nil2(body, 4096),
  )

  print_duration(start, birl.now())
  Ok(cache.ComicWithData(latest, result, body))
}

fn handle_id(cache: cache.Cache, id: Int) -> Result(cache.ComicWithData, Nil) {
  debug_print("Handling id: " <> int.to_string(id))
  let start = birl.now()
  let result = case cache.get_comic(cache, id) {
    option.Some(cwd) -> Ok(cwd)
    option.None -> {
      debug_print("Not found in cache: " <> int.to_string(id))
      use xkcd <- result.try(api.get_comic |> wrap_nil1(id))
      use body <- result.try(api.get_image |> wrap_nil1(xkcd))
      use result <- result.try(
        graphics.to_kitty_protocol_string |> wrap_nil2(body, 4096),
      )

      cache.insert_comic(cache, xkcd)
      |> cache.insert_image(xkcd.number, result, body)

      debug_print("Found comic: " <> int.to_string(xkcd.number))

      Ok(cache.ComicWithData(xkcd, result, body))
    }
  }

  print_duration(start, birl.now())
  result
}

fn to_printable(
  in: cache.ComicWithData,
  terminal_size: option.Option(graphics.TerminalSize),
) -> bytes_tree.BytesTree {
  let data = case terminal_size, png.get_image_size(in.raw_data) {
    option.Some(ts), Ok(is) -> {
      graphics.resize_image(in.data, is, ts)
    }
    _, _ -> in.data
  }

  bytes_tree.new()
  |> bytes_tree.append_string("[" <> int.to_string(in.comic.number) <> "] ")
  |> bytes_tree.append_string(in.comic.title)
  |> bytes_tree.append_string("   ")
  |> bytes_tree.append_string(birl.to_date_string(in.comic.publication_date))
  |> bytes_tree.append_string("   ")
  |> bytes_tree.append_string(
    "https://xkcd.com/" <> int.to_string(in.comic.number),
  )
  |> bytes_tree.append_string("\n")
  |> bytes_tree.append_string(data)
  |> bytes_tree.append_string("\n")
  |> bytes_tree.append_string(in.comic.alternative_text)
  |> bytes_tree.append_string("\n")
  |> bytes_tree.append_string(option.unwrap(in.comic.link, ""))
}

/// Given a base path and a path, strip the base path from the path
fn strip_base_path(
  base_path: List(String),
  received_path: List(String),
) -> Result(List(String), Nil) {
  case base_path, received_path {
    [], rest -> Ok(rest)
    [x, ..xs], [y, ..ys] if x == y -> strip_base_path(xs, ys)
    [_, ..], [_, ..] -> Error(Nil)
    _, [] -> Error(Nil)
  }
}

fn handler(base_path: String) -> fn(StatefulRequest) -> rr.MResponse {
  io.println("Serving at base path: " <> base_path)
  let base_path = uri.path_segments(base_path)

  fn(s: StatefulRequest) -> rr.MResponse {
    let cache = rr.state(s)
    let path_segments =
      base_path
      |> strip_base_path(handle.path_segments(s))

    use terminal_columns <- handle.require_valid_optional_header(
      s,
      "X-TERMINAL-COLUMNS",
      int.parse,
    )

    use terminal_rows <- handle.require_valid_optional_header(
      s,
      "X-TERMINAL-ROWS",
      int.parse,
    )

    let terminal_size = case terminal_columns, terminal_rows {
      option.Some(columns), option.Some(rows) ->
        option.Some(graphics.TerminalSize(rows, columns))
      _, _ -> option.None
    }

    let result = case path_segments {
      Ok(l) ->
        case l {
          ["random"] -> handle_random(cache)
          ["id", id] -> {
            case int.parse(id) {
              Ok(num) -> handle_id(cache, num)
              Error(_) -> Error(Nil)
            }
          }
          ["latest"] | [] | _ -> handle_latest()
        }
      _ -> Error(Nil)
    }

    case result {
      Ok(cd) -> {
        ok.ok()
        |> ok.with_header("Content-Type", "text/plain")
        |> ok.with_header("X-Server-Version", version.gleeter_version)
        |> ok.with_binary_body(cd |> to_printable(terminal_size))
        |> Ok
      }
      Error(_) -> {
        err.new(404)
        |> Error
      }
    }
  }
}

pub fn serve(port: Int, base_path: String, cache: cache.Cache) -> Nil {
  io.println("Serving on port " <> int.to_string(port))

  messua.default()
  |> messua.with_http(port)
  |> messua.with_binding("0.0.0.0")
  |> messua.with_state(cache)
  |> messua.start(handler(base_path))

  process.sleep_forever()
}
