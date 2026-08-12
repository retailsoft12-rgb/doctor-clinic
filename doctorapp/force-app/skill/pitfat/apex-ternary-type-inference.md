Name: Apex ternary type inference / implicit Id coercion — the conditional operator ?: resolves its result type from the first branch, then coerces the second to it (String → Id conversion throws Invalid id).

Abstract


// PROBLEM — first branch is Id, second gets coerced to Id
String x = cond ? idValue : textValue;   // Id.valueOf(text) → Invalid id

// SOLUTION — make both branches the same type
String x = cond ? String.valueOf(idValue) : textValue;
Rule: in a ? b : c, type of b wins; c must fit it.
