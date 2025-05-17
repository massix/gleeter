import gleam/bit_array
import gleam/erlang
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import simplifile
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
  let controls = chunks_to_kitty_controls(chunks, chunk_size, [])

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
  chunk_size: Int,
  acc: List(KittyControl),
) -> List(KittyControl) {
  case chunks {
    [] -> acc
    [Chunk(data, size), ..rest] -> {
      let option = {
        case size {
          x if x == chunk_size -> [#("m", "1")]
          _ -> []
        }
      }

      chunks_to_kitty_controls(
        rest,
        chunk_size,
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

/// Retrieve the current terminal size
pub fn get_terminal_size() -> #(Int, Int) {
  case term_size.get() {
    Ok(x) -> x
    Error(_) -> #(0, 0)
  }
}
