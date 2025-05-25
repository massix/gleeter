import birl
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/hackney
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleam/uri
import version

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
      json.UnableToDecode(_) -> DecodeError("Unable to decode")
    }
  }

  let parse_date = {
    use day <- decode.field("day", decode.string)
    use month <- decode.field("month", decode.string)
    use year <- decode.field("year", decode.string)

    decode.success(#(day, month, year))
  }

  use #(day, month, year) <- result.try(
    json.parse(in, parse_date)
    |> result.map_error(fn(_) { DecodeError("Could not parse date") }),
  )

  use publication_date <- result.try(to_birl_time(year:, month:, day:))

  let main_decoder = {
    use number <- decode.field("num", decode.int)
    use link <- decode.field("link", decode.string |> decode.optional)
    use news <- decode.field("news", decode.string |> decode.optional)
    use safe_title <- decode.optional_field("safe_title", "", decode.string)
    use transcript <- decode.field(
      "transcript",
      decode.string |> decode.optional,
    )
    use alternative_text <- decode.field("alt", decode.string)
    use img_url <- decode.field("img", decode.string)
    use title <- decode.field("title", decode.string)

    let img_url = case uri.parse(img_url) {
      Ok(uri) -> uri
      Error(_) -> uri.empty
    }

    decode.success(Xkcd(
      publication_date:,
      number:,
      link:,
      news:,
      safe_title:,
      transcript:,
      alternative_text:,
      img_url: img_url,
      title:,
    ))
  }

  json.parse(in, main_decoder)
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
    |> result.map(request.set_header(_, "User-Agent", version.user_agent))
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
    |> result.map(request.set_body(_, bytes_tree.new()))
    |> result.map_error(fn(_) { RequestError("Could not create request") }),
  )

  use response.Response(_, _, body) <- result.try(
    hackney.send_bits(request)
    |> result.map_error(hackney_error_to_apierror),
  )

  Ok(body)
}
