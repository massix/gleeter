import argv
import gleam/int
import gleam/list
import gleam/result
import gleeter/config

pub type ApplicationBehavior {
  RandomComic
  LatestComic
  WithIDComic(id: Int)
  PrintVersion
  Help
  Serve(port: Int, base_path: String)
}

pub fn get_application_behavior(
  cfg: config.Configuration,
) -> ApplicationBehavior {
  let args = argv.load().arguments

  parse_arguments(args, cfg.aliases)
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
) -> ApplicationBehavior {
  case args {
    [] | ["help", ..] | ["--help", ..] -> Help
    ["version", ..] | ["--version", ..] -> PrintVersion
    ["random", ..] -> RandomComic
    ["latest", ..] -> LatestComic
    ["id", id, ..] -> {
      case int.parse(id) {
        Ok(id) -> WithIDComic(id)
        _ -> Help
      }
    }
    ["serve", ..rest] -> parse_serve(rest)
    [alias] -> {
      case list.filter(aliases, fn(x) { x.name == alias }) |> list.first() {
        Ok(alias) ->
          case alias {
            config.IdAlias(_, id) -> WithIDComic(id)
            config.LatestAlias(_) -> LatestComic
            config.RandomAlias(_) -> RandomComic
          }
        Error(_) -> Help
      }
    }
    _ -> Help
  }
}
