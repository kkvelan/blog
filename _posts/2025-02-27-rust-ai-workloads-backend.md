---
layout: post
title: "Rust for AI Infrastructure"
date: 2025-02-27 12:00:00 +0000
---

Most conversations about AI focus on models and Python. But once you start building real systems around AI, concurrency, speed and performance become important.

![Rust for AI Infrastructure]({{ site.baseurl }}/rust-ai-workloads-backend/image1.jpeg)

## A Practical Scenario

Suppose you are building an agentic discovery system inside an enterprise network. The system continuously scans and enumerates thousands of internal systems, collects service details, tracks configuration changes, compares historical states, and feeds that data into an AI layer that reasons about risk or prioritization.

The challenge is not just inference.

You need to handle thousands of concurrent network operations, continuous scheduling, data parsing, state comparison, queue management, and long-running reliability. The system must run 24/7 without leaking memory, collapsing under load, or creating unpredictable latency spikes.

## Where Rust Fits

Rust gives you high-performance networking, controlled concurrency through async runtimes like Tokio, and compile-time guarantees that eliminate many common memory and race-condition problems. When you are managing thousands of parallel tasks (scanning, parsing responses, diffing results, feeding pipelines), those guarantees become extremely valuable.

Another advantage is **predictability**. Systems that continuously process large streams of data cannot afford garbage-collection pauses or silent memory growth. For example, imagine processing vulnerability data across thousands of systems, correlating scan results, tracking changes, and feeding prioritization pipelines. Rust's ownership model keeps resource usage explicit and stable even in long-running workloads like these.

In architectures like these, the AI model is just one component. Around it sits a large amount of infrastructure: discovery workers, schedulers, enrichment pipelines, storage layers, and APIs that expose results to analysts or other systems.

## Example: Concurrent Port Scanning with hping3

A typical backend component runs many scans concurrently but shapes traffic so the network and target are not overwhelmed. Below, we run **hping3** for SYN port scanning with bounded concurrency and send results into a channel for downstream processing (e.g. enrichment or an AI risk layer):

```rust
use tokio::process::Command;
use tokio::sync::{mpsc, Semaphore};
use std::sync::Arc;

struct ScanResult {
    target: String,
    port: u16,
    open: bool,
}

async fn run_hping3_scan(
    target: &str,
    port: u16,
) -> std::io::Result<ScanResult> {
    let out = Command::new("hping3")
        .arg("-S")
        .arg("-p")
        .arg(port.to_string())
        .arg("-c")
        .arg("1")
        .arg(target)
        .output()
        .await?;
    let open = out.status.success();
    Ok(ScanResult {
        target: target.into(),
        port,
        open,
    })
}

async fn run_concurrent_scans(
    tx: mpsc::Sender<ScanResult>,
    targets: Vec<String>,
    ports: Vec<u16>,
    max_concurrent: usize,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let sem = Arc::new(Semaphore::new(max_concurrent));
    let mut handles = Vec::new();
    for target in &targets {
        for &port in &ports {
            let tx = tx.clone();
            let permit = sem.clone().acquire_owned().await?;
            let target = target.clone();
            handles.push(tokio::spawn(async move {
                let _permit = permit;
                let result = run_hping3_scan(&target, port).await?;
                let _ = tx.send(result).await;
                Ok::<_, Box<dyn std::error::Error + Send + Sync>>(
                    (),
                )
            }));
        }
    }
    for h in handles {
        let _ = h.await;
    }
    Ok(())
}
```

Here, **packet shaping** is done by limiting concurrency with a `Semaphore` (e.g. `max_concurrent: 50`) so you do not flood the network or trigger rate limits. The channel `tx` feeds scan results to another task that can aggregate, store, or pass them to an AI pipeline.

## Agentic Vulnerability Assessment and Discovery

