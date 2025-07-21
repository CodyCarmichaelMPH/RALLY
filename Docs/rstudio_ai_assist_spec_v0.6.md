# RStudio AI‑Assist Add‑in — **Full Spec v0.6 (MVP Lock)**
*“One file to rule them all” – everything you need before the first line of code.*

---

## 0 ▸ Elevator Pitch  
A **local‑first** RStudio/Posit add‑in that gives Copilot‑style chat, inline completions, diff‑apply, meta‑prompts and **file‑tag references** while demanding *zero* extra permissions beyond normal add‑ins. Ollama is the default LLM backend; cloud endpoints are opt‑in fallbacks.

---

## 1 ▸ Target Audience  
- Solo data‑scientists, epidemiologists & educators who can’t ship code or data to the cloud.  
- Enterprise teams in regulated zones (health, finance, gov) needing on‑prem AI.  
- Folks who value simple install: `pak::pak("rstudioai")` + `brew install ollama`.

---

## 2 ▸ Core Data Models  

| Model | Key Fields / Relationships | Purpose |
|-------|---------------------------|---------|
| **Session** | `id` (uuid), `started_at`, `active_doc_path`, `model` | One chat / completion interaction bound to a doc |
| **Prompt** | FK `session`, `role` (user/assistant/sys), `content`, `created_at` | Turn log for replay/audit |
| **Completion** | FK `prompt`, `raw_json`, `insert_range`, `applied` (bool) | Captures LLM output & where it landed |
| **FilePatch** | FK `session`, `doc_id`, `diff`, `applied_at` | Atomic diff enabling undo/redo |
| **RuleFile** | `path` (unique), `type` (`always/auto/manual/agent`), `globs_json`, `etag`, `content`, `modified_at` | Cached Markdown meta‑prompts |
| **Tag** | `label`, `target_path`, `kind` (`file/folder/url`), `created_at` | Points the LLM at project artefacts |
| **Config** *(singleton)* | `default_model`, `fallback_endpoint`, `temp`, `max_tokens`, `safety_checks_json` | User‑editable runtime knobs |
| **Telemetry** | `event`, `payload_json`, `ts` | Anonymous, opt‑in usage pings |

> *Why “Tag”?* Lets users pin big CSVs, README sections or entire folders with a short handle (`@sales_csv`) so the model can request a snippet on demand.

---

## 3 ▸ Feature Matrix at MVP Lock  

| Feature | Included? | Notes |
|---------|-----------|-------|
| Chat side‑pane (Shiny) | ✅ | Streams tokens, supports markdown + code blocks |
| Inline completion (⌥+↩) | ✅ | Uses selection + 200 line context |
| Meta‑prompts via `*.ai‑rules.md` | ✅ | Cursor‑style but Markdown |
| File / folder tagging | ✅ | `Add‑in → Tag current file` or manual YAML |
| Diff‑apply & undo stack | ✅ | FilePatch model |
| Local Ollama backend | ✅ | REST `http://127.0.0.1:11434` |
| Cloud fallback endpoint | ✅ | Off by default |
| Opt‑in telemetry | ✅ | GDPR‑friendly, anonymised |
| Multi‑file refactor agent | ❌ | Post‑MVP (v1.0) |
| Multimodal (image) support | ❌ | Post‑MVP |

---

## 4 ▸ User‑Visible Workflow  

```
[Hot‑key or Add‑in click]
         ↓ Trigger Listener
         ↓ Context Collector
         ↓ Rule Resolver
         ↓ Tag Resolver  ← NEW
         ↓ Prompt Builder (merges rules + tag stubs)
         ↓ Model Router  (Ollama → fallback)
         ↓ Response Post‑Processor
         ↓ Apply & Display  (FilePatch + Chat pane)
         ↘ Undo/Redo Service
```

### 4.1 **Tag Resolver** (new logic)  
1. **Syntax** in prompts:  
   - Inline handle: `@sales_csv`  
   - Free‑form: “see `<<data/sales_2024.csv>>`”  
