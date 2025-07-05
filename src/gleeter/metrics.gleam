import birl
import birl/duration
import gleam/dict
import gleam/int
import gleam/list
import gleam/set
import themis
import themis/counter
import themis/gauge
import themis/histogram
import themis/number

const request_duration = "gleeter:http_request_duration_seconds"

const processed_queries = "gleeter:processed_queries_total"

const cache_hits = "gleeter:cache_hits_total"

const cache_miss = "gleeter:cache_miss_total"

const cached_elements = "gleeter:cached_elements_total"

const memory_used = "gleeter:memory_used_bytes"

const invalid_requests = "gleeter:http_invalid_requests_total"

type Memory {
  Processes(m: Int)
  ProcessesUsed(m: Int)
  System(m: Int)
  Atom(m: Int)
  AtomUsed(m: Int)
  Binary(m: Int)
  Code(m: Int)
  Ets(m: Int)
  Total(m: Int)
}

@external(erlang, "erlang", "memory")
fn memory() -> List(Memory)

pub fn init() -> Nil {
  let _ = themis.init()

  // Init some metrics
  let assert Ok(_) = counter.new(cached_elements, "Number of elements in cache")
  let assert Ok(_) =
    counter.new(processed_queries, "Number of processed queries")
  let assert Ok(_) = counter.new(cache_hits, "Number of cache hits")
  let assert Ok(_) = counter.new(cache_miss, "Number of cache misses")
  let assert Ok(_) =
    counter.new(invalid_requests, "Number of invalid HTTP requests")
  let assert Ok(_) =
    gauge.new(memory_used, "Memory used in bytes by the Erlang VM")

  let buckets =
    set.from_list([
      number.decimal(0.1),
      number.decimal(0.25),
      number.decimal(0.5),
      number.decimal(0.75),
      number.decimal(1.0),
      number.decimal(1.5),
    ])
  let assert Ok(_) =
    histogram.new(request_duration, "Duration of a request in seconds", buckets)
  Nil
}

pub fn update_request_duration(
  start: birl.Time,
  end: birl.Time,
  method: String,
) -> Nil {
  let duration =
    {
      birl.difference(end, start)
      |> duration.blur_to(duration.MilliSecond)
      |> int.to_float
    }
    /. 1000.0
    |> number.decimal

  let labels = dict.from_list([#("method", method)])
  let assert Ok(_) = histogram.observe(request_duration, labels, duration)
  Nil
}

pub fn increment_processed_queries(method: String) -> Nil {
  let labels = dict.from_list([#("method", method)])
  let assert Ok(_) = counter.increment(processed_queries, labels)
  Nil
}

pub fn increment_invalid_requests() -> Nil {
  let labels = dict.new()
  let assert Ok(_) = counter.increment(invalid_requests, labels)
  Nil
}

pub fn increment_cached_elements() -> Nil {
  let assert Ok(_) = counter.increment(cached_elements, dict.new())
  Nil
}

pub fn increment_cache_hits(method: String) -> Nil {
  let labels = dict.from_list([#("method", method)])
  let assert Ok(_) = counter.increment(cache_hits, labels)
  Nil
}

pub fn increment_cache_miss(method: String) -> Nil {
  let labels = dict.from_list([#("method", method)])
  let assert Ok(_) = counter.increment(cache_miss, labels)
  Nil
}

pub fn update_memory() -> Nil {
  list.each(memory(), fn(m) {
    let #(label, memory) = case m {
      System(m) -> #("system", m)
      Processes(m) -> #("processes", m)
      ProcessesUsed(m) -> #("processes_used", m)
      Ets(m) -> #("ets", m)
      Code(m) -> #("code", m)
      Binary(m) -> #("binary", m)
      AtomUsed(m) -> #("atom_used", m)
      Atom(m) -> #("atom", m)
      Total(m) -> #("total", m)
    }

    gauge.observe(
      memory_used,
      dict.from_list([#("slice", label)]),
      number.integer(memory),
    )
  })

  Nil
}
