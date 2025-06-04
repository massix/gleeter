import gleam/dict
import gleam/list
import gleam/option
import simplifile
import tom

pub type Configuration {
  Configuration(
    random_start: option.Option(Int),
    max_cols: option.Option(Int),
    max_lines: option.Option(Int),
    aliases: List(Alias),
  )
}

pub type Alias {
  IdAlias(name: String, comic_id: Int)
  LatestAlias(name: String)
  RandomAlias(name: String)
}

fn default() -> Configuration {
  Configuration(
    random_start: option.None,
    max_cols: option.None,
    max_lines: option.None,
    aliases: [],
  )
}

type NextFunction(a) =
  fn(a) -> Configuration

fn or_default(in: Result(a, b), next: NextFunction(a)) -> Configuration {
  case in {
    Ok(a) -> next(a)
    Error(_) -> default()
  }
}

fn or_none(
  in: Result(a, b),
  next: NextFunction(option.Option(a)),
) -> Configuration {
  case in {
    Ok(a) -> next(option.Some(a))
    Error(_) -> next(option.None)
  }
}

fn or_empty(
  in: Result(List(a), b),
  next: NextFunction(List(a)),
) -> Configuration {
  case in {
    Ok(a) -> next(a)
    Error(_) -> next([])
  }
}

fn parse_alias(in: dict.Dict(String, tom.Toml)) -> option.Option(Alias) {
  let name = tom.get_string(in, ["name"]) |> option.from_result
  let alias_type = tom.get_string(in, ["type"]) |> option.from_result
  let comic_id = tom.get_int(in, ["id"]) |> option.from_result

  case name, alias_type, comic_id {
    option.Some(name), option.Some("id"), option.Some(comic_id) -> {
      IdAlias(name, comic_id) |> option.Some
    }
    option.Some(name), option.Some("latest"), _ -> {
      LatestAlias(name) |> option.Some
    }
    option.Some(name), option.Some("random"), _ -> {
      RandomAlias(name) |> option.Some
    }
    _, _, _ -> option.None
  }
}

pub fn parse(in: String) -> Configuration {
  use file_content <- or_default(simplifile.read(in))
  use parsed <- or_default(tom.parse(file_content))

  use random_start <- or_none(tom.get_int(parsed, ["random_start"]))
  use max_cols <- or_none(tom.get_int(parsed, ["screen", "max_cols"]))
  use max_lines <- or_none(tom.get_int(parsed, ["screen", "max_lines"]))

  use aliases <- or_empty(tom.get_array(parsed, ["alias"]))
  let aliases =
    list.map(aliases, fn(alias) {
      case tom.as_table(alias) {
        Ok(alias) -> parse_alias(alias)
        Error(_) -> option.None
      }
    })
    |> list.filter(option.is_some)
    |> list.map(option.unwrap(_, LatestAlias("nonexisting")))

  Configuration(random_start, max_cols, max_lines, aliases)
}