2. Resolver maps handle ➝ `Tag` row ➝ file path.  
3. Up to **`MAX_TAG_BYTES`** of the file are streamed into the final prompt chunk **only if**:  
   - User included the tag explicitly **or**  
   - Model emitted `@request_tag(sales_csv)` tool call (agent type).  
4. For large files, heuristic sample: head 20 rows + tail 20 rows + schema summary.  

---

## 5 ▸ Settings & Defaults  

| Setting | Default | Meaning |
|---------|---------|---------|
| `OLLAMA_MODEL` | `"llama3:8b"` | Any model label accepted by Ollama |
| `TIMEOUT_SECONDS` | 60 | Per request |
| `TEMP` | 0.7 | Passed to backend |
| `MAX_CONTEXT_LINES` | 200 | Trim source doc |
| `RULE_FILE_PATTERN` | `"*.ai-rules.md"` | Glob for meta‑prompts |
| `MAX_RULE_TOKENS` | 1 000 | Safety ceiling |
| `MAX_TAG_BYTES` | 32 kB | Prevent huge CSV dumps |
| `ENABLE_TELEMETRY` | `FALSE` | Opt‑in |

---

## 6 ▸ UI Touch‑points  

| Surface | Enhancement |
|---------|-------------|
| **Chat Pane** | Tabs: *Chat* · *Completions* · *Rules* · *Tags* |
| **Rules Tab** | List rules, size badges, toggle `manual` rules |
| **Tags Tab** | Quick‑add current file/folder, click to open |
| **Command Palette** | “AI‑Assist: Create Rule”, “AI‑Assist: Tag File” |
| **Status Bar** | Live token counter ++ model name badge |

---

## 7 ▸ Template Files (ship in `inst/templates/`)  

### 7.1 Default Rule (`general.ai-rules.md`)  
```md
---
name: general
type: always
globs: ["*.R", "*.Rmd"]
description: |
  House style & safety rails.
---

# Coding Guidelines
- Use tidyverse style & `snake_case`.
- Prefer `%>%` pipes.
- No PII in commits.
```

### 7.2 Tag YAML (`.ai-assist/tags.yaml`)  
```yaml
# label : path | glob | url
sales_csv:   data/sales_2024.csv
plots_dir:   results/figures/
readme:      README.md
help_site:   https://intranet.example.org/help
```

Parser loads this once per session, builds `Tag` rows.

---

## 8 ▸ Implementation Checklist  

1. **Package Skeleton** – `{rstudioai}` with add‑in bindings in `inst/rstudio/addins.dcf`.  
2. **Rule & Tag parsers** – `yaml::yaml.load` + `fs::dir_ls` caching (`etag` via `digest`).  
3. **Streaming UI** – chunked `httr2::req_stream()` piping to Shiny reactive.  
4. **Diff Engine** – use `{diffify}` or fall back to `waldo::compare` for patches.  
5. **Undo Integration** – push FilePatch to `rstudioapi::documentUndo()`.  
6. **Safety Filters** – regex + token length guard before send.  
7. **Opt‑in Telemetry** – fire‑and‑forget POST to tiny Go relay; respect env var `RSTUDIOAI_NO_TELEMETRY`.  
8. **Unit tests** – `{testthat}`; mock Ollama with local RHTTPD stub.  

---

## 9 ▸ Cut‑lines (if schedule slips)  

1. **Telemetry** – nice‑to‑have; cut first.  
2. **Tags Tab UI** – keep backend Tag resolver, defer Shiny table.  
3. **Agent‑type rules** – strip, leave `always` + `auto` + `manual`.  

---

## 10 ▸ Future Roadmap (post‑MVP)  

| Version | Highlight |
|---------|-----------|
| **v0.8** | Multi‑file refactor agent (“rename function across project”) |
| **v0.9** | Lintr‑powered “fix‑it” button |
| **v1.0** | Multimodal models (code + images), repo‑wide embeddings cache |
| **v1.1** | Remote rules/tags via Git URLs |

---

### 🌟 **North‑Star**  
Hit that *“type ↩, see correct R code appear”* wow‑moment **within 2 seconds** on a 2020 MacBook Air with Llama 3 8B running locally. Everything else is a bonus.

---

*Spec frozen — any new requirement bumps the version.*
