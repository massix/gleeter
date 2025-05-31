import argv
import gleam/int
import gleam/result

pub type ApplicationBehavior {
  RandomComic
  LatestComic
  WithIDComic(id: Int)
  PrintVersion
  Help
  Serve(port: Int, base_path: String)
}

pub fn get_application_behavior() -> ApplicationBehavior {
  let args = argv.load().arguments

  parse_arguments(args)
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

pub fn parse_arguments(args: List(String)) -> ApplicationBehavior {
  case args {
    [] | ["help", ..] -> Help
    ["version", ..] -> PrintVersion
    ["random", ..] -> RandomComic
    ["latest", ..] -> LatestComic
    ["id", id, ..] -> {
      case int.parse(id) {
        Ok(id) -> WithIDComic(id)
        _ -> LatestComic
      }
    }
    ["serve", ..rest] -> parse_serve(rest)
    _ -> PrintVersion
  }
}
