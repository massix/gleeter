import application_behavior
import birl
import birl/duration
import cache
import envoy
import gleam/int
import gleam/io
import gleam/option
import gleam/result
import kitty/graphics
import xkcd/api

const gleeter_version = "1.1.0"

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
      use body <- result.try(
        api.get_image(xkcd) |> result.map_error(print_api_error),
      )
      use body <- result.try(
        graphics.to_kitty_protocol_string(body, 4096)
        |> result.map_error(fn(e) {
          case e {
            graphics.ChunkSizeTooBig -> io.println("Chunk size is too big!")
            graphics.ChunkNotMultipleOf4 ->
              io.println("Chunk size is not a multiple of 4!")
          }
        }),
      )

      cache.insert_comic(cache, xkcd)
      |> cache.insert_image(xkcd.number, body)

      Ok(cache.ComicWithData(xkcd, body))
    }
  }
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

  let cache.ComicWithData(xkcd, body) = cached_comic
  let api.Xkcd(publication_date:, title:, alternative_text:, number:, ..) = xkcd
  io.print("[" <> int.to_string(number) <> "] ")
  io.print(title)
  io.print("   ")
  io.println(birl.to_date_string(publication_date))
  io.println(body)
  io.println(alternative_text)

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

  case envoy.get("GLEETER_DEBUG") {
    Ok(_) -> io.println("Duration: " <> int.to_string(duration) <> "ms")
    Error(_) -> Nil
  }

  r
}
