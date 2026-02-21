---
name: doc-coauthoring
description: Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, or similar structured content. This workflow helps users efficiently transfer context, refine content through iteration, and verify the doc works for readers. Trigger when user mentions writing docs, creating proposals, drafting specs, or similar documentation tasks.
---

# Doc Co-Authoring Workflow

Walk users through three stages of collaborative document creation: Context Gathering, Refinement & Structure, and Reader Testing.

## When to Offer This Workflow

**Trigger conditions:**
- User mentions writing documentation: "write a doc", "draft a proposal", "create a spec"
- User mentions specific doc types: "PRD", "design doc", "decision doc", "RFC"
- User is starting a substantial writing task

**Initial offer:** Explain the three stages and ask if they want structured or freeform.

## Stage 1: Context Gathering

Close the gap between what the user knows and what the agent knows.

### Initial Questions
1. What type of document is this?
2. Who's the primary audience?
3. What's the desired impact when someone reads this?
4. Is there a template or specific format to follow?
5. Any other constraints or context?

### Info Dumping
Encourage the user to dump all context:
- Background on the project/problem
- Related discussions or documents
- Why alternatives aren't being used
- Organizational context, timeline pressures
- Technical architecture or dependencies

After the initial dump, ask 5-10 clarifying questions based on gaps.

**Exit condition:** Questions show understanding — edge cases and trade-offs can be discussed without needing basics explained.

## Stage 2: Refinement & Structure

Build the document section by section through brainstorming, curation, and iterative refinement.

### For Each Section
1. **Clarify**: Ask 5-10 questions about what to include
2. **Brainstorm**: Generate 5-20 options for content
3. **Curate**: User selects what to keep/remove/combine
4. **Gap Check**: Ask if anything important is missing
5. **Draft**: Write the section based on selections
6. **Refine**: Make surgical edits based on feedback (never reprint whole doc)

### Key Instructions
- Start with whichever section has the most unknowns
- Ask user to indicate changes rather than editing directly (helps learn their style)
- After 3 consecutive iterations with no substantial changes, suggest removing unnecessary content

### Near Completion (80%+ done)
Re-read entire document and check for:
- Flow and consistency across sections
- Redundancy or contradictions
- Generic filler that doesn't carry weight

## Stage 3: Reader Testing

Test the document with a fresh perspective to catch blind spots.

### Steps
1. **Predict reader questions**: Generate 5-10 questions readers would realistically ask
2. **Test**: Use a sub-agent (if available) or ask user to test in a fresh conversation
3. **Additional checks**: Look for ambiguity, false assumptions, contradictions
4. **Fix gaps**: Loop back to refinement for any problematic sections

**Exit condition:** Reader consistently answers questions correctly with no new gaps.

## Final Review

When reader testing passes:
1. Recommend a final read-through by the user
2. Suggest double-checking facts, links, technical details
3. Ask if it achieves the intended impact

## Tips
- Be direct and procedural in tone
- If user wants to skip a stage, let them
- Address context gaps as they come up — don't let them accumulate
- Use surgical edits (str_replace), never reprint the whole doc

## Attribution

From [anthropics/skills](https://github.com/anthropics/skills) `doc-coauthoring` skill (Apache 2.0 License).
