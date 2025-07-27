import birl
import birl/duration
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/uri
import gleeter/application_behavior
import gleeter/cache
import gleeter/config
import gleeter/debug.{debug_print}
import gleeter/graphics
import gleeter/png
import gleeter/serve
import gleeter/utils
import gleeter/version
import gleeter/xkcd

type PrintComic {
  Latest
  Random
  ID(Int)
}

fn print_api_error(in: xkcd.APIError) -> Nil {
  case in {
    xkcd.DecodeError(r) -> io.println("Could not decode API result: " <> r)
    xkcd.RequestError(r) -> io.println("Could not create request: " <> r)
    xkcd.GenericError(r) -> io.println("Generic error: " <> r)
  }
}

fn print_graphics_error(in: graphics.GraphicsError) -> Nil {
  case in {
    graphics.ChunkSizeTooBig -> io.println("Chunk size is too big!")
    graphics.ChunkNotMultipleOf4 ->
      io.println("Chunk size is not a multiple of 4!")
  }
}

fn print_version() -> Result(Nil, Nil) {
  Ok(io.println(
    "gleeter v" <> version.gleeter_version <> " " <> version.github_url,
  ))
}

// Get a comic from the cache or fetch it from the APIs and then store in the cache
fn get_comic_from_cache(
  cache: cache.Cache,
  id: Int,
) -> Result(cache.ComicWithData, Nil) {
  case cache.get_comic(cache, id) {
    option.Some(cd) -> Ok(cd)
    option.None -> {
      use cache.ComicWithData(xkcd, body, raw_data) as cmd <- result.try(
        get_comic_without_cache(id),
      )

      cache.insert_comic(cache, xkcd)
      |> cache.insert_image(xkcd.number, body, raw_data)

      Ok(cmd)
    }
  }
}

// Get a comic without using the cache
fn get_comic_without_cache(id: Int) -> Result(cache.ComicWithData, Nil) {
  let xkcd = case id {
    0 -> xkcd.get_latest()
    x -> xkcd.get_comic(x)
  }
  use xkcd <- result.try(
    xkcd
    |> result.map_error(print_api_error),
  )
  use raw_data <- result.try(
    xkcd.get_image(xkcd) |> result.map_error(print_api_error),
  )

  use body <- result.try(
    graphics.to_kitty_protocol_string(raw_data, 4096)
    |> result.map_error(print_graphics_error),
  )

  Ok(cache.ComicWithData(xkcd, body, raw_data))
}

// Generic get comic function, the request is then routed to the right underneath function
fn get_comic(
  in: PrintComic,
  cache: cache.Cache,
  ignore_cache: Bool,
) -> Result(cache.ComicWithData, Nil) {
  case in, ignore_cache {
    Latest, _ -> get_comic_from_cache(cache, 0)
    ID(id), False -> get_comic_from_cache(cache, id)
    ID(id), True -> get_comic_without_cache(id)
    Random, ignore_cache -> {
      use xkcd.Xkcd(number: highest, ..) <- result.try(
        xkcd.get_latest() |> result.map_error(print_api_error),
      )
      let random_comic = int.random(highest)
      use cache.ComicWithData(xkcd.Xkcd(img_url:, ..), ..) as r <- result.try(
        case ignore_cache {
          False -> get_comic_from_cache(cache, random_comic)
          True -> get_comic_without_cache(random_comic)
        },
      )
      let uri_string = uri.to_string(img_url)
      case utils.is_jpeg(uri_string) {
        False -> Ok(r)
        True -> {
          debug_print("Skipping JPEG comic: " <> uri_string)
          get_comic(in, cache, ignore_cache)
        }
      }
    }
  }
}

// Prints a comic to the stdout
fn print_comic(
  cache: cache.Cache,
  config: config.Configuration,
  in: PrintComic,
  ignore_cache: Bool,
) -> Result(Nil, Nil) {
  use cache.ComicWithData(xkcd, body, raw_data) <- result.try(get_comic(
    in,
    cache,
    ignore_cache,
  ))
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

  let xkcd.Xkcd(
    publication_date:,
    title:,
    alternative_text:,
    number:,
    link:,
    ..,
  ) = xkcd
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
    "  clearcache: clear the cache without printing any comic",
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
    application_behavior.LatestComic(ignore_cache) ->
      print_comic(cache, configuration, Latest, ignore_cache)
    application_behavior.RandomComic(ignore_cache) ->
      print_comic(cache, configuration, Random, ignore_cache)
    application_behavior.WithIDComic(id, ignore_cache) ->
      print_comic(cache, configuration, ID(id), ignore_cache)
    application_behavior.Serve(p, b) ->
      serve.serve(p, b, cache, configuration) |> Ok
    application_behavior.Help -> print_help(configuration.aliases)
    application_behavior.ClearCache -> {
      cache.clear(cache)
      io.println("Cache cleared") |> Ok
    }
  }
  let end = birl.now()

  let duration =
    birl.difference(end, now) |> duration.blur_to(duration.MilliSecond)

  debug_print("Duration: " <> int.to_string(duration) <> "ms")
  r
}
