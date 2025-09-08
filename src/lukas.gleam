import gleam/io
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/erlang/process

// Simplified message types
pub type WorkerMessage {
  ProcessRange(start: Int, end: Int, seq_length: Int, results: process.Subject(List(Int)))
}

pub type WorkerState {
  WorkerState
}

pub fn main() {
  // Get command line arguments
  let args = get_args()
  
  case parse_arguments(args) {
    Ok(#(max_num, seq_length)) -> {
      io.println("Starting search for N=" <> int.to_string(max_num) <> ", k=" <> int.to_string(seq_length))
      solve_problem(max_num, seq_length)
    }
    Error(error_msg) -> {
      io.println("Error: " <> error_msg)
      io.println("Usage: lukas <N> <k>")
      io.println("Where N is the maximum starting number and k is the sequence length")
    }
  }
}

fn get_args() -> List(String) {
  // Use a different approach to get command line arguments
  case erlang_get_plain_arguments() {
    args -> list.map(args, erlang_list_to_string)
  }
}

@external(erlang, "init", "get_plain_arguments")
fn erlang_get_plain_arguments() -> List(List(Int))

@external(erlang, "unicode", "characters_to_binary")
fn erlang_list_to_string(char_list: List(Int)) -> String

fn parse_arguments(args: List(String)) -> Result(#(Int, Int), String) {
  case args {
    [n_str, k_str] -> {
      case int.parse(n_str), int.parse(k_str) {
        Ok(n), Ok(k) -> {
          case n > 0, k > 0 {
            True, True -> Ok(#(n, k))
            _, _ -> Error("Both N and k must be positive integers")
          }
        }
        Error(_), _ -> Error("Invalid number format for N: " <> n_str)
        _, Error(_) -> Error("Invalid number format for k: " <> k_str)
      }
    }
    [] -> Error("No arguments provided")
    [_] -> Error("Missing second argument")
    _ -> Error("Too many arguments provided")
  }
}

fn solve_problem(max_num: Int, seq_length: Int) {
  // Create a results collection subject
  let results_subject = process.new_subject()
  
  // Determine work distribution
  let task_size = determine_task_size(max_num)
  let ranges = create_work_ranges(1, max_num, task_size)
  
  io.println("Manager: Task size = " <> int.to_string(task_size))
  io.println("Manager: Created " <> int.to_string(list.length(ranges)) <> " work ranges")
  
  // Start workers for each range
  let worker_count = list.length(ranges)
  list.each(ranges, fn(range) {
    let #(start, end) = range
    start_worker(start, end, seq_length, results_subject)
  })
  
  // Collect results from all workers
  let all_results = collect_results(results_subject, worker_count, [])
  
  // Display final results
  display_results(all_results)
}

fn create_work_ranges(start: Int, end: Int, task_size: Int) -> List(#(Int, Int)) {
  create_ranges_recursive(start, end, task_size, [])
}

fn create_ranges_recursive(start: Int, end: Int, task_size: Int, acc: List(#(Int, Int))) -> List(#(Int, Int)) {
  case start <= end {
    True -> {
      let range_end = int.min(start + task_size - 1, end)
      let new_range = #(start, range_end)
      create_ranges_recursive(range_end + 1, end, task_size, [new_range, ..acc])
    }
    False -> list.reverse(acc)
  }
}

fn start_worker(start: Int, end: Int, seq_length: Int, results_subject: process.Subject(List(Int))) {
  let worker_spec = 
    actor.new(WorkerState)
    |> actor.on_message(worker_actor)
  
  case actor.start(worker_spec) {
    Ok(worker) -> {
      io.println("Started worker for range " <> int.to_string(start) <> " to " <> int.to_string(end))
      process.send(worker.data, ProcessRange(start, end, seq_length, results_subject))
    }
    Error(_) -> {
      io.println("Failed to start worker for range " <> int.to_string(start) <> " to " <> int.to_string(end))
      // Send empty results if worker fails to start
      process.send(results_subject, [])
    }
  }
}

fn worker_actor(
  _state: WorkerState,
  message: WorkerMessage,
) -> actor.Next(WorkerState, WorkerMessage) {
  case message {
    ProcessRange(start, end, seq_length, results_subject) -> {
      io.println("Worker: Processing range " <> int.to_string(start) <> " to " <> int.to_string(end))
      
      let valid_starts = list.range(start, end)
        |> list.filter(fn(num) { is_valid_start(num, seq_length) })
      
      io.println("Worker: Found " <> int.to_string(list.length(valid_starts)) <> " valid starts in range")
      
      // Send results back
      process.send(results_subject, valid_starts)
      
      io.println("Worker: Finished processing range " <> int.to_string(start) <> " to " <> int.to_string(end))
      actor.stop()
    }
  }
}

fn collect_results(results_subject: process.Subject(List(Int)), remaining_workers: Int, acc: List(Int)) -> List(Int) {
  case remaining_workers {
    0 -> {
      io.println("Collected all results")
      acc
    }
    _ -> {
      io.println("Waiting for " <> int.to_string(remaining_workers) <> " more workers...")
      case process.receive(results_subject, 10000) {
        Ok(worker_results) -> {
          let combined_results = list.append(acc, worker_results)
          collect_results(results_subject, remaining_workers - 1, combined_results)
        }
        Error(_) -> {
          io.println("Timeout waiting for worker results")
          acc
        }
      }
    }
  }
}

fn is_valid_start(start_num: Int, seq_length: Int) -> Bool {
  let sum_squares = calculate_sum_of_squares(start_num, seq_length)
  let is_square = is_perfect_square(sum_squares)
  
  // Only show debug output for valid sequences
  case is_square {
    True -> {
      let sequence = list.range(0, seq_length - 1)
        |> list.map(fn(i) { start_num + i })
        |> list.map(int.to_string)
        |> list.fold("", fn(acc, x) { acc <> x <> " " })
      
      io.println("FOUND: sequence [" <> sequence <> "] sum=" <> int.to_string(sum_squares) <> " is perfect square")
    }
    False -> Nil
  }
  
  is_square
}

fn calculate_sum_of_squares(start_num: Int, seq_length: Int) -> Int {
  list.range(0, seq_length - 1)
  |> list.map(fn(i) {
    let num = start_num + i
    num * num
  })
  |> list.fold(0, int.add)
}

// Newton's method for perfect square detection
fn is_perfect_square(num: Int) -> Bool {
  case num {
    0 -> True
    n if n < 0 -> False
    _ -> {
      let result = newton_sqrt(num, num)
      result * result == num
    }
  }
}

fn newton_sqrt(num: Int, x: Int) -> Int {
  let y = { x + num / x } / 2
  case y < x {
    True -> newton_sqrt(num, y)
    False -> x
  }
}

fn determine_task_size(max_num: Int) -> Int {
  // For small test cases, use smaller task sizes
  case max_num {
    n if n <= 100 -> int.max(n / 4, 1)
    _ -> {
      let total_range = max_num
      int.min(int.max(total_range / 100, 1000), total_range)
    }
  }
}

fn display_results(valid_starts: List(Int)) -> Nil {
  let sorted_starts = list.sort(valid_starts, int.compare)
  
  case list.length(sorted_starts) {
    0 -> io.println("No solutions found")
    count -> {
      io.println("Found " <> int.to_string(count) <> " solution(s):")
      list.each(sorted_starts, fn(start) {
        io.println(int.to_string(start))
      })
    }
  }
}