import argv
import gleam/int

pub type ApplicationBehavior {
  RandomComic
  LatestComic
  WithIDComic(id: Int)
  PrintVersion
}

pub fn get_application_behavior() -> ApplicationBehavior {
  let args = argv.load().arguments

  parse_arguments(args, RandomComic)
}

pub fn parse_arguments(
  args: List(String),
  last: ApplicationBehavior,
) -> ApplicationBehavior {
  case args {
    [] -> last
    ["version", ..] -> PrintVersion
    ["random", ..rest] -> parse_arguments(rest, RandomComic)
    ["latest", ..rest] -> parse_arguments(rest, LatestComic)
    ["id", id, ..rest] -> {
      case int.parse(id) {
        Ok(id) -> parse_arguments(rest, WithIDComic(id))
        _ -> parse_arguments(rest, last)
      }
    }
    _ -> last
  }
}
