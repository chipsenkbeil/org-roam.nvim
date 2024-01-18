local TEST_ORG_CONTENTS = vim.trim([=[
#+TITLE: Test Org Contents
:PROPERTIES:
:ID: 1234
:OTHER: hello
:END:

:LOGBOOK:
:FIX: TEST
:END:

* Heading 1 that is a node
  :PROPERTIES:
  :ID: 5678
  :OTHER: world
  :END:

  Some content for the first heading.

* Heading 2 that is not a node

  Some content for the second heading.

  [[id:1234][Link to file node]] is here.
  [[id:5678][Link to heading node]] is here.
  [[https://example.com]] is a link without a description.
]=])

describe("Parser", function()
  local Parser = require("org-roam.parser")

  it("should test_parse", function()
    local output = Parser.test_parse(TEST_ORG_CONTENTS)
    print(vim.inspect(output))
  end)
end)
