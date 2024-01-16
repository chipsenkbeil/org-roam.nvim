local TEST_ORG_CONTENTS = vim.trim([[
#+TITLE: Test Org Contents
:PROPERTIES:
:ID: 1234
:END:

:LOGBOOK:
:FIX: TEST
:END:

* Heading 1 that is a node
  :PROPERTIES:
  :ID: 5678
  :END:

  Some content for the first heading.

* Heading 2 that is not a node

  Some content for the second heading.
]])

describe("Parser", function()
    local Parser = require("org-roam.parser")

    it("should test_parse", function()
        Parser.test_parse(TEST_ORG_CONTENTS)
        error("STOP")
    end)
end)
