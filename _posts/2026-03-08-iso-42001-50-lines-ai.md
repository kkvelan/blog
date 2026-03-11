---
layout: post
title: "When 50 Lines of Code Turn an Application into an AI System: Visibility and Governance for ISO/IEC 42001"
date: 2026-03-08 12:00:00 +0000
---

![When 50 Lines of Code Turn an Application into an AI System: Visibility and Governance for ISO/IEC 42001]({{ site.baseurl }}/iso-42001-50-lines-ai/image1.webp)

A deterministic application can become an AI-enabled system through very small code changes. Sometimes as little as 50 lines that introduce a model call can transform a traditional application into one whose behaviour is influenced by AI; content, recommendations, or decisions then depend on the model. That shift creates a major governance challenge: the same system that was "just an application" is now in scope for ISO/IEC 42001 and must be identified, documented, and managed. This article is for cybersecurity leaders, AI governance professionals, architects, auditors, and implementers. It explains why identifying AI systems is harder than it sounds, what auditors are up against, and how implementers can build governance that makes AI usage visible and governable.

## 1. The Small Change That Changes Everything

From a governance perspective, what matters is not how many lines of code an application has, but whether its behaviour is influenced by an AI model. A large, rule-based system remains deterministic. A small change that adds a single model call can make the same system non-deterministic and subject to AI governance. That shift is often invisible at the process or documentation level; only code and integration points reveal it.

Consider a support ticket router. Originally it might classify tickets using fixed rules: keyword matching, category lookup tables, and priority thresholds. The behaviour is predictable; the system is not an AI system. A product team then adds a call to an external API that uses a language model to suggest category and priority. A developer adds a small module: an HTTP client, a prompt, and a call to the model API. The change may be a few dozen lines. Functionally, the system is now "smarter"; from a governance standpoint, it is now an AI system.

The following illustrates the kind of change that turns a deterministic path into an AI-influenced one. First, a purely rule-based classification:

```python
def classify_ticket(subject: str, body: str) -> dict:
    # Deterministic: rules only
    if "billing" in subject.lower() or "invoice" in body.lower():
        return {"category": "billing", "priority": "high"}
    if "login" in subject.lower():
        return {"category": "access", "priority": "medium"}
    return {"category": "general", "priority": "low"}
```

After the change, the same function delegates to a model for edge cases. The surface area of the change is small; the governance impact is large.

```python
def classify_ticket(subject: str, body: str) -> dict:
    # Try rules first
    if "billing" in subject.lower() or "invoice" in body.lower():
        return {"category": "billing", "priority": "high"}
    if "login" in subject.lower():
        return {"category": "access", "priority": "medium"}
    # AI-influenced path: model call
    response = model_client.complete(
        prompt=f"Classify support ticket. Subject: {subject}. Body: {body[:500]}.",
        max_tokens=50
    )
    return parse_model_response(response)  # category, priority from model
```

The application is now subject to AI governance: model behaviour affects decisions, and the organisation must identify, document, and manage it under ISO/IEC 42001.

## 2. Why This Creates an AI Governance Problem

Once the model is in the path, the system's outputs depend on the model's behaviour. That behaviour can change with model updates, prompt changes, or input distribution shift. The organisation needs to treat it as an AI system: inventory it, assess risk, define policies, and maintain documentation. If the change was never flagged to compliance or architecture, the system will not appear in the AI inventory. Auditors cannot validate what is not identified; implementers cannot govern what they do not know exists. ISO/IEC 42001 is not only about auditing AI systems; it is about building management processes that make AI usage visible and governable. Without a deliberate process, small, incremental additions of AI create invisible governance gaps.

## 3. Why Identifying AI Systems Is Harder Than Traditional Asset Identification

Many organisations already maintain an asset register. In frameworks such as ISO/IEC 27001, the focus is on information assets within the scope of the ISMS: applications, infrastructure, data, and often people or roles. You list them, classify them, assign ownership, and link them to risks and controls. The unit of account is the asset itself (e.g. "Support Ticket System," "CRM").

ISO/IEC 42001 asks for something different: an inventory of **AI systems**. The unit of account is not "any asset" but "a system in which AI influences decisions or outcomes." The same application may appear in both registers; in 42001 it is in scope only if and where AI is used. So 42001 requires an extra dimension: not just "what systems we have," but "where AI is used inside them." A 27001 asset register rarely captures that; it does not usually tag "contains model call" or "AI in decision path." AI may be introduced via third-party APIs, SaaS features, or internal microservices, with no central list of "AI projects." The inventory has to be discovered, not simply read from an existing register. Relying on the 27001 register alone is therefore insufficient for 42001.

