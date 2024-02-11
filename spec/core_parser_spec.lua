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
  This is a [[link]] embedded within, and [[link2]] also.

* Heading 3 that is a node with tags :tag1:tag2:
  :PROPERTIES:
  :ID: 9999
  :END:

#+FILETAGS: :a:b:c:
#+TITLE: some title
]=])

describe("Parser", function()
  local Parser = require("org-roam.core.parser")

  it("should parse an org file correctly", function()
    local output = Parser.parse(TEST_ORG_CONTENTS)

    -- Verify that we have the title parsed if specified
    assert.equals("some title", output.title)

    -------------------------------
    -- TOP-LEVEL PROPERTY DRAWER --
    -------------------------------

    -- Check our top-level property drawer
    assert.equals(2, #output.drawers[1].properties)

    -- Check position of first property
    assert.equals(2, output.drawers[1].properties[1].range.start.row)
    assert.equals(0, output.drawers[1].properties[1].range.start.column)
    assert.equals(40, output.drawers[1].properties[1].range.start.offset)
    assert.equals(2, output.drawers[1].properties[1].range.end_.row)
    assert.equals(8, output.drawers[1].properties[1].range.end_.column)
    assert.equals(48, output.drawers[1].properties[1].range.end_.offset)

    -- Check the position of the first name (all should be zero-based)
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

    -- Check position of second property
    assert.equals(3, output.drawers[1].properties[2].range.start.row)
    assert.equals(0, output.drawers[1].properties[2].range.start.column)
    assert.equals(50, output.drawers[1].properties[2].range.start.offset)
    assert.equals(3, output.drawers[1].properties[2].range.end_.row)
    assert.equals(12, output.drawers[1].properties[2].range.end_.column)
    assert.equals(62, output.drawers[1].properties[2].range.end_.offset)

    -- Check the position of the second name (all should be zero-based)
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

    --------------------------------------
    -- SECTION HEADLINE PROPERTY DRAWER --
    --------------------------------------

    -- Check position of first property
    assert.equals(12, output.sections[1].property_drawer.properties[1].range.start.row)
    assert.equals(2, output.sections[1].property_drawer.properties[1].range.start.column)
    assert.equals(143, output.sections[1].property_drawer.properties[1].range.start.offset)
    assert.equals(12, output.sections[1].property_drawer.properties[1].range.end_.row)
    assert.equals(10, output.sections[1].property_drawer.properties[1].range.end_.column)
    assert.equals(151, output.sections[1].property_drawer.properties[1].range.end_.offset)

    -- Check the position of the first name (all should be zero-based)
    assert.equals("ID", output.sections[1].property_drawer.properties[1].name:text())
    assert.equals("ID", output.sections[1].property_drawer.properties[1].name:text({ refresh = true }))
    assert.equals(12, output.sections[1].property_drawer.properties[1].name:start_row())
    assert.equals(3, output.sections[1].property_drawer.properties[1].name:start_column())
    assert.equals(144, output.sections[1].property_drawer.properties[1].name:start_byte_offset())
    assert.equals(12, output.sections[1].property_drawer.properties[1].name:end_row())
    assert.equals(4, output.sections[1].property_drawer.properties[1].name:end_column())
    assert.equals(145, output.sections[1].property_drawer.properties[1].name:end_byte_offset())

    -- Check the position of the first value (all should be zero-based)
    assert.equals("5678", output.sections[1].property_drawer.properties[1].value:text())
    assert.equals("5678", output.sections[1].property_drawer.properties[1].value:text({ refresh = true }))
    assert.equals(12, output.sections[1].property_drawer.properties[1].value:start_row())
    assert.equals(7, output.sections[1].property_drawer.properties[1].value:start_column())
    assert.equals(148, output.sections[1].property_drawer.properties[1].value:start_byte_offset())
    assert.equals(12, output.sections[1].property_drawer.properties[1].value:end_row())
    assert.equals(10, output.sections[1].property_drawer.properties[1].value:end_column())
    assert.equals(151, output.sections[1].property_drawer.properties[1].value:end_byte_offset())

    -- Check position of second property
    assert.equals(13, output.sections[1].property_drawer.properties[2].range.start.row)
    assert.equals(2, output.sections[1].property_drawer.properties[2].range.start.column)
    assert.equals(155, output.sections[1].property_drawer.properties[2].range.start.offset)
    assert.equals(13, output.sections[1].property_drawer.properties[2].range.end_.row)
    assert.equals(14, output.sections[1].property_drawer.properties[2].range.end_.column)
    assert.equals(167, output.sections[1].property_drawer.properties[2].range.end_.offset)

    -- Check the position of the second name (all should be zero-based)
    assert.equals("OTHER", output.sections[1].property_drawer.properties[2].name:text())
    assert.equals("OTHER", output.sections[1].property_drawer.properties[2].name:text({ refresh = true }))
    assert.equals(13, output.sections[1].property_drawer.properties[2].name:start_row())
    assert.equals(3, output.sections[1].property_drawer.properties[2].name:start_column())
    assert.equals(156, output.sections[1].property_drawer.properties[2].name:start_byte_offset())
    assert.equals(13, output.sections[1].property_drawer.properties[2].name:end_row())
    assert.equals(7, output.sections[1].property_drawer.properties[2].name:end_column())
    assert.equals(160, output.sections[1].property_drawer.properties[2].name:end_byte_offset())

    -- Check the position of the second value (all should be zero-based)
    assert.equals("world", output.sections[1].property_drawer.properties[2].value:text())
    assert.equals("world", output.sections[1].property_drawer.properties[2].value:text({ refresh = true }))
    assert.equals(13, output.sections[1].property_drawer.properties[2].value:start_row())
    assert.equals(10, output.sections[1].property_drawer.properties[2].value:start_column())
    assert.equals(163, output.sections[1].property_drawer.properties[2].value:start_byte_offset())
    assert.equals(13, output.sections[1].property_drawer.properties[2].value:end_row())
    assert.equals(14, output.sections[1].property_drawer.properties[2].value:end_column())
    assert.equals(167, output.sections[1].property_drawer.properties[2].value:end_byte_offset())

    ----------------------------------------
    -- HEADLINE PROPERTY DRAWER WITH TAGS --
    ----------------------------------------

    -- NOTE: I'm lazy, so we're just checking a couple of specifics here
    --       since we've already tested ranges earlier for drawers.
    assert.equals("ID", output.sections[2].property_drawer.properties[1].name:text())
    assert.equals("9999", output.sections[2].property_drawer.properties[1].value:text())
    assert.equals(":tag1:tag2:", output.sections[2].heading.tags:text())
    assert.same({ "tag1", "tag2" }, output.sections[2].heading:tag_list())

    ------------------------
    -- FILETAGS DIRECTIVE --
    ------------------------

    assert.same({ "a", "b", "c" }, output.filetags)

    -------------------
    -- REGULAR LINKS --
    -------------------

    -- Check our links
    assert.equals(5, #output.links)

    -- Check information about the first link
    assert.equals("regular", output.links[1].kind)
    assert.equals("id:1234", output.links[1].path)
    assert.equals("Link to file node", output.links[1].description)
    assert.equals(22, output.links[1].range.start.row)
    assert.equals(2, output.links[1].range.start.column)
    assert.equals(291, output.links[1].range.start.offset)
    assert.equals(22, output.links[1].range.end_.row)
    assert.equals(31, output.links[1].range.end_.column)
    assert.equals(320, output.links[1].range.end_.offset)

    -- Check information about the second link
    assert.equals("regular", output.links[2].kind)
    assert.equals("id:5678", output.links[2].path)
    assert.equals("Link to heading node", output.links[2].description)
    assert.equals(23, output.links[2].range.start.row)
    assert.equals(2, output.links[2].range.start.column)
    assert.equals(333, output.links[2].range.start.offset)
    assert.equals(23, output.links[2].range.end_.row)
    assert.equals(34, output.links[2].range.end_.column)
    assert.equals(365, output.links[2].range.end_.offset)

    -- Check information about the third link
    assert.equals("regular", output.links[3].kind)
    assert.equals("https://example.com", output.links[3].path)
    assert.is_nil(output.links[3].description)
    assert.equals(24, output.links[3].range.start.row)
    assert.equals(2, output.links[3].range.start.column)
    assert.equals(378, output.links[3].range.start.offset)
    assert.equals(24, output.links[3].range.end_.row)
    assert.equals(24, output.links[3].range.end_.column)
    assert.equals(400, output.links[3].range.end_.offset)

    -- Check information about the fourth link
    assert.equals("regular", output.links[4].kind)
    assert.equals("link", output.links[4].path)
    assert.is_nil(output.links[4].description)
    assert.equals(25, output.links[4].range.start.row)
    assert.equals(12, output.links[4].range.start.column)
    assert.equals(447, output.links[4].range.start.offset)
    assert.equals(25, output.links[4].range.end_.row)
    assert.equals(19, output.links[4].range.end_.column)
    assert.equals(454, output.links[4].range.end_.offset)

    -- Check information about the fifth link
    assert.equals("regular", output.links[5].kind)
    assert.equals("link2", output.links[5].path)
    assert.is_nil(output.links[5].description)
    assert.equals(25, output.links[5].range.start.row)
    assert.equals(42, output.links[5].range.start.column)
    assert.equals(477, output.links[5].range.start.offset)
    assert.equals(25, output.links[5].range.end_.row)
    assert.equals(50, output.links[5].range.end_.column)
    assert.equals(485, output.links[5].range.end_.offset)
  end)
end)
