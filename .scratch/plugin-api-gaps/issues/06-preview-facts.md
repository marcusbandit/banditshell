# The side preview can show facts

Status: resolved
PR: #817
GitHub: #810

Label and value facts only show on a full detail page. Raycast's list items
carry a detail beside the list with metadata.

Use case: a Voice rule row shows what the rule does, how loud dim is and
what is playing, beside the list, without opening a page.

Done when: `preview` takes `facts` (with optional `text` above them), drawn
in the peek card the way a detail page draws its facts.
