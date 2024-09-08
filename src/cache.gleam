import birl
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/uri
import sqlight
import xkcd/api

pub opaque type CacheSystem {
  Empty
  Inited(path: String, db: sqlight.Connection)
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
  insert into comics
    (number, publication_date, link, news, safe_title, transcript, alternative_text, img_url, title)
  values
    (?, ?, ?, ?, ?, ?, ?, ?, ?)
  returning number
"

const insert_table_image_query = "
  insert into images(comic_number, image_data) values(?, ?)
"

fn print_sqlight_error(in: sqlight.Error) -> Nil {
  let sqlight.SqlightError(_, desc, code) = in
  io.println_error("sqlight error: " <> int.to_string(code) <> ", " <> desc)
}

pub fn new(path: String) -> CacheSystem {
  case sqlight.open(path) {
    Ok(db) -> {
      case sqlight.exec(create_table_query, db) {
        Ok(_) -> Inited(path, db)
        Error(e) -> {
          io.println_error("Warning: could not init cache system from " <> path)
          print_sqlight_error(e)
          Empty
        }
      }
    }
    Error(e) -> {
      io.println_error("Warning: could not retrieve cache from: " <> path)
      print_sqlight_error(e)
      Empty
    }
  }
}

pub fn insert_comic(cache: CacheSystem, comic comic: api.Xkcd) -> CacheSystem {
  case cache {
    Empty -> Empty
    Inited(db:, ..) -> {
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
          dynamic.element(0, dynamic.int),
        )

      case insert_result {
        Ok(_) -> Nil
        Error(e) -> print_sqlight_error(e)
      }

      cache
    }
  }
}
