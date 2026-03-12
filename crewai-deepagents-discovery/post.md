---
layout: post
title: "CrewAI and Deep Agents for Agentic Discovery"
date: 2026-03-02 12:00:00 +0000
---

Agentic discovery needs more than a single model call: planning, task decomposition, tool use, and coordination with workers that do the actual probing. Frameworks like CrewAI and LangChain Deep Agents are built for that. This post explains both and uses a concrete system as the example.

![CrewAI and Deep Agents for agentic discovery]({{ site.baseurl }}/crewai-deepagents-discovery/image1.png)

## ProbeScout: What We Are Building and Why

I am building an agentic vulnerability assessment and discovery system (ProbeScout) that ties together concurrent scanning, traffic shaping, and an AI layer for risk and prioritization. The pipeline uses nmap for port scanning and service discovery, traceroute and tcptraceroute for target intel and path analysis, and tools like hping3 for SYN probes, with results fed into an AI layer for reasoning about findings.

The system is designed to operate autonomously with minimal human intervention, scaling to thousands of IP addresses via continuous, batch, or scheduled execution. The goal is to reduce reliance on manual effort for probe orchestration, result analysis, and prioritization decisions.

To get there, the orchestration layer must plan campaigns, decompose work into batches or phases, keep context under control when scan output is large, and delegate analysis without overloading a single prompt. That is exactly the kind of workload agent frameworks target: multi-step tasks, tool use, and structured execution. Below we look at CrewAI and Deep Agents and where they fit in a setup like ProbeScout.

## Where the Agent Layer Runs

ProbeScout runs as three tiers:

- Frontend (Node.js): Create campaigns, upload targets, initiate scans, monitor runs. Talks to the backend for orchestration and live status.
- Backend (Python): Orchestration, scheduling, coordination. Assigns work to Rust scanning agents, receives status and progress updates, aggregates results, and drives reasoning or prioritization. This is where CrewAI or Deep Agents run.- Scanning agents (Rust): Run on separate machines in the network. Perform probing (nmap, traceroute, tcptraceroute, etc.), coordinate with the backend, and report status, progress, and results.

The backend uses tools to dispatch work to Rust agents (e.g. "run nmap on this target", "run traceroute", "store result in X") and to push status and results to the frontend.

## CrewAI

[CrewAI](https://www.crewai.com/) lets you define agents with roles and goals and crews that work together on tasks. In a system like ProbeScout, you can assign different agents to different stages in the Python backend: one agent for target selection or campaign planning, one for dispatching work to Rust agents and collecting progress, one for result analysis and prioritization. Tasks can be chained and delegated, which fits a pipeline where the frontend creates a campaign, the backend decomposes it and hands batches to Rust agents, and results flow back for analysis and display. Useful when you want a clear separation of roles and a crew that collaborates on a shared goal.

## LangChain Deep Agents

[Deep Agents](https://docs.langchain.com/oss/python/deepagents/overview) (from the LangChain ecosystem) are built for complex, multi-step tasks with built-in support for:

- Planning and task decomposition – e.g. break a campaign into batches or phases and track progress as Rust agents report back.
- Context management – file system tools (`read_file`, `write_file`, etc.) so the backend can offload scan results and logs instead of blowing the context window.
- Subagent spawning – delegate a subtask (e.g. "analyze this subnet's results" or "correlate these ports") to a dedicated agent and keep the main orchestrator's context focused.
- Pluggable backends – in-memory, local disk, or durable stores for state and context, so the backend can scale and persist across restarts.
- Long-term memory – persist facts or preferences across runs for a more consistent scanning and prioritization strategy.

The Deep Agents SDK is a standalone library on top of LangChain and uses LangGraph for execution, streaming, and human-in-the-loop. In ProbeScout, running in the Python backend, it would coordinate with Rust scanning agents via your existing APIs, aggregate status and results, and drive what the frontend shows and what work gets sent next.

## How It Fits Today

In the current setup, the Node.js frontend is where operators create campaigns, upload targets, and initiate scans. The Python backend runs the orchestration and reasoning; that is where you integrate CrewAI or Deep Agents. They call into your Rust agents (via the same coordination channel you already use for status, progress, and results), handle planning and decomposition, and use file system or backend storage to keep scan output and state manageable. Rust agents stay focused on probing; the backend stays focused on what to run and what it means. Either framework fits this split.

## Summary

CrewAI gives you role-based agents and crews in the Python backend for collaborative planning, dispatch, and analysis. Deep Agents give you planning, decomposition, context management, subagents, and pluggable backends in one stack, also in the backend. In a system like ProbeScout, both coordinate with Rust scanning agents on separate machines and with the Node.js frontend that creates campaigns, uploads targets, and initiates scans. The architecture stays: Node.js frontend, Python backend (with CrewAI or Deep Agents), Rust scanning agents; the agent layer is the brain in the middle.
