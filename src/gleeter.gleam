import application_behavior
import birl
import birl/duration
import cache
import debug.{debug_print, debug_print_x}
import gleam/float
import gleam/int
import gleam/io
import gleam/option
import gleam/result
import gleam/string
import kitty/graphics
import png
import xkcd/api

const gleeter_version = "1.1.1"

type PrintComic {
  Latest
  Random
  ID(Int)
}

fn print_api_error(in: api.APIError) -> Nil {
  case in {
    api.DecodeError(r) -> io.println("Could not decode API result: " <> r)
    api.RequestError(r) -> io.println("Could not create request: " <> r)
    api.GenericError(r) -> io.println("Generic error: " <> r)
  }
}

fn print_version() -> Result(Nil, Nil) {
  Ok(io.println("gleeter v" <> gleeter_version))
}

// Get a comic from the cache or fetch it from the APIs and then store in the cache
fn get_comic(cache: cache.Cache, id: Int) -> Result(cache.ComicWithData, Nil) {
  case cache.get_comic(cache, id) {
    option.Some(cd) -> Ok(cd)
    option.None -> {
      let xkcd = case id {
        0 -> api.get_latest()
        x -> api.get_comic(x)
      }
      use xkcd <- result.try(
        xkcd
        |> result.map_error(print_api_error),
      )
      use raw_data <- result.try(
        api.get_image(xkcd) |> result.map_error(print_api_error),
      )

      use body <- result.try(
        graphics.to_kitty_protocol_string(raw_data, 4096)
        |> result.map_error(fn(e) {
          case e {
            graphics.ChunkSizeTooBig -> io.println("Chunk size is too big!")
            graphics.ChunkNotMultipleOf4 ->
              io.println("Chunk size is not a multiple of 4!")
          }
        }),
      )

      cache.insert_comic(cache, xkcd)
      |> cache.insert_image(xkcd.number, body, raw_data)

      Ok(cache.ComicWithData(xkcd, body, raw_data))
    }
  }
}

// PERF: temporary hack to resize the image before printing it
fn resize_image(in: String, original_size: png.ImageSize(Int)) -> String {
  let #(terminal_rows, terminal_columns) = graphics.get_terminal_size()
  let png.ImageSize(width: image_width, height: image_height) = original_size

  debug_print("terminal_rows: " <> int.to_string(terminal_rows))
  debug_print("terminal_columns: " <> int.to_string(terminal_columns))
  debug_print("image_width: " <> int.to_string(image_width))
  debug_print("image_height: " <> int.to_string(image_height))

  let image_aspect = int.to_float(image_width) /. int.to_float(image_height)

  debug_print("image_aspect: " <> float.to_string(image_aspect))

  let max_rows = int.to_float(terminal_rows) *. 0.75
  let max_cols = int.to_float(terminal_columns) *. 0.75

  debug_print("max_rows: " <> float.to_string(max_rows))
  debug_print("max_cols: " <> float.to_string(max_cols))

  let maxed_height = {
    let rows = max_rows |> float.round
    let cols = { max_rows *. image_aspect } |> float.round
    #(cols, rows)
  }

  let maxed_width = {
    let cols = max_cols |> float.round
    let rows = { max_cols /. image_aspect } |> float.round
    #(cols, rows)
  }

  // If the maxed height is less than the maxed width, use the maxed height
  let #(cols, rows) = case max_rows >. max_cols {
    True -> maxed_width |> debug_print_x("returning maxed width")
    False -> maxed_height |> debug_print_x("returning maxed height")
  }

  debug_print("cols: " <> int.to_string(cols))
  debug_print("rows: " <> int.to_string(rows))

  string.replace(
    in,
    "a=T,f=100",
    "a=T,f=100,X=32,r="
      <> rows |> int.to_string()
      <> ",c="
      <> cols |> int.to_string(),
  )
}

fn print_comic(cache: cache.Cache, in: PrintComic) -> Result(Nil, Nil) {
  use cached_comic <- result.try(case in {
    Latest -> get_comic(cache, 0)
    Random -> {
      use api.Xkcd(number:, ..) <- result.try(
        api.get_latest() |> result.map_error(print_api_error),
      )
      let random_comic = int.random(number)
      get_comic(cache, random_comic)
    }
    ID(id) -> get_comic(cache, id)
  })

  let cache.ComicWithData(xkcd, body, raw_data) = cached_comic
  use image_size <- result.try(png.get_image_size(raw_data))

  let api.Xkcd(publication_date:, title:, alternative_text:, number:, link:, ..) =
    xkcd
  io.print("[" <> int.to_string(number) <> "] ")
  io.print(title)
  io.print("   ")
  io.print(birl.to_date_string(publication_date))
  io.print("   ")
  io.println("https://xkcd.com/" <> int.to_string(number))
  io.println(body |> resize_image(image_size))
  io.println(alternative_text)
  option.unwrap(link, "")
  |> io.println()

  Ok(Nil)
}

pub fn main() -> Result(Nil, Nil) {
  let cache = cache.new(cache.get_cache_location())
  let now = birl.now()
  let r = case application_behavior.get_application_behavior() {
    application_behavior.PrintVersion -> print_version()
    application_behavior.LatestComic -> print_comic(cache, Latest)
    application_behavior.RandomComic -> print_comic(cache, Random)
    application_behavior.WithIDComic(id) -> print_comic(cache, ID(id))
  }
  let end = birl.now()

  let duration =
    birl.difference(end, now) |> duration.blur_to(duration.MilliSecond)

  debug_print("Duration: " <> int.to_string(duration) <> "ms")
  r
}
