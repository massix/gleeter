import birl
import birl/duration
import gleam/bytes_tree
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/string_tree
import gleam/uri
import gleeter/cache
import gleeter/config
import gleeter/debug.{debug_print}
import gleeter/graphics
import gleeter/metrics
import gleeter/png
import gleeter/version
import gleeter/xkcd
import messua
import messua/err
import messua/handle
import messua/ok
import messua/rr
import themis

type ApplicationContext {
  ApplicationContext(
    cache: cache.Cache,
    cfg: config.Configuration,
    actor: process.Subject(ActorMessage),
  )
}

type HealthCheck {
  HealthCheck(
    cache_status: Bool,
    cache_elements: Int,
    processed_queries: Int,
    current_version: String,
    loaded_aliases: List(String),
  )
}

type ApiError {
  ApiError(message: String)
}

fn encode_api_error(api_error: ApiError) -> json.Json {
  let ApiError(message:) = api_error
  json.object([#("message", json.string(message))])
}

fn encode_health_check(health_check: HealthCheck) -> json.Json {
  let HealthCheck(
    cache_status:,
    cache_elements:,
    processed_queries:,
    current_version:,
    loaded_aliases:,
  ) = health_check
  json.object([
    #("cache_status", json.bool(cache_status)),
    #("cache_elements", json.int(cache_elements)),
    #("processed_queries", json.int(processed_queries)),
    #("current_version", json.string(current_version)),
    #("loaded_aliases", json.array(loaded_aliases, json.string)),
  ])
}

fn build_health_check(ctx: ApplicationContext) -> HealthCheck {
  let cache_status = cache.is_cache_loaded(ctx.cache)
  let cache_elements = cache.count_elements(ctx.cache) |> option.unwrap(0)
  let processed_queries = process.call(ctx.actor, Get, 50)
  let current_version = version.user_agent
  let loaded_aliases = list.map(ctx.cfg.aliases, fn(x) { x.name })

  HealthCheck(
    cache_status:,
    cache_elements:,
    processed_queries:,
    current_version:,
    loaded_aliases:,
  )
}

type ActorMessage {
  Get(process.Subject(Int))
  Inc
}

fn process_request(
  message: ActorMessage,
  state: Int,
) -> actor.Next(ActorMessage, Int) {
  case message {
    Inc -> actor.continue(state + 1)
    Get(s) -> {
      actor.send(s, state)
      actor.continue(state)
    }
  }
}

type StatefulRequest =
  rr.MRequest(ApplicationContext)

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
  use xkcd.Xkcd(number:, ..) <- result.try(xkcd.get_latest |> wrap_nil0())
  let random = int.random(number + 1)

  let result = case cache.get_comic(cache, random) {
    option.Some(cwd) -> {
      metrics.increment_cache_hits("random")
      Ok(cwd)
    }
    option.None -> {
      metrics.increment_cache_miss("random")
      debug_print("Not found in cache: " <> int.to_string(random))
      use xkcd <- result.try(xkcd.get_comic |> wrap_nil1(random))
      use body <- result.try(xkcd.get_image |> wrap_nil1(xkcd))
      use result <- result.try(
        graphics.to_kitty_protocol_string |> wrap_nil2(body, 4096),
      )

      cache.insert_comic(cache, xkcd)
      |> cache.insert_image(xkcd.number, result, body)

      debug_print("Found comic: " <> int.to_string(xkcd.number))
      metrics.increment_cached_elements()

      Ok(cache.ComicWithData(xkcd, result, body))
    }
  }

  let end = birl.now()
  print_duration(start, end)
  metrics.update_request_duration(start, end, "random")
  metrics.increment_processed_queries("random")
  result
}

fn handle_latest() -> Result(cache.ComicWithData, Nil) {
  debug_print("Handling latest")
  let start = birl.now()
  use latest <- result.try(xkcd.get_latest |> wrap_nil0)
  use body <- result.try(xkcd.get_image |> wrap_nil1(latest))
  use result <- result.try(
    graphics.to_kitty_protocol_string |> wrap_nil2(body, 4096),
  )

  let end = birl.now()
  print_duration(start, end)
  metrics.increment_processed_queries("latest")
  metrics.update_request_duration(start, end, "latest")
  Ok(cache.ComicWithData(latest, result, body))
}

fn handle_id(cache: cache.Cache, id: Int) -> Result(cache.ComicWithData, Nil) {
  debug_print("Handling id: " <> int.to_string(id))
  let start = birl.now()
  let result = case cache.get_comic(cache, id) {
    option.Some(cwd) -> {
      metrics.increment_cache_hits("id")
      Ok(cwd)
    }
    option.None -> {
      metrics.increment_cache_miss("id")
      debug_print("Not found in cache: " <> int.to_string(id))
      use xkcd <- result.try(xkcd.get_comic |> wrap_nil1(id))
      use body <- result.try(xkcd.get_image |> wrap_nil1(xkcd))
      use result <- result.try(
        graphics.to_kitty_protocol_string |> wrap_nil2(body, 4096),
      )

      cache.insert_comic(cache, xkcd)
      |> cache.insert_image(xkcd.number, result, body)

      debug_print("Found comic: " <> int.to_string(xkcd.number))
      metrics.increment_cached_elements()

      Ok(cache.ComicWithData(xkcd, result, body))
    }
  }

  let end = birl.now()
  print_duration(start, end)
  metrics.update_request_duration(start, end, "id")
  metrics.increment_processed_queries("id")
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

type PathResult {
  Json(json.Json, Int)
  Comic(cache.ComicWithData)
  Prometheus(String)
}

fn handler(base_path: String) -> fn(StatefulRequest) -> rr.MResponse {
  io.println("Serving at base path: " <> base_path)
  let base_path = uri.path_segments(base_path)

  fn(s: StatefulRequest) -> rr.MResponse {
    let ApplicationContext(cache, config, actor) as context = rr.state(s)
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

    let comic_or_error = fn(
      in: Result(cache.ComicWithData, Nil),
      message: String,
    ) {
      result.map(in, Comic)
      |> result.unwrap(ApiError(message) |> encode_api_error() |> Json(500))
    }

    let result = case path_segments {
      Ok(l) ->
        case l {
          ["health"] -> {
            build_health_check(context)
            |> encode_health_check
            |> Json(200)
          }
          ["metrics"] -> {
            metrics.update_memory()
            case themis.print() {
              Ok(s) -> Prometheus(s)
              Error(_) -> Prometheus("")
            }
          }
          ["random"] -> {
            handle_random(cache)
            |> comic_or_error("Failed to load random comic")
          }
          ["id", id] -> {
            case int.parse(id) {
              Ok(num) -> {
                handle_id(cache, num)
                |> comic_or_error("Failed to load comic")
              }
              Error(_) ->
                ApiError("Invalid id provided") |> encode_api_error |> Json(400)
            }
          }
          ["latest"] | [] -> {
            handle_latest()
            |> comic_or_error("Failed to load latest comic")
          }
          [alias] -> {
            let first_alias =
              list.filter(config.aliases, fn(x) { x.name == alias })
              |> list.first
            case first_alias {
              Ok(alias) ->
                case alias {
                  config.RandomAlias(_) -> {
                    handle_random(cache)
                    |> comic_or_error("Failed to load random comic")
                  }
                  config.LatestAlias(_) -> {
                    handle_latest()
                    |> comic_or_error("Failed to load latest comic")
                  }
                  config.IdAlias(_, id) -> {
                    handle_id(cache, id)
                    |> comic_or_error("Failed to load comic")
                  }
                }
              Error(_) -> {
                ApiError("Not found") |> encode_api_error |> Json(404)
              }
            }
          }
          _ -> {
            ApiError("Not found")
            |> encode_api_error
            |> Json(404)
          }
        }
      _ -> ApiError("Not found") |> encode_api_error |> Json(404)
    }

    case result {
      Json(data, code) -> {
        err.new(code)
        |> err.with_header("Content-Type", "application/json")
        |> err.with_header("X-Server-Version", version.gleeter_version)
        |> err.with_message([json.to_string_tree(data) |> string_tree.to_string])
        |> err.to_response(fn(_) { Nil })
      }
      Comic(cd) -> {
        process.send(actor, Inc)

        ok.ok()
        |> ok.with_header("Content-Type", "text/plain")
        |> ok.with_header("X-Server-Version", version.gleeter_version)
        |> ok.with_binary_body(cd |> to_printable(terminal_size))
      }
      Prometheus(result) -> {
        ok.ok()
        |> ok.with_header("Content-Type", "text/plain")
        |> ok.with_header("X-Server-Version", version.gleeter_version)
        |> ok.with_text_body(result)
      }
    }
    |> Ok
  }
}

pub fn serve(
  port: Int,
  base_path: String,
  cache: cache.Cache,
  config: config.Configuration,
) -> Nil {
  io.println("Serving on port " <> int.to_string(port))
  let assert Ok(actor) = actor.start(0, process_request)
  metrics.init()

  messua.default()
  |> messua.with_http(port)
  |> messua.with_binding("0.0.0.0")
  |> messua.with_state(ApplicationContext(cache, config, actor))
  |> messua.start(handler(base_path))

  process.sleep_forever()
}
