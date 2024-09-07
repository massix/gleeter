import application_behavior
import birl
import gleam/int
import gleam/io
import gleam/result
import kitty/graphics
import xkcd/api

const gleeter_version = "1.0.0"

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

fn print_comic(in: PrintComic) -> Result(Nil, Nil) {
  use xkcd <- result.try(
    case in {
      Latest -> api.get_latest()
      Random -> api.get_random()
      ID(id) -> api.get_comic(id)
    }
    |> result.map_error(print_api_error),
  )

  let api.Xkcd(publication_date:, title:, alternative_text:, number:, ..) = xkcd
  io.print("[" <> int.to_string(number) <> "] ")
  io.print(title)
  io.print("   ")
  io.println(birl.to_date_string(publication_date))

  use body <- result.try(
    api.get_image(xkcd) |> result.map_error(print_api_error),
  )

  graphics.to_kitty_protocol_string(body, 4096)
  |> result.map_error(fn(e) {
    case e {
      graphics.ChunkSizeTooBig -> io.println("Chunk size is too big!")
      graphics.ChunkNotMultipleOf4 ->
        io.println("Chunk size is not a multiple of 4!")
    }
  })
  |> result.map(io.println)
  |> result.map(fn(_) { io.println(alternative_text) })
}

pub fn main() -> Result(Nil, Nil) {
  case application_behavior.get_application_behavior() {
    application_behavior.PrintVersion -> print_version()
    application_behavior.LatestComic -> print_comic(Latest)
    application_behavior.RandomComic -> print_comic(Random)
    application_behavior.WithIDComic(id) -> print_comic(ID(id))
  }
}
