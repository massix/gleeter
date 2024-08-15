import birl
import gleam/bytes_builder
import gleam/dynamic
import gleam/hackney
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleam/uri

const base_url = "https://xkcd.com"

pub type Xkcd {
  Xkcd(
    publication_date: birl.Time,
    number: Int,
    link: option.Option(String),
    news: option.Option(String),
    safe_title: String,
    transcript: option.Option(String),
    alternative_text: String,
    img_url: uri.Uri,
    title: String,
  )
}

pub type APIError {
  DecodeError(reason: String)
  GenericError(reason: String)
  RequestError(reason: String)
}

fn to_birl_time(
  year year: String,
  month month: String,
  day day: String,
) -> Result(birl.Time, APIError) {
  birl.from_naive(year <> "-" <> month <> "-" <> day)
  |> result.map_error(fn(_) { GenericError("Could not parse date") })
}

pub fn api_decoder(in: String) -> Result(Xkcd, APIError) {
  let to_apierror = fn(in: json.DecodeError) -> APIError {
    case in {
      json.UnexpectedEndOfInput -> DecodeError("Unexpected end of input")
      json.UnexpectedByte(b) -> DecodeError("Unexpected byte: " <> b)
      json.UnexpectedSequence(s) -> DecodeError("Unexpected sequence: " <> s)
      json.UnexpectedFormat(_) -> DecodeError("Unexpected format")
    }
  }

  let day = dynamic.field("day", dynamic.string)
  let month = dynamic.field("month", dynamic.string)
  let year = dynamic.field("year", dynamic.string)
  let link = fn(in: dynamic.Dynamic) {
    use as_string <- result.try(dynamic.string(in))

    uri.parse(as_string)
    |> result.map_error(fn(_) { [dynamic.DecodeError("uri", "not an uri", [])] })
  }
  let maybe_empty_string = fn(in: dynamic.Dynamic) {
    dynamic.string(in)
    |> result.map(string.to_option)
  }

  use decoded_day <- result.try(
    json.decode(in, day) |> result.map_error(to_apierror),
  )
  use decoded_month <- result.try(
    json.decode(in, month) |> result.map_error(to_apierror),
  )
  use decoded_year <- result.try(
    json.decode(in, year) |> result.map_error(to_apierror),
  )

  use birl_time <- result.try(to_birl_time(
    year: decoded_year,
    month: decoded_month,
    day: decoded_day,
  ))

  let decoder =
    dynamic.decode9(
      Xkcd,
      fn(_) { Ok(birl_time) },
      dynamic.field("num", dynamic.int),
      dynamic.field("link", maybe_empty_string),
      dynamic.field("news", maybe_empty_string),
      dynamic.field("safe_title", dynamic.string),
      dynamic.field("transcript", maybe_empty_string),
      dynamic.field("alt", dynamic.string),
      dynamic.field("img", link),
      dynamic.field("title", dynamic.string),
    )

  json.decode(in, decoder)
  |> result.map_error(to_apierror)
}

fn hackney_error_to_apierror(in: hackney.Error) -> APIError {
  case in {
    hackney.InvalidUtf8Response -> RequestError("Received incompatible data")
    hackney.Other(_) -> RequestError("Generic error from Hackney")
  }
}

fn download(in: uri.Uri) -> Result(Xkcd, APIError) {
  use request <- result.try(
    request.from_uri(in)
    |> result.map_error(fn(_) { RequestError("Could not create request") }),
  )

  use response.Response(_, _, data) <- result.try(
    hackney.send(request)
    |> result.map_error(hackney_error_to_apierror),
  )

  api_decoder(data)
}

/// Returns the latest comic available for XKCD
pub fn get_latest() -> Result(Xkcd, APIError) {
  use uri <- result.try(
    uri.parse(base_url <> "/info.0.json")
    |> result.map_error(fn(_) { RequestError("Could not build URI") }),
  )

  download(uri)
}

/// Returns the comic identified by the id
pub fn get_comic(id: Int) -> Result(Xkcd, APIError) {
  use uri <- result.try(
    uri.parse(base_url <> "/" <> int.to_string(id) <> "/info.0.json")
    |> result.map_error(fn(_) { RequestError("Could not build URI") }),
  )

  download(uri)
}

/// Returns a random comic
pub fn get_random() -> Result(Xkcd, APIError) {
  use Xkcd(number:, ..) <- result.try(get_latest())

  let random_comic = int.random(number)
  get_comic(random_comic)
}

pub fn get_image(in: Xkcd) -> Result(BitArray, APIError) {
  use request <- result.try(
    request.from_uri(in.img_url)
    |> result.map(request.set_body(_, bytes_builder.new()))
    |> result.map_error(fn(_) { RequestError("Could not create request") }),
  )

  use response.Response(_, _, body) <- result.try(
    hackney.send_bits(request)
    |> result.map_error(hackney_error_to_apierror),
  )

  Ok(body)
}
