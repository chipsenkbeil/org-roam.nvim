describe("Parser", function()
  local async = require("org-roam.core.utils.async")
  local join_path = require("org-roam.core.utils.io").join_path
  local Parser = require("org-roam.core.parser")

  local ORG_FILES_DIR = (function()
    local str = debug.getinfo(2, "S").source:sub(2)
    return join_path(vim.fs.dirname(str:match("(.*/)")), "files")
  end)()

  it("should parse an org file correctly", function()
    ---@type string|nil, org-roam.core.parser.File|nil
    local err, file = async.wait(
      Parser.parse_file,
      join_path(ORG_FILES_DIR, "test.org")
    )
    assert(not err, err)
    assert(file)

    -- Verify that we have the title parsed if specified
    assert.equals("some title", file.title)

    -------------------------------
    -- TOP-LEVEL PROPERTY DRAWER --
    -------------------------------

    -- Check our top-level property drawer
    assert.equals(2, #file.drawers[1].properties)

    -- Check position of first property
    assert.equals(2, file.drawers[1].properties[1].range.start.row)
    assert.equals(0, file.drawers[1].properties[1].range.start.column)
    assert.equals(40, file.drawers[1].properties[1].range.start.offset)
    assert.equals(2, file.drawers[1].properties[1].range.end_.row)
    assert.equals(8, file.drawers[1].properties[1].range.end_.column)
    assert.equals(48, file.drawers[1].properties[1].range.end_.offset)

    -- Check the position of the first name (all should be zero-based)
    assert.equals("ID", file.drawers[1].properties[1].name:text())
    assert.equals("ID", file.drawers[1].properties[1].name:text({ refresh = true }))
    assert.equals(2, file.drawers[1].properties[1].name:start_row())
    assert.equals(1, file.drawers[1].properties[1].name:start_column())
    assert.equals(41, file.drawers[1].properties[1].name:start_byte_offset())
    assert.equals(2, file.drawers[1].properties[1].name:end_row())
    assert.equals(2, file.drawers[1].properties[1].name:end_column())
    assert.equals(42, file.drawers[1].properties[1].name:end_byte_offset())

    -- Check the position of the first value (all should be zero-based)
    assert.equals("1234", file.drawers[1].properties[1].value:text())
    assert.equals("1234", file.drawers[1].properties[1].value:text({ refresh = true }))
    assert.equals(2, file.drawers[1].properties[1].value:start_row())
    assert.equals(5, file.drawers[1].properties[1].value:start_column())
    assert.equals(45, file.drawers[1].properties[1].value:start_byte_offset())
    assert.equals(2, file.drawers[1].properties[1].value:end_row())
    assert.equals(8, file.drawers[1].properties[1].value:end_column())
    assert.equals(48, file.drawers[1].properties[1].value:end_byte_offset())

    -- Check position of second property
    assert.equals(3, file.drawers[1].properties[2].range.start.row)
    assert.equals(0, file.drawers[1].properties[2].range.start.column)
    assert.equals(50, file.drawers[1].properties[2].range.start.offset)
    assert.equals(3, file.drawers[1].properties[2].range.end_.row)
    assert.equals(12, file.drawers[1].properties[2].range.end_.column)
    assert.equals(62, file.drawers[1].properties[2].range.end_.offset)

    -- Check the position of the second name (all should be zero-based)
    assert.equals("OTHER", file.drawers[1].properties[2].name:text())
    assert.equals("OTHER", file.drawers[1].properties[2].name:text({ refresh = true }))
    assert.equals(3, file.drawers[1].properties[2].name:start_row())
    assert.equals(1, file.drawers[1].properties[2].name:start_column())
    assert.equals(51, file.drawers[1].properties[2].name:start_byte_offset())
    assert.equals(3, file.drawers[1].properties[2].name:end_row())
    assert.equals(5, file.drawers[1].properties[2].name:end_column())
    assert.equals(55, file.drawers[1].properties[2].name:end_byte_offset())

    -- Check the position of the second value (all should be zero-based)
    assert.equals("hello", file.drawers[1].properties[2].value:text())
    assert.equals("hello", file.drawers[1].properties[2].value:text({ refresh = true }))
    assert.equals(3, file.drawers[1].properties[2].value:start_row())
    assert.equals(8, file.drawers[1].properties[2].value:start_column())
    assert.equals(58, file.drawers[1].properties[2].value:start_byte_offset())
    assert.equals(3, file.drawers[1].properties[2].value:end_row())
    assert.equals(12, file.drawers[1].properties[2].value:end_column())
    assert.equals(62, file.drawers[1].properties[2].value:end_byte_offset())

    --------------------------------------
    -- SECTION HEADLINE PROPERTY DRAWER --
    --------------------------------------

    -- Check position of first property
    assert.equals(12, file.sections[1].property_drawer.properties[1].range.start.row)
    assert.equals(2, file.sections[1].property_drawer.properties[1].range.start.column)
    assert.equals(143, file.sections[1].property_drawer.properties[1].range.start.offset)
    assert.equals(12, file.sections[1].property_drawer.properties[1].range.end_.row)
    assert.equals(10, file.sections[1].property_drawer.properties[1].range.end_.column)
    assert.equals(151, file.sections[1].property_drawer.properties[1].range.end_.offset)

    -- Check the position of the first name (all should be zero-based)
    assert.equals("ID", file.sections[1].property_drawer.properties[1].name:text())
    assert.equals("ID", file.sections[1].property_drawer.properties[1].name:text({ refresh = true }))
    assert.equals(12, file.sections[1].property_drawer.properties[1].name:start_row())
    assert.equals(3, file.sections[1].property_drawer.properties[1].name:start_column())
    assert.equals(144, file.sections[1].property_drawer.properties[1].name:start_byte_offset())
    assert.equals(12, file.sections[1].property_drawer.properties[1].name:end_row())
    assert.equals(4, file.sections[1].property_drawer.properties[1].name:end_column())
    assert.equals(145, file.sections[1].property_drawer.properties[1].name:end_byte_offset())

    -- Check the position of the first value (all should be zero-based)
    assert.equals("5678", file.sections[1].property_drawer.properties[1].value:text())
    assert.equals("5678", file.sections[1].property_drawer.properties[1].value:text({ refresh = true }))
    assert.equals(12, file.sections[1].property_drawer.properties[1].value:start_row())
    assert.equals(7, file.sections[1].property_drawer.properties[1].value:start_column())
    assert.equals(148, file.sections[1].property_drawer.properties[1].value:start_byte_offset())
    assert.equals(12, file.sections[1].property_drawer.properties[1].value:end_row())
    assert.equals(10, file.sections[1].property_drawer.properties[1].value:end_column())
    assert.equals(151, file.sections[1].property_drawer.properties[1].value:end_byte_offset())

    -- Check position of second property
    assert.equals(13, file.sections[1].property_drawer.properties[2].range.start.row)
    assert.equals(2, file.sections[1].property_drawer.properties[2].range.start.column)
    assert.equals(155, file.sections[1].property_drawer.properties[2].range.start.offset)
    assert.equals(13, file.sections[1].property_drawer.properties[2].range.end_.row)
    assert.equals(14, file.sections[1].property_drawer.properties[2].range.end_.column)
    assert.equals(167, file.sections[1].property_drawer.properties[2].range.end_.offset)

    -- Check the position of the second name (all should be zero-based)
    assert.equals("OTHER", file.sections[1].property_drawer.properties[2].name:text())
    assert.equals("OTHER", file.sections[1].property_drawer.properties[2].name:text({ refresh = true }))
    assert.equals(13, file.sections[1].property_drawer.properties[2].name:start_row())
    assert.equals(3, file.sections[1].property_drawer.properties[2].name:start_column())
    assert.equals(156, file.sections[1].property_drawer.properties[2].name:start_byte_offset())
    assert.equals(13, file.sections[1].property_drawer.properties[2].name:end_row())
    assert.equals(7, file.sections[1].property_drawer.properties[2].name:end_column())
    assert.equals(160, file.sections[1].property_drawer.properties[2].name:end_byte_offset())

    -- Check the position of the second value (all should be zero-based)
    assert.equals("world", file.sections[1].property_drawer.properties[2].value:text())
    assert.equals("world", file.sections[1].property_drawer.properties[2].value:text({ refresh = true }))
    assert.equals(13, file.sections[1].property_drawer.properties[2].value:start_row())
    assert.equals(10, file.sections[1].property_drawer.properties[2].value:start_column())
    assert.equals(163, file.sections[1].property_drawer.properties[2].value:start_byte_offset())
    assert.equals(13, file.sections[1].property_drawer.properties[2].value:end_row())
    assert.equals(14, file.sections[1].property_drawer.properties[2].value:end_column())
    assert.equals(167, file.sections[1].property_drawer.properties[2].value:end_byte_offset())

    ----------------------------------------
    -- HEADLINE PROPERTY DRAWER WITH TAGS --
    ----------------------------------------

    -- NOTE: I'm lazy, so we're just checking a couple of specifics here
    --                         since we've already tested ranges earlier for drawers.
    assert.equals("ID", file.sections[2].property_drawer.properties[1].name:text())
    assert.equals("9999", file.sections[2].property_drawer.properties[1].value:text())
    assert.equals(":tag1:tag2:", file.sections[2].heading.tags:text())
    assert.same({ "tag1", "tag2" }, file.sections[2].heading:tag_list())

    ------------------------
    -- FILETAGS DIRECTIVE --
    ------------------------

    assert.same({ "a", "b", "c" }, file.filetags)

    -------------------
    -- REGULAR LINKS --
    -------------------

    -- Check our links
    assert.equals(5, #file.links)

    -- Check information about the first link
    assert.equals("regular", file.links[1].kind)
    assert.equals("id:1234", file.links[1].path)
    assert.equals("Link to file node", file.links[1].description)
    assert.equals(22, file.links[1].range.start.row)
    assert.equals(2, file.links[1].range.start.column)
    assert.equals(291, file.links[1].range.start.offset)
    assert.equals(22, file.links[1].range.end_.row)
    assert.equals(31, file.links[1].range.end_.column)
    assert.equals(320, file.links[1].range.end_.offset)

    -- Check information about the second link
    assert.equals("regular", file.links[2].kind)
    assert.equals("id:5678", file.links[2].path)
    assert.equals("Link to heading node", file.links[2].description)
    assert.equals(23, file.links[2].range.start.row)
    assert.equals(2, file.links[2].range.start.column)
    assert.equals(333, file.links[2].range.start.offset)
    assert.equals(23, file.links[2].range.end_.row)
    assert.equals(34, file.links[2].range.end_.column)
    assert.equals(365, file.links[2].range.end_.offset)

    -- Check information about the third link
    assert.equals("regular", file.links[3].kind)
    assert.equals("https://example.com", file.links[3].path)
    assert.is_nil(file.links[3].description)
    assert.equals(24, file.links[3].range.start.row)
    assert.equals(2, file.links[3].range.start.column)
    assert.equals(378, file.links[3].range.start.offset)
    assert.equals(24, file.links[3].range.end_.row)
    assert.equals(24, file.links[3].range.end_.column)
    assert.equals(400, file.links[3].range.end_.offset)

    -- Check information about the fourth link
    assert.equals("regular", file.links[4].kind)
    assert.equals("link", file.links[4].path)
    assert.is_nil(file.links[4].description)
    assert.equals(25, file.links[4].range.start.row)
    assert.equals(12, file.links[4].range.start.column)
    assert.equals(447, file.links[4].range.start.offset)
    assert.equals(25, file.links[4].range.end_.row)
    assert.equals(19, file.links[4].range.end_.column)
    assert.equals(454, file.links[4].range.end_.offset)

    -- Check information about the fifth link
    assert.equals("regular", file.links[5].kind)
    assert.equals("link2", file.links[5].path)
    assert.is_nil(file.links[5].description)
    assert.equals(25, file.links[5].range.start.row)
    assert.equals(42, file.links[5].range.start.column)
    assert.equals(477, file.links[5].range.start.offset)
    assert.equals(25, file.links[5].range.end_.row)
    assert.equals(50, file.links[5].range.end_.column)
    assert.equals(485, file.links[5].range.end_.offset)
  end)

  it("should parse an org file correctly (2)", function()
    ---@type string|nil, org-roam.core.parser.File|nil
    local err, file = async.wait(
      Parser.parse_file,
      join_path(ORG_FILES_DIR, "one.org")
    )
    assert(not err, err)
    assert(file)

    -- NOTE: We aren't checking the entire thing fully
    assert.equals(1, #file.drawers)
    assert.equals(2, #file.sections)
    assert.equals(6, #file.links)

    -- Verify section merging (bug workaround) is working as expected
    assert.equals("node two", file.sections[1].heading.item:text())
    assert.equals(":d:e:f:", file.sections[1].heading.tags:text())
    assert.equals("node three", file.sections[2].heading.item:text())
    assert.equals(":g:h:i:", file.sections[2].heading.tags:text())

    -- Verify we get all of the links (catch bug about near end of paragraph
    -- with a period immediately after it
    assert.equals("id:2", file.links[1].path)
    assert.equals("id:3", file.links[2].path)
    assert.equals("id:4", file.links[3].path)
    assert.equals("id:1", file.links[4].path)
    assert.equals("id:3", file.links[5].path)
    assert.equals("id:2", file.links[6].path)
  end)

  it("should parse links from a variety of locations", function()
    ---@type string|nil, org-roam.core.parser.File|nil
    local err, file = async.wait(
      Parser.parse_file,
      join_path(ORG_FILES_DIR, "links.org")
    )
    assert(not err, err)
    assert(file)

    assert.equals(14, #file.links)

    assert.equals("id:1234", file.links[1].path)
    assert.equals("id:5678", file.links[2].path)
    assert.equals("https://example.com", file.links[3].path)
    assert.equals("link", file.links[4].path)
    assert.equals("link2", file.links[5].path)
    assert.equals("link3", file.links[6].path)
    assert.equals("link4", file.links[7].path)
    assert.equals("link5", file.links[8].path)
    assert.equals("link6", file.links[9].path)
    assert.equals("link7", file.links[10].path)
    assert.equals("link8", file.links[11].path)
    assert.equals("link9", file.links[12].path)
    assert.equals("link10", file.links[13].path)
    assert.equals("link11", file.links[14].path)
  end)
end)
