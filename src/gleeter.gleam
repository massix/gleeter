import application_behavior
import birl
import birl/duration
import cache
import debug.{debug_print}
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleeter/config
import kitty/graphics
import png
import serve
import version
import xkcd/api

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
  Ok(io.println(
    "gleeter v" <> version.gleeter_version <> " " <> version.github_url,
  ))
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

fn print_comic(
  cache: cache.Cache,
  config: config.Configuration,
  in: PrintComic,
) -> Result(Nil, Nil) {
  use cached_comic <- result.try(case in {
    Latest -> get_comic(cache, 0)
    Random -> {
      use api.Xkcd(number: highest, ..) <- result.try(
        api.get_latest() |> result.map_error(print_api_error),
      )
      let random_comic = case config.random_start {
        option.Some(start) -> int.random(highest - start) + start
        option.None -> int.random(highest)
      }
      get_comic(cache, random_comic)
    }
    ID(id) -> get_comic(cache, id)
  })

  let cache.ComicWithData(xkcd, body, raw_data) = cached_comic
  use image_size <- result.try(png.get_image_size(raw_data))
  let terminal_size = graphics.get_terminal_size()

  // Set new max_cols and max_lines if they were specified in the configuration
  let terminal_size = case config.max_lines, config.max_cols {
    option.Some(max_rows), option.Some(max_cols) ->
      graphics.TerminalSize(
        int.min(max_rows, terminal_size.rows),
        int.min(max_cols, terminal_size.columns),
      )
    option.Some(max_rows), option.None ->
      graphics.TerminalSize(
        int.min(max_rows, terminal_size.rows),
        terminal_size.columns,
      )
    option.None, option.Some(max_cols) ->
      graphics.TerminalSize(
        terminal_size.rows,
        int.min(max_cols, terminal_size.columns),
      )
    option.None, option.None -> terminal_size
  }

  let api.Xkcd(publication_date:, title:, alternative_text:, number:, link:, ..) =
    xkcd
  io.print("[" <> int.to_string(number) <> "] ")
  io.print(title)
  io.print("   ")
  io.print(birl.to_date_string(publication_date))
  io.print("   ")
  io.println("https://xkcd.com/" <> int.to_string(number))
  io.println(body |> graphics.resize_image(image_size, terminal_size))
  io.println(alternative_text)
  option.unwrap(link, "")
  |> io.println()

  Ok(Nil)
}

fn print_help(aliases: List(config.Alias)) -> Result(Nil, Nil) {
  let help_lines = [
    "usage: gleeter [command] [options]", "", "available commands:",
    "  serve [port] [base_path]: start gleeter in server mode",
    "                            default port: 8080, default base_path: \"/\"",
    "  id [id]: print comic with id", "  latest: print latest comic",
    "  random: print random comic",
  ]

  let aliases =
    list.map(aliases, fn(alias) {
      case alias {
        config.RandomAlias(_) -> "  " <> alias.name <> ": print random comic"
        config.LatestAlias(_) -> "  " <> alias.name <> ": print latest comic"
        config.IdAlias(_, id) ->
          "  " <> alias.name <> ": print comic with id " <> int.to_string(id)
      }
    })

  help_lines
  |> list.append(aliases)
  |> list.each(io.println)
  |> Ok
}

pub fn main() -> Result(Nil, Nil) {
  let cache = cache.new(cache.get_cache_location())
  let now = birl.now()
  let configuration_path = config.get_configuration_file()
  debug_print("Configuration path: " <> configuration_path)

  let configuration = config.parse(configuration_path)

  let r = case application_behavior.get_application_behavior(configuration) {
    application_behavior.PrintVersion -> print_version()
    application_behavior.LatestComic ->
      print_comic(cache, configuration, Latest)
    application_behavior.RandomComic ->
      print_comic(cache, configuration, Random)
    application_behavior.WithIDComic(id) ->
      print_comic(cache, configuration, ID(id))
    application_behavior.Serve(p, b) ->
      serve.serve(p, b, cache, configuration) |> Ok
    application_behavior.Help -> print_help(configuration.aliases)
  }
  let end = birl.now()

  let duration =
    birl.difference(end, now) |> duration.blur_to(duration.MilliSecond)

  debug_print("Duration: " <> int.to_string(duration) <> "ms")
  r
}
