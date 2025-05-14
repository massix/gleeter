import birl
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/uri
import sqlight.{type Connection}
import xkcd/api

pub opaque type Cache {
  Faulty(error: String)
  Cache(path: String, db: Connection, operations: List(Operation))
}

pub type Operation {
  Insert(numbers: List(Int))
}

pub type ComicWithData {
  ComicWithData(comic: api.Xkcd, data: String)
}

const create_table_query = "
  pragma foreign_keys = on;

  create table if not exists comics(
    number int primary key not null,
    publication_date text not null,
    link text default null,
    news text default null,
    safe_title text not null,
    transcript text default null,
    alternative_text not null,
    img_url text not null,
    title text not null
  );

  create table if not exists images(
    comic_number int primary key references comics(number),
    image_data text not null
  );
"

const insert_table_comic_query = "
  insert into comics (number, publication_date, link, news, safe_title, transcript, alternative_text, img_url, title)
  values (?, ?, ?, ?, ?, ?, ?, ?, ?)
  returning number
"

const insert_table_image_query = "
  insert into images(comic_number, image_data)
  values(?, ?)
  returning comic_number
"

const select_comic_query = "
  select c.*, i.image_data from comics c join images i on i.comic_number = c.number where c.number = ?
"

fn convert_sqlight_error(in: sqlight.Error) -> String {
  let sqlight.SqlightError(_, desc, code) = in
  "sqlight error: "
  <> int.to_string(code)
  <> {
    case desc {
      "" -> ""
      x -> " - " <> x
    }
  }
}

fn with_cache_insert(cache: Cache, f: fn(Connection) -> Cache) -> Cache {
  case cache {
    Faulty(_) -> cache
    Cache(db:, ..) -> f(db)
  }
}

fn with_cache_select(cache: Cache, f: fn(Connection) -> Option(a)) -> Option(a) {
  case cache {
    Faulty(_) -> option.None
    Cache(db:, ..) -> f(db)
  }
}

pub fn new(path: String) -> Cache {
  case sqlight.open(path) {
    Ok(db) -> {
      case sqlight.exec(create_table_query, db) {
        Ok(_) -> Cache(path, db, [])
        Error(e) -> {
          convert_sqlight_error(e)
          |> Faulty
        }
      }
    }
    Error(e) -> {
      convert_sqlight_error(e)
      |> Faulty
    }
  }
}

pub fn insert_image(cache: Cache, comic_number: Int, data: String) -> Cache {
  use db <- with_cache_insert(cache)
  let insert_result =
    sqlight.query(
      insert_table_image_query,
      db,
      [sqlight.int(comic_number), sqlight.text(data)],
      decode.list(decode.int),
    )
    |> result.map(list.flatten)

  case insert_result {
    Error(e) -> convert_sqlight_error(e) |> Faulty
    Ok(result) -> {
      let assert Cache(operations: prev_ops, ..) = cache
      let new_ops = list.append(prev_ops, [Insert(result)])

      Cache(..cache, operations: new_ops)
    }
  }
}

pub fn insert_comic(cache: Cache, comic comic: api.Xkcd) -> Cache {
  use db <- with_cache_insert(cache)
  let api.Xkcd(
    number:,
    publication_date:,
    link:,
    news:,
    safe_title:,
    transcript:,
    alternative_text:,
    img_url:,
    title:,
  ) = comic

  let insert_result =
    sqlight.query(
      insert_table_comic_query,
      db,
      [
        sqlight.int(number),
        sqlight.text(publication_date |> birl.to_http),
        sqlight.nullable(sqlight.text, link),
        sqlight.nullable(sqlight.text, news),
        sqlight.text(safe_title),
        sqlight.nullable(sqlight.text, transcript),
        sqlight.text(alternative_text),
        sqlight.text(img_url |> uri.to_string),
        sqlight.text(title),
      ],
      decode.list(decode.int),
    )
    |> result.map(list.flatten)

  case insert_result {
    Ok(result) -> {
      let assert Cache(operations: prev_ops, ..) = cache
      let new_ops = list.append(prev_ops, [Insert(result)])

      Cache(..cache, operations: new_ops)
    }
    Error(e) -> convert_sqlight_error(e) |> Faulty
  }
}

pub fn get_comic(cache: Cache, id number: Int) -> Option(ComicWithData) {
  use db <- with_cache_select(cache)

  let decoder = {
    use number <- decode.field(0, decode.int)
    use publication_date <- decode.field(1, decode.string)
    use link <- decode.field(2, decode.optional(decode.string))
    use news <- decode.field(3, decode.optional(decode.string))
    use safe_title <- decode.field(4, decode.string)
    use transcript <- decode.field(5, decode.optional(decode.string))
    use alternative_text <- decode.field(6, decode.string)
    use img_url <- decode.field(7, decode.string)
    use title <- decode.field(8, decode.string)
    use comic_data <- decode.field(9, decode.string)

    let assert Ok(publication_date) = birl.from_http(publication_date)
    let assert Ok(img_url) = uri.parse(img_url)

    decode.success(ComicWithData(
      api.Xkcd(
        number:,
        publication_date:,
        link: link,
        news: news,
        safe_title:,
        transcript: transcript,
        alternative_text:,
        img_url:,
        title:,
      ),
      comic_data,
    ))
  }

  let result =
    sqlight.query(select_comic_query, db, [sqlight.int(number)], decoder)
    |> result.unwrap([])

  case list.first(result) {
    Ok(e) -> option.Some(e)
    Error(_) -> option.None
  }
}
