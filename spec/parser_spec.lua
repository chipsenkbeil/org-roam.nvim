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

  it("should parse an org file correctly", function()
    local output = Parser.parse(TEST_ORG_CONTENTS)

    -------------------------------
    -- TOP-LEVEL PROPERTY DRAWER --
    -------------------------------

    -- Check our top-level property drawer
    assert.is_nil(output.drawers[1].heading)
    assert.equals(2, #output.drawers[1].properties)

    -- Check position of first property
    assert.equals(2, output.drawers[1].properties[1].range.start.row)
    assert.equals(0, output.drawers[1].properties[1].range.start.column)
    assert.equals(40, output.drawers[1].properties[1].range.start.offset)
    assert.equals(2, output.drawers[1].properties[1].range.end_.row)
    assert.equals(8, output.drawers[1].properties[1].range.end_.column)
    assert.equals(47, output.drawers[1].properties[1].range.end_.offset)

    -- Check the position of the first key (all should be zero-based)
    assert.equals("ID", output.drawers[1].properties[1].name:text())
    assert.equals("ID", output.drawers[1].properties[1].name:text({ refresh = true }))
    assert.equals(2, output.drawers[1].properties[1].name:start_row())
    assert.equals(1, output.drawers[1].properties[1].name:start_column())
    assert.equals(41, output.drawers[1].properties[1].name:start_byte_offset())
    assert.equals(2, output.drawers[1].properties[1].name:end_row())
    assert.equals(2, output.drawers[1].properties[1].name:end_column())
    assert.equals(42, output.drawers[1].properties[1].name:end_byte_offset())

    -- Check the position of the first value (all should be zero-based)
    assert.equals("1234", output.drawers[1].properties[1].value:text())
    assert.equals("1234", output.drawers[1].properties[1].value:text({ refresh = true }))
    assert.equals(2, output.drawers[1].properties[1].value:start_row())
    assert.equals(5, output.drawers[1].properties[1].value:start_column())
    assert.equals(45, output.drawers[1].properties[1].value:start_byte_offset())
    assert.equals(2, output.drawers[1].properties[1].value:end_row())
    assert.equals(8, output.drawers[1].properties[1].value:end_column())
    assert.equals(48, output.drawers[1].properties[1].value:end_byte_offset())

    -- Check the position of the second key (all should be zero-based)
    assert.equals("OTHER", output.drawers[1].properties[2].name:text())
    assert.equals("OTHER", output.drawers[1].properties[2].name:text({ refresh = true }))
    assert.equals(3, output.drawers[1].properties[2].name:start_row())
    assert.equals(1, output.drawers[1].properties[2].name:start_column())
    assert.equals(51, output.drawers[1].properties[2].name:start_byte_offset())
    assert.equals(3, output.drawers[1].properties[2].name:end_row())
    assert.equals(5, output.drawers[1].properties[2].name:end_column())
    assert.equals(55, output.drawers[1].properties[2].name:end_byte_offset())

    -- Check the position of the second value (all should be zero-based)
    assert.equals("hello", output.drawers[1].properties[2].value:text())
    assert.equals("hello", output.drawers[1].properties[2].value:text({ refresh = true }))
    assert.equals(3, output.drawers[1].properties[2].value:start_row())
    assert.equals(8, output.drawers[1].properties[2].value:start_column())
    assert.equals(58, output.drawers[1].properties[2].value:start_byte_offset())
    assert.equals(3, output.drawers[1].properties[2].value:end_row())
    assert.equals(12, output.drawers[1].properties[2].value:end_column())
    assert.equals(62, output.drawers[1].properties[2].value:end_byte_offset())

    ------------------------------
    -- HEADLINE PROPERTY DRAWER --
    ------------------------------

    -- Check the position of the first key (all should be zero-based)
    assert.equals("ID", output.drawers[2].properties[1].name:text())
    assert.equals("ID", output.drawers[2].properties[1].name:text({ refresh = true }))
    assert.equals(12, output.drawers[2].properties[1].name:start_row())
    assert.equals(3, output.drawers[2].properties[1].name:start_column())
    assert.equals(144, output.drawers[2].properties[1].name:start_byte_offset())
    assert.equals(12, output.drawers[2].properties[1].name:end_row())
    assert.equals(4, output.drawers[2].properties[1].name:end_column())
    assert.equals(145, output.drawers[2].properties[1].name:end_byte_offset())

    -- Check the position of the first value (all should be zero-based)
    assert.equals("5678", output.drawers[2].properties[1].value:text())
    assert.equals("5678", output.drawers[2].properties[1].value:text({ refresh = true }))
    assert.equals(12, output.drawers[2].properties[1].value:start_row())
    assert.equals(7, output.drawers[2].properties[1].value:start_column())
    assert.equals(148, output.drawers[2].properties[1].value:start_byte_offset())
    assert.equals(12, output.drawers[2].properties[1].value:end_row())
    assert.equals(10, output.drawers[2].properties[1].value:end_column())
    assert.equals(151, output.drawers[2].properties[1].value:end_byte_offset())

    -- Check the position of the second key (all should be zero-based)
    assert.equals("OTHER", output.drawers[2].properties[2].name:text())
    assert.equals("OTHER", output.drawers[2].properties[2].name:text({ refresh = true }))
    assert.equals(13, output.drawers[2].properties[2].name:start_row())
    assert.equals(3, output.drawers[2].properties[2].name:start_column())
    assert.equals(156, output.drawers[2].properties[2].name:start_byte_offset())
    assert.equals(13, output.drawers[2].properties[2].name:end_row())
    assert.equals(7, output.drawers[2].properties[2].name:end_column())
    assert.equals(160, output.drawers[2].properties[2].name:end_byte_offset())

    -- Check the position of the second value (all should be zero-based)
    assert.equals("world", output.drawers[2].properties[2].value:text())
    assert.equals("world", output.drawers[2].properties[2].value:text({ refresh = true }))
    assert.equals(13, output.drawers[2].properties[2].value:start_row())
    assert.equals(10, output.drawers[2].properties[2].value:start_column())
    assert.equals(163, output.drawers[2].properties[2].value:start_byte_offset())
    assert.equals(13, output.drawers[2].properties[2].value:end_row())
    assert.equals(14, output.drawers[2].properties[2].value:end_column())
    assert.equals(167, output.drawers[2].properties[2].value:end_byte_offset())

    -------------------
    -- REGULAR LINKS --
    -------------------

    -- TODO: Lines 22 - 24 for links
    -- 291 for first link
    -- 333 for second link
    -- 378 for third link
  end)
end)