I am building an agentic vulnerability assessment and discovery system that ties together concurrent scanning, traffic shaping, and an AI layer for risk and prioritization. The pipeline uses **nmap** for port scanning and service discovery, **traceroute** and **tcptraceroute** for target intel and path analysis, and tools like hping3 for SYN probes, with results fed into an AI layer for reasoning about findings.

The system is designed to operate autonomously with minimal human intervention, scaling to thousands of IP addresses via continuous, batch, or scheduled execution. The goal is to reduce reliance on manual effort for probe orchestration, result analysis, and prioritization decisions.

## Architecture

The system is three tiers: **Node.js** frontend, **Python** backend, and **Rust** scanning agents.

- **Frontend (Node.js):** Create campaigns, upload targets, initiate scans, and monitor runs. The UI talks to the backend for orchestration and live status.
- **Backend (Python):** Orchestration, scheduling, and coordination. It hands work to scanning agents, receives status and progress updates, aggregates results, and drives reasoning or prioritization. Single control plane for the whole system.
- **Scanning agents (Rust):** Run on separate machines inside the network. Each agent performs the actual probing (nmap, traceroute, tcptraceroute, etc.), coordinates with the backend over the network, and reports status, progress, and results. Rust keeps scanning fast and predictable; the backend and frontend handle workflow and UX.

Agents register or poll the backend for work, stream progress and results back, and scale out by adding more machines. The frontend is where operators create campaigns, upload targets, and initiate scans.

## Useful Cargo Crates for AI Backends

These crates are commonly used when building Rust backends that sit alongside AI inference or orchestration:

| Crate | Purpose |
|-------|---------|
| **tokio** | Async runtime: networking, timers, concurrency |
| **axum** / **actix-web** | HTTP APIs to expose results or call Python services |
| **serde** / **serde_json** | Serialization for configs, API payloads, pipeline data |
| **reqwest** | Async HTTP client (call model APIs, internal services) |
| **tonic** | gRPC for high-throughput service-to-service calls |
| **redis** / **deadqueue** | Queues and caches for job distribution and rate limiting |
| **tracing** / **tracing-subscriber** | Structured logging and observability |
| **pyo3** | Embed or call Python from Rust when you need a model API |

Example `Cargo.toml` for a minimal AI-facing backend:

```toml
[package]
name = "ai-backend"
version = "0.1.0"
edition = "2021"

[dependencies]
tokio = { version = "1", features = ["full"] }
axum = "0.7"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
reqwest = { version = "0.11", default-features = false, features = ["json"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
```

## AI Backend Services That Use Rust

Several production AI backends and infra projects rely on Rust for speed and reliability:

- **Candle** (Hugging Face): ML inference engine in Rust. Used to run models (including LLMs) with minimal dependencies and good performance on CPU and GPU.
- **llm.rs / llama.cpp bindings**: Rust crates and tooling around fast inference runtimes, often used for local or edge deployment.
- **Inference servers and gateways**: Many custom inference gateways that sit in front of Python model servers are written in Rust for request routing, batching, rate limiting, and auth.
- **Vector DBs and embedding pipelines**: Services that index embeddings, run similarity search, or build RAG pipelines often use Rust for the hot path (e.g. **qdrant**, **milvus**-related components, or custom indexers).
- **Orchestration and agents**: Backends that schedule tasks, call multiple models, or run agent loops use Rust for the control plane and Python (or FFI) for the model calls.
- **Observability and telemetry**: Pipelines that ingest traces, metrics, or logs from AI workloads sometimes use Rust for high-throughput ingestion and aggregation.

These are examples of the split you see in practice: Python for model code and experimentation, Rust for the services that serve, scale, and orchestrate it.

## Python and Rust Together

The Python ecosystem remains central to AI development. Most model libraries, research tooling, and experimentation frameworks still live there. Python remains excellent for experimentation and model development.

In practice, many architectures benefit from both: **Python for model development** and **Rust for the high-performance backend infrastructure** around it.

When you need speed, safety, and concurrency in the always-on backend that powers AI systems, Rust becomes a very compelling choice.
