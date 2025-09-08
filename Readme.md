# DOSP Project-1: **Lukas Problem Solver** (Sums of Consecutive Squares)

**Course:** COP5615 — Distributed Operating Systems Principles (Fall 2025)  
**Group:** 084  
**Team Members:**  
- Trinesh Reddy Bayapureddy Sannala  
- Abhinav Lakkapragada

---

## Problem Statement
Find all sequences of **k** consecutive integers, with start `s ∈ [1, N]`, such that the **sum of their squares** is a perfect square. The program is parallelized using the **actor model** (boss/manager + workers). Inputs are `N` and `k`; outputs are the valid starting indices, one per line.

---

## Implementation Overview
- **Actor model / Boss–Worker pattern**
  - **Manager** partitions `[1..N]` into fixed-size **work units**, sends them to **Worker** actors, and collects results.
  - **Workers** check assigned sub-ranges for valid sequences and reply to the Manager.
  - Asynchronous message passing; no shared state; natural parallelism across cores.
- **Language/Runtime**
  - Implemented in **Gleam** on **Erlang/OTP**.
  - Clear separation: coordination (Manager) vs computation (Workers).

---

## Work Unit Size

A dynamic chunk sizing strategy is implemented to efficiently divide the workload:

- The "determine_task_size()" function calculates an optimal chunk size based on the input range.
- It aims for about 100 chunks with a minimum size of 1000.
- This approach adapts to different input sizes and system configurations.
- For small inputs, it creates fewer, larger chunks; for large inputs, it creates more chunks for better parallelization.
- The Gleam runtime handles scheduling of actors across available CPU cores, maximizing parallel processing.

---

## Result for `lukas 1000000 4`
**No valid sequences** were found (no start `s ∈ [1..1,000,000]` with `Σ_{i=0}^{3} (s+i)^2` a perfect square).

---

## System Specifications
- **CPU:** Ryzen 7 6000 series (16 cores)  
- **GPU:** RTX 3050 Ti (4 GB)  
- **RAM:** 16 GB

---

## Performance Metrics
- **Real Time:** **3.2015625** seconds  
- **User Time:** **12.9179688** seconds  
- **System Time:** **0.09375** seconds  
- **CPU Time (User + System):** **13.0117188** seconds  
- **CPU/REAL ratio (effective cores):** **4.06×**

The ratio of CPU time to Real time (~4.06×) indicates excellent multi-core utilization.

---

## Largest Problem Solved
- Successfully completed up to **N = 10,000,000** (with `k = 4`).  
- Beyond that, coordination overhead and memory footprint for actor scheduling/processes became the bottleneck on our machine.

---

## How to Build & Run
```bash
# Build
gleam build

# Run: lukas N k
gleam run -- 1000000 4
