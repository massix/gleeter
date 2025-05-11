import birl
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/result
import gleam/uri
import sqlight
import xkcd/api

pub opaque type Cache {
  Faulty(error: String)
  Cache(path: String, db: sqlight.Connection, operations: List(Operation))
}

pub type Operation {
  Insert(numbers: List(Int))
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

fn with_cache(cache: Cache, f: fn(sqlight.Connection) -> Cache) -> Cache {
  case cache {
    Faulty(_) -> cache
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
  use db <- with_cache(cache)
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
  use db <- with_cache(cache)
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
