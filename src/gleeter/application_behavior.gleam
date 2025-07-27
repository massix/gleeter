import argv
import gleam/int
import gleam/list
import gleam/result
import gleeter/config

pub type ApplicationBehavior {
  RandomComic(ignore_cache: Bool)
  LatestComic(ignore_cache: Bool)
  WithIDComic(id: Int, ignore_cache: Bool)
  PrintVersion
  Help
  ClearCache
  Serve(port: Int, base_path: String)
}

pub fn get_application_behavior(
  cfg: config.Configuration,
) -> ApplicationBehavior {
  let args = argv.load().arguments

  parse_arguments(args, cfg.aliases, False)
}

fn parse_serve(args: List(String)) -> ApplicationBehavior {
  case args {
    [port, base_path, ..] -> {
      let port = int.parse(port) |> result.unwrap(8080)
      Serve(port, base_path)
    }
    [port, ..] -> {
      let port = int.parse(port) |> result.unwrap(8080)
      Serve(port, "")
    }
    [] -> Serve(8080, "")
  }
}

pub fn parse_arguments(
  args: List(String),
  aliases: List(config.Alias),
  ignore_cache: Bool,
) -> ApplicationBehavior {
  case args {
    [] | ["help", ..] | ["--help", ..] -> Help
    ["--no-cache", ..rest] | ["-n", ..rest] ->
      parse_arguments(rest, aliases, True)
    ["version", ..] | ["--version", ..] -> PrintVersion
    ["random", ..] -> RandomComic(ignore_cache)
    ["latest", ..] -> LatestComic(ignore_cache)
    ["clearcache", ..] -> ClearCache
    ["id", id, ..] -> {
      case int.parse(id) {
        Ok(id) -> WithIDComic(id, ignore_cache)
        _ -> Help
      }
    }
    ["serve", ..rest] -> parse_serve(rest)
    [alias] -> {
      case list.filter(aliases, fn(x) { x.name == alias }) |> list.first() {
        Ok(alias) ->
          case alias {
            config.IdAlias(_, id) -> WithIDComic(id, ignore_cache)
            config.LatestAlias(_) -> LatestComic(ignore_cache)
            config.RandomAlias(_) -> RandomComic(ignore_cache)
          }
        Error(_) -> Help
      }
    }
    _ -> Help
  }
}
