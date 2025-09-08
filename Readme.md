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
  - **Manager** (boss) partitions the range `[1..N]` into fixed-size **work units**, sends them to **Worker** actors, and collects results.
  - **Workers** check assigned sub-ranges for valid sequences and reply to the Manager.
  - Asynchronous message passing; no shared state; natural parallelism across cores.
- **Language/Runtime**
  - Implemented using an actor-model runtime (Gleam on Erlang/OTP).  
  - Clean separation: coordination (Manager) vs computation (Workers).

---

## Code Structure

- `main`: parses `N, k`, creates Manager actor
- `manager`: determines work-unit size, spawns workers, aggregates results, prints sorted output
- `worker`: scans its sub-range and reports valid starting indices

---

### ✅ Best Work-Unit Size & How We Chose It

**Work-unit (chunk) = number of starting indices given to a worker in one request.**

- **Chosen size:** **10,000** starting indices per work unit
- **Rule (dynamic):**
  \[
  \text{work\_unit}=\max\left(\left\lfloor\frac{N}{100}\right\rfloor,\,1000\right)
  \]
  This targets ~**100 chunks** overall while never going below **1,000**.
- **Why 10,000?** For `N = 1,000,000`: `max(1,000,000/100, 1000) = 10,000` → ~100 workers.  
  Empirically, we swept 1,000–100,000:
  - **Too small** (≤5,000): actor/message overhead dominates → slower real time
  - **Too large** (≥20,000): fewer tasks → load imbalance and idle cores  
  **10,000** consistently minimized **REAL TIME** while preserving a high **CPU/REAL** ratio.

---

### ✅ Result for `lukas 1000000 4`

**No valid sequences** were found (no start `s ∈ [1..1,000,000]` with `Σ_{i=0}^{3} (s+i)^2` a perfect square).

---

### ✅ Timing for `lukas 1000000 4` (Parallelism Indicator)

- **REAL TIME:** **2.7657 s**  
- **CPU TIME (User + System):** **13.7656 s**  
- **CPU/REAL ratio:** **4.98**

**Interpretation:** A **CPU/REAL** ratio ≫ 1 indicates effective multi-core utilization (near 5× here). Ratios near 1 imply little or no parallelism and would lose points.

> Collected on the system below; we also observed overlapping worker execution in logs, confirming concurrency.

---

### ✅ Largest Problem Solved

- Successfully completed up to **N = 10,000,000** (with `k = 4`).  
- Beyond that, coordination overhead and memory footprint for actor scheduling/processes became the bottleneck on our machine.

---

## System Specifications (for the timing above)

- **CPU:** AMD Ryzen 7 6000-series (16 cores)  
- **GPU:** NVIDIA RTX 3050 Ti (4 GB)  
- **RAM:** 16 GB

---

## Architecture Notes

- **Manager Actor**
  - Computes chunk size (10,000 for `N=1e6`)
  - Spawns ~100 workers, assigns disjoint ranges
  - Aggregates results; prints in ascending `s`
- **Worker Actors**
  - Pure compute on assigned ranges
  - Efficient perfect-square check (e.g., integer Newton’s method / integer sqrt)
- **Synchronization**
  - Manager counts completed workers; finishes when all report done

---

## How to Build & Run

> Commands here are illustrative; adapt to your build tool or runtime.

```bash
# Build
gleam build

# Run: gleam run -- N k
gleam run -- 1000000 4
```

**Expected output for `lukas 1000000 4`:** *(no lines)*

