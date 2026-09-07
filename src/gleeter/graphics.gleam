import gleam/bit_array
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import gleeter/debug.{debug_print}
import gleeter/png
import term_size

pub type Chunk {
  Chunk(data: String, size: Int)
}

pub type KittyControl {
  KittyControl(options: List(#(String, String)), payload: String)
}

pub fn kitty_control_to_string(in: KittyControl) -> String {
  let tuple_to_string = fn(t) -> String {
    let #(key, value) = t
    key <> "=" <> value
  }

  string_tree.new()
  |> string_tree.append("\u{001b}_G")
  |> string_tree.append(
    list.map(in.options, tuple_to_string) |> string.join(","),
  )
  |> string_tree.append(";")
  |> string_tree.append(in.payload)
  |> string_tree.append("\u{001b}\\")
  |> string_tree.to_string
}

pub type GraphicsError {
  ChunkNotMultipleOf4
  ChunkSizeTooBig
}

pub fn to_kitty_protocol_string(
  data: BitArray,
  chunk_size: Int,
) -> Result(String, GraphicsError) {
  use chunks <- result.try(image_to_chunks(data, chunk_size))
  let controls = chunks_to_kitty_controls(chunks, [])

  // The first control *must* contain the graphics type for Kitty
  let controls =
    list.index_map(controls, fn(control, index) {
      let KittyControl(options, payload) = control
      case index {
        0 -> {
          let options = list.append(options, [#("a", "T"), #("f", "100")])
          KittyControl(options, payload)
        }
        _ -> control
      }
    })

  Ok(list.map(controls, kitty_control_to_string) |> string.join(""))
}

// -- Helper function for to_kitty_protocol_string
pub fn chunks_to_kitty_controls(
  chunks: List(Chunk),
  acc: List(KittyControl),
) -> List(KittyControl) {
  case chunks {
    [] -> acc
    [Chunk(data:, ..), ..rest] -> {
      let option = {
        case list.is_empty(rest) {
          True -> [#("m", "0")]
          False -> [#("m", "1")]
        }
      }

      chunks_to_kitty_controls(
        rest,
        list.append(acc, [KittyControl(option, data)]),
      )
    }
  }
}

/// Given a binary string depicting an image, convert it into base64 chunks
/// for the Kitty graphics protocol. The chunks' size must be divisible by 4
/// and the maximum size is 4096 bytes.
pub fn image_to_chunks(
  data: BitArray,
  chunk_size: Int,
) -> Result(List(Chunk), GraphicsError) {
  use chunk_size <- result.try({
    case chunk_size {
      x if x > 4096 -> Error(ChunkSizeTooBig)
      x if x % 4 != 0 -> Error(ChunkNotMultipleOf4)
      _ -> Ok(chunk_size)
    }
  })

  Ok(
    string_split_into_chunks(
      data |> bit_array.base64_encode(True),
      chunk_size,
      [],
    ),
  )
}

/// -- Helper function for image_to_chunks
pub fn string_split_into_chunks(
  in: String,
  chunk_size: Int,
  acc: List(Chunk),
) -> List(Chunk) {
  case string.length(in) {
    x if x == 0 -> acc
    x if x < chunk_size -> list.append(acc, [Chunk(in, x)])
    x -> {
      let first_part = string.slice(in, 0, chunk_size)
      let second_part = string.slice(in, chunk_size, x)

      string_split_into_chunks(
        second_part,
        chunk_size,
        list.append(acc, [Chunk(first_part, chunk_size)]),
      )
    }
  }
}

pub type TerminalSize {
  TerminalSize(rows: Int, columns: Int)
}

/// Retrieve the current terminal size
pub fn get_terminal_size() -> TerminalSize {
  case term_size.get() {
    Ok(x) -> TerminalSize(x.0, x.1)
    Error(_) -> TerminalSize(0, 0)
  }
}

pub type Rows =
  Int

pub type Columns =
  Int

pub fn calculate_new_size(
  image_size: png.ImageSize,
  terminal_size: TerminalSize,
) -> #(Rows, Columns) {
  let TerminalSize(columns:, rows:) = terminal_size
  let png.ImageSize(width:, height:) = image_size
  debug_print(
    "Image size: " <> int.to_string(width) <> "x" <> int.to_string(height),
  )

  let image_aspect = int.to_float(width) /. int.to_float(height)

  debug_print("Image aspect: " <> float.to_string(image_aspect))

  // Make sure we use at most 80% of the height of the terminal
  let max_rows = int.to_float(rows) *. 0.8
  let max_columns = int.to_float(columns) *. 0.8
  debug_print("Max rows: " <> float.to_string(max_rows))
  debug_print("Max columns: " <> float.to_string(max_columns))

  let columns = max_rows *. image_aspect *. 2.0
  debug_print("Columns: " <> float.to_string(columns))

  let rows = max_columns /. image_aspect
  debug_print("Rows: " <> float.to_string(rows))

  case columns >. max_columns {
    False -> #(max_rows |> float.round(), columns |> float.round())
    True -> #(rows /. 2.0 |> float.round, max_columns |> float.round())
  }
}

// PERF: This is a horrible workaround waiting for me to fix the way the cache works
pub fn resize_image(
  in: String,
  image_size: png.ImageSize,
  terminal_size: TerminalSize,
) -> String {
  let #(rows, cols) = calculate_new_size(image_size, terminal_size)
  debug_print(
    "Resizing image to " <> int.to_string(rows) <> "x" <> int.to_string(cols),
  )

  string.replace(
    in,
    "a=T,f=100",
    "a=T,f=100,X=32,r="
      <> rows |> int.to_string()
      <> ",c="
      <> cols |> int.to_string(),
  )
}