## 4. Auditor Perspective: The Visibility and Inventory Challenge

Auditors must validate that the organisation has identified its AI systems in scope. That means assessing whether the discovery process is repeatable, documented, and sufficient to support the stated scope. If the organisation has not looked in the right places (e.g. codebases, API integrations, vendor capabilities), the auditor cannot rely on the inventory. The challenge is to design procedures that catch systems like the ticket router above: small changes with large governance implications. AI often appears at integration points (calls to model APIs, embeddings, SaaS ML features) or in internal services that are not named or documented as "AI." Auditors should check that the organisation has a defined process for discovering and maintaining the AI system inventory, that the process was applied consistently, and that the resulting scope is plausible given the organisation's size, industry, and use of technology. The objective is to gain confidence that the inventory is a reasonable basis for the AI management system, not that every possible AI use has been found. Perfect visibility is unrealistic; a repeatable discovery process and evidence that it is followed are what auditors should validate.

## 5. Auditor Risk: When Hidden AI Systems Undermine the Audit

A change in an application that turns it into an AI system (e.g. a few dozen lines adding a model call) is exactly the kind of change that creates **auditor risk**. The auditor is asked to form an opinion on whether the organisation's AI management system is adequate: whether AI systems are identified, risks are assessed, and controls are in place. If the organisation (or the auditor) does not account for the fact that small, local code or integration changes can turn a previously deterministic system into an AI system, the scope of the management system can be materially understated. Systems that should be in the inventory are missing; risks attached to those systems are not assessed; the auditor may be validating a picture that is incomplete. That gap is auditor risk: the risk that the audit conclusion is based on an inventory or scope that omits AI systems that fall within the intended scope of the management system. Auditors therefore need to understand this dynamic and to design procedures that address it (e.g. sampling codebases or integration points, challenging the discovery process, and assessing whether the organisation has considered "small change" scenarios). Acknowledging that a small change can create a large governance shift is part of assessing and mitigating auditor risk.

## 6. Implementor Perspective: How to Build Governance Around This Reality

Implementers face the same reality from the inside: they must set up AI governance so that the organisation can identify, document, and manage AI systems even when those systems emerge from small code changes. That starts with defining what qualifies as an AI system. A practical definition is: a system in which an AI model (internal or external) influences content, recommendations, or decisions that affect the organisation or its stakeholders. Rule-based logic alone does not qualify; once a model call influences the outcome, the system is in scope. With that definition in place, the implementer establishes an AI system inventory as the single source of truth: system name, purpose, where AI is used (e.g. classification, recommendation, generation), how it is implemented (internal model, external API, SaaS feature), and ownership. The inventory should be linked to architecture and risk assessments so it drives the rest of the management system. AI review should be integrated into architecture review and change management: when new services, integrations, or features are proposed, there is a checkpoint to ask whether AI is involved and whether the system belongs in the inventory. **Awareness training** is important: developers and product teams need to know that introducing a model API or an AI-backed SaaS feature triggers governance steps. Some organisations add **AI governance office hours** or **quick security review** paths so that teams can get fast, lightweight approvals for low-risk AI use without blocking delivery. Without awareness and accessible approval paths, AI will continue to appear in production without being captured in the inventory.

## 7. Governance Checkpoints and Approval Workflow

To prevent AI from being introduced without oversight, organisations should define clear checkpoints. Before a new external AI service or model integration goes into production, it should go through an approval process: who is allowed to sign off, what information must be documented (vendor, data flows, purpose, risk level), and how the system is added to the AI system inventory. The same applies to internal model deployments or material changes to existing AI use (e.g. prompt changes, model upgrades). Checkpoints can be embedded in architecture review boards, change advisory boards, or a dedicated AI governance review. The goal is not to block innovation but to ensure that every AI system is known, scoped, and managed.

### Shadow AI: A Consequence of Weak Governance and Missing Checkpoints

When there are no clear approval steps or when developers are unaware that AI use triggers governance, "Shadow AI" appears: AI usage that is not in the inventory, not approved, and not subject to the organisation's policies or risk controls. Examples include teams subscribing to external model APIs on a credit card, embedding SaaS features that use ML without checking data or compliance implications, or adding a small model call in a legacy application without telling anyone. Shadow AI is not necessarily malicious; it is often the result of speed and lack of awareness. The consequence is the same: the organisation cannot govern what it does not know about. Strong checkpoints and approval workflows, combined with discovery (see below), reduce Shadow AI by making AI use visible and expected to be registered.

