# Remaining test failures — evidence contract

Objective: resolve the ten baseline failures without fabricating trip evidence.

Invariants:
- Supplier/place heuristics are contextual suggestions, never proof that bulky tools were carried. A home/supplier trip must not start with tools confirmed solely from its address.
- Explicit existing tools evidence remains selected when editing.
- Dismissing an awaited registration sheet must not update a disposed widget.
- Empty recent activity cannot manufacture sample ledger entries; manual entry callback remains accessible.
- Weekend classification still requires user confirmation. Copy changes do not alter that decision.
- Switching tax method reaches the real logbook setup screen.

Executable contracts: adversarial home/supplier initial-checkbox test; existing explicit evidence test; current recent-activity, classifier, advisor and quick resolve widget tests; full Flutter suite and analyzer. Tax calculation formulas and eligibility rules are outside this change.
