# Case 02: Review Gate Mapping

You are evaluating whether the local `clinical-biostat-er` skills preserve
human-in-the-loop decisions.

Task:

Read the bundle-level `SKILL.md`, `LIFECYCLE.md`, and Core 1-5 `DESIGN.md`
files. Produce a concise map of which workflow decisions can be automated and
which must remain review-gated.

Constraints:

- Do not run modeling code.
- Do not invent new review gates beyond what the bundle supports.
- Ground claims in local files.

Expected answer:

- Core-by-core review gate map.
- A short list of analyst/CP/statistician decision items.
- A short list of automated checks that are safe to run.
- Any unclear contracts that should be improved in the skill docs.