## 8. Discovery Methods to Uncover Hidden or Unapproved AI Usage

Technical discovery complements governance checkpoints by finding AI that was introduced without going through them. Implementers and auditors can use a combination of methods:

- **Code scanning for AI SDKs:** Scan codebases for imports or dependencies that indicate model usage (e.g. OpenAI client libraries, Hugging Face, LangChain, vendor SDKs). Search for prompt construction, completion calls, and embedding APIs.
- **Dependency analysis:** Review dependency lists (e.g. package.json, requirements.txt, go.mod, Cargo.toml and Rust crates) for ML/AI libraries and API clients. Flag new or updated dependencies that suggest AI integration.
- **API integration review:** Identify outbound calls to model APIs, embeddings APIs, or vendor endpoints that document AI features. Use API inventories, network egress reviews, or integration documentation.
- **Infrastructure and service usage monitoring:** Review usage of internal ML platforms, model serving endpoints, or shared AI services. Monitor which applications or teams consume these services.
- **Vendor and SaaS capability review:** Periodically check whether purchased applications or platforms have introduced or expanded AI features (e.g. suggested replies, content moderation, summarisation) that process organisational data.

Architecture review and developer or product team interviews remain important: trace data flows, ask where classification, recommendation, or generation is performed, and which products call external AI services. Discovery should be repeatable and documented so that auditors can assess whether it was applied consistently.

## 9. Building and Maintaining the AI System Inventory

The AI system inventory is the central artefact. It should record, for each AI system: name, purpose, where AI is used (e.g. classification, recommendation, generation), how it is implemented (internal model, external API, SaaS feature), ownership, and linkage to risk assessment and controls. The inventory should be updated when new AI features are deployed, when integrations change, or when discovery finds previously unknown usage. It should be owned by a function that can enforce the process (e.g. AI governance, architecture, or risk). Linking the inventory to architecture and change management ensures that new systems are added at the right time and that the inventory stays actionable for the rest of the management system.

Some organisations go further with structures that, while not strictly required by ISO/IEC 42001, support consistent and governable AI use. An **approved AI register** (or approved AI services list) works like an approved list of base images (e.g. approved Docker or Linux images): only listed models, APIs, or vendors are permitted for production use unless an exception is documented. That makes discovery and policy enforcement easier. Where prompts drive material decisions, a **prompt registry** can be required: a central place to store, version, and review prompts used in production so that changes are visible and auditable. A **centralised LLM orchestration layer** is another option: all LLM calls are routed through one gateway or proxy. That gives a single point for logging, policy enforcement, and visibility into which applications use which models; it also simplifies discovery because outbound model traffic is concentrated in one place. These practices are organisational choices that complement the AI system inventory and make governance more tractable at scale.

## 10. Why Continuous Discovery Matters

Enterprises will never have perfect, real-time visibility into every line of code or every API call. New integrations and features are added continuously; 50 lines of code can turn an application into an AI system at any time. So discovery cannot be a one-off. It should be periodic (e.g. quarterly or as part of architecture or risk cycles) and triggered by significant events (e.g. new vendor onboarding, major releases, or post-incident reviews). The aim is not perfection but a repeatable, risk-based process that keeps the inventory accurate enough to support risk management and compliance. Continuous discovery, combined with governance checkpoints and developer awareness, is what makes AI usage visible and governable over time.

## 11. Conclusion: AI Governance Begins the Moment AI Influences System Behaviour

A deterministic application that gains a model call becomes an AI system under ISO/IEC 42001. The governance impact is large even when the code change is small. Identifying such systems is harder than traditional asset identification because 42001 requires knowing not only what systems exist but where AI is used inside them. Auditors validate that the organisation has a repeatable discovery process and a plausible inventory; implementers build that process by defining what counts as an AI system, establishing the inventory, introducing governance checkpoints and approval workflows, integrating AI review into architecture and change management, training developers, and applying technical discovery methods. Shadow AI is the consequence of weak governance and missing checkpoints; reducing it depends on making AI use visible and expected to be registered. ISO/IEC 42001 is not just about auditing AI systems; it is about building management processes that make AI usage visible and governable. AI governance begins the moment AI influences system behaviour, regardless of how many lines of code it took to get there.
