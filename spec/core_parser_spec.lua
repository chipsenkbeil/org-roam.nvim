describe("org-roam.core.parser", function()
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
    assert.are.equal("some title", file.title)

    -------------------------------
    -- TOP-LEVEL PROPERTY DRAWER --
    -------------------------------

    -- Check our top-level property drawer
    assert.are.equal(2, #file.drawers[1].properties)

    -- Check position of first property
    assert.are.equal(2, file.drawers[1].properties[1].range.start.row)
    assert.are.equal(0, file.drawers[1].properties[1].range.start.column)
    assert.are.equal(40, file.drawers[1].properties[1].range.start.offset)
    assert.are.equal(2, file.drawers[1].properties[1].range.end_.row)
    assert.are.equal(8, file.drawers[1].properties[1].range.end_.column)
    assert.are.equal(48, file.drawers[1].properties[1].range.end_.offset)

    -- Check the position of the first name (all should be zero-based)
    assert.are.equal("ID", file.drawers[1].properties[1].name:text())
    assert.are.equal("ID", file.drawers[1].properties[1].name:text({ refresh = true }))
    assert.are.equal(2, file.drawers[1].properties[1].name:start_row())
    assert.are.equal(1, file.drawers[1].properties[1].name:start_column())
    assert.are.equal(41, file.drawers[1].properties[1].name:start_byte_offset())
    assert.are.equal(2, file.drawers[1].properties[1].name:end_row())
    assert.are.equal(2, file.drawers[1].properties[1].name:end_column())
    assert.are.equal(42, file.drawers[1].properties[1].name:end_byte_offset())

    -- Check the position of the first value (all should be zero-based)
    assert.are.equal("1234", file.drawers[1].properties[1].value:text())
    assert.are.equal("1234", file.drawers[1].properties[1].value:text({ refresh = true }))
    assert.are.equal(2, file.drawers[1].properties[1].value:start_row())
    assert.are.equal(5, file.drawers[1].properties[1].value:start_column())
    assert.are.equal(45, file.drawers[1].properties[1].value:start_byte_offset())
    assert.are.equal(2, file.drawers[1].properties[1].value:end_row())
    assert.are.equal(8, file.drawers[1].properties[1].value:end_column())
    assert.are.equal(48, file.drawers[1].properties[1].value:end_byte_offset())

    -- Check position of second property
    assert.are.equal(3, file.drawers[1].properties[2].range.start.row)
    assert.are.equal(0, file.drawers[1].properties[2].range.start.column)
    assert.are.equal(50, file.drawers[1].properties[2].range.start.offset)
    assert.are.equal(3, file.drawers[1].properties[2].range.end_.row)
    assert.are.equal(12, file.drawers[1].properties[2].range.end_.column)
    assert.are.equal(62, file.drawers[1].properties[2].range.end_.offset)

    -- Check the position of the second name (all should be zero-based)
    assert.are.equal("OTHER", file.drawers[1].properties[2].name:text())
    assert.are.equal("OTHER", file.drawers[1].properties[2].name:text({ refresh = true }))
    assert.are.equal(3, file.drawers[1].properties[2].name:start_row())
    assert.are.equal(1, file.drawers[1].properties[2].name:start_column())
    assert.are.equal(51, file.drawers[1].properties[2].name:start_byte_offset())
    assert.are.equal(3, file.drawers[1].properties[2].name:end_row())
    assert.are.equal(5, file.drawers[1].properties[2].name:end_column())
    assert.are.equal(55, file.drawers[1].properties[2].name:end_byte_offset())

    -- Check the position of the second value (all should be zero-based)
    assert.are.equal("hello", file.drawers[1].properties[2].value:text())
    assert.are.equal("hello", file.drawers[1].properties[2].value:text({ refresh = true }))
    assert.are.equal(3, file.drawers[1].properties[2].value:start_row())
    assert.are.equal(8, file.drawers[1].properties[2].value:start_column())
    assert.are.equal(58, file.drawers[1].properties[2].value:start_byte_offset())
    assert.are.equal(3, file.drawers[1].properties[2].value:end_row())
    assert.are.equal(12, file.drawers[1].properties[2].value:end_column())
    assert.are.equal(62, file.drawers[1].properties[2].value:end_byte_offset())

    --------------------------------------
    -- SECTION HEADLINE PROPERTY DRAWER --
    --------------------------------------

    -- Check position of first property
    assert.are.equal(12, file.sections[1].property_drawer.properties[1].range.start.row)
    assert.are.equal(2, file.sections[1].property_drawer.properties[1].range.start.column)
    assert.are.equal(143, file.sections[1].property_drawer.properties[1].range.start.offset)
    assert.are.equal(12, file.sections[1].property_drawer.properties[1].range.end_.row)
    assert.are.equal(10, file.sections[1].property_drawer.properties[1].range.end_.column)
    assert.are.equal(151, file.sections[1].property_drawer.properties[1].range.end_.offset)

    -- Check the position of the first name (all should be zero-based)
    assert.are.equal("ID", file.sections[1].property_drawer.properties[1].name:text())
    assert.are.equal("ID", file.sections[1].property_drawer.properties[1].name:text({ refresh = true }))
    assert.are.equal(12, file.sections[1].property_drawer.properties[1].name:start_row())
    assert.are.equal(3, file.sections[1].property_drawer.properties[1].name:start_column())
    assert.are.equal(144, file.sections[1].property_drawer.properties[1].name:start_byte_offset())
    assert.are.equal(12, file.sections[1].property_drawer.properties[1].name:end_row())
    assert.are.equal(4, file.sections[1].property_drawer.properties[1].name:end_column())
    assert.are.equal(145, file.sections[1].property_drawer.properties[1].name:end_byte_offset())

    -- Check the position of the first value (all should be zero-based)
    assert.are.equal("5678", file.sections[1].property_drawer.properties[1].value:text())
    assert.are.equal("5678", file.sections[1].property_drawer.properties[1].value:text({ refresh = true }))
    assert.are.equal(12, file.sections[1].property_drawer.properties[1].value:start_row())
    assert.are.equal(7, file.sections[1].property_drawer.properties[1].value:start_column())
    assert.are.equal(148, file.sections[1].property_drawer.properties[1].value:start_byte_offset())
    assert.are.equal(12, file.sections[1].property_drawer.properties[1].value:end_row())
    assert.are.equal(10, file.sections[1].property_drawer.properties[1].value:end_column())
    assert.are.equal(151, file.sections[1].property_drawer.properties[1].value:end_byte_offset())

    -- Check position of second property
    assert.are.equal(13, file.sections[1].property_drawer.properties[2].range.start.row)
    assert.are.equal(2, file.sections[1].property_drawer.properties[2].range.start.column)
    assert.are.equal(155, file.sections[1].property_drawer.properties[2].range.start.offset)
    assert.are.equal(13, file.sections[1].property_drawer.properties[2].range.end_.row)
    assert.are.equal(14, file.sections[1].property_drawer.properties[2].range.end_.column)
    assert.are.equal(167, file.sections[1].property_drawer.properties[2].range.end_.offset)

    -- Check the position of the second name (all should be zero-based)
    assert.are.equal("OTHER", file.sections[1].property_drawer.properties[2].name:text())
    assert.are.equal("OTHER", file.sections[1].property_drawer.properties[2].name:text({ refresh = true }))
    assert.are.equal(13, file.sections[1].property_drawer.properties[2].name:start_row())
    assert.are.equal(3, file.sections[1].property_drawer.properties[2].name:start_column())
    assert.are.equal(156, file.sections[1].property_drawer.properties[2].name:start_byte_offset())
    assert.are.equal(13, file.sections[1].property_drawer.properties[2].name:end_row())
    assert.are.equal(7, file.sections[1].property_drawer.properties[2].name:end_column())
    assert.are.equal(160, file.sections[1].property_drawer.properties[2].name:end_byte_offset())

    -- Check the position of the second value (all should be zero-based)
    assert.are.equal("world", file.sections[1].property_drawer.properties[2].value:text())
    assert.are.equal("world", file.sections[1].property_drawer.properties[2].value:text({ refresh = true }))
    assert.are.equal(13, file.sections[1].property_drawer.properties[2].value:start_row())
    assert.are.equal(10, file.sections[1].property_drawer.properties[2].value:start_column())
    assert.are.equal(163, file.sections[1].property_drawer.properties[2].value:start_byte_offset())
    assert.are.equal(13, file.sections[1].property_drawer.properties[2].value:end_row())
    assert.are.equal(14, file.sections[1].property_drawer.properties[2].value:end_column())
    assert.are.equal(167, file.sections[1].property_drawer.properties[2].value:end_byte_offset())

    ----------------------------------------
    -- HEADLINE PROPERTY DRAWER WITH TAGS --
    ----------------------------------------

    -- NOTE: I'm lazy, so we're just checking a couple of specifics here
    --                         since we've already tested ranges earlier for drawers.
    assert.are.equal("ID", file.sections[2].property_drawer.properties[1].name:text())
    assert.are.equal("9999", file.sections[2].property_drawer.properties[1].value:text())
    assert.are.equal(":tag1:tag2:", file.sections[2].heading.tags:text())
    assert.are.same({ "tag1", "tag2" }, file.sections[2].heading:tag_list())

    ------------------------
    -- FILETAGS DIRECTIVE --
    ------------------------

    assert.are.same({ "a", "b", "c" }, file.filetags)

    -------------------
    -- REGULAR LINKS --
    -------------------

    -- Check our links
    assert.are.equal(5, #file.links)

    -- Check information about the first link
    assert.are.equal("regular", file.links[1].kind)
    assert.are.equal("id:1234", file.links[1].path)
    assert.are.equal("Link to file node", file.links[1].description)
    assert.are.equal(22, file.links[1].range.start.row)
    assert.are.equal(2, file.links[1].range.start.column)
    assert.are.equal(291, file.links[1].range.start.offset)
    assert.are.equal(22, file.links[1].range.end_.row)
    assert.are.equal(31, file.links[1].range.end_.column)
    assert.are.equal(320, file.links[1].range.end_.offset)

    -- Check information about the second link
    assert.are.equal("regular", file.links[2].kind)
    assert.are.equal("id:5678", file.links[2].path)
    assert.are.equal("Link to heading node", file.links[2].description)
    assert.are.equal(23, file.links[2].range.start.row)
    assert.are.equal(2, file.links[2].range.start.column)
    assert.are.equal(333, file.links[2].range.start.offset)
    assert.are.equal(23, file.links[2].range.end_.row)
    assert.are.equal(34, file.links[2].range.end_.column)
    assert.are.equal(365, file.links[2].range.end_.offset)

    -- Check information about the third link
    assert.are.equal("regular", file.links[3].kind)
    assert.are.equal("https://example.com", file.links[3].path)
    assert.is_nil(file.links[3].description)
    assert.are.equal(24, file.links[3].range.start.row)
    assert.are.equal(2, file.links[3].range.start.column)
    assert.are.equal(378, file.links[3].range.start.offset)
    assert.are.equal(24, file.links[3].range.end_.row)
    assert.are.equal(24, file.links[3].range.end_.column)
    assert.are.equal(400, file.links[3].range.end_.offset)

    -- Check information about the fourth link
    assert.are.equal("regular", file.links[4].kind)
    assert.are.equal("link", file.links[4].path)
    assert.is_nil(file.links[4].description)
    assert.are.equal(25, file.links[4].range.start.row)
    assert.are.equal(12, file.links[4].range.start.column)
    assert.are.equal(447, file.links[4].range.start.offset)
    assert.are.equal(25, file.links[4].range.end_.row)
    assert.are.equal(19, file.links[4].range.end_.column)
    assert.are.equal(454, file.links[4].range.end_.offset)

    -- Check information about the fifth link
    assert.are.equal("regular", file.links[5].kind)
    assert.are.equal("link2", file.links[5].path)
    assert.is_nil(file.links[5].description)
    assert.are.equal(25, file.links[5].range.start.row)
    assert.are.equal(42, file.links[5].range.start.column)
    assert.are.equal(477, file.links[5].range.start.offset)
    assert.are.equal(25, file.links[5].range.end_.row)
    assert.are.equal(50, file.links[5].range.end_.column)
    assert.are.equal(485, file.links[5].range.end_.offset)
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
    assert.are.equal(1, #file.drawers)
    assert.are.equal(2, #file.sections)
    assert.are.equal(6, #file.links)

    -- Verify section merging (bug workaround) is working as expected
    assert.are.equal("node two", file.sections[1].heading.item:text())
    assert.are.equal(":d:e:f:", file.sections[1].heading.tags:text())
    assert.are.equal("node three", file.sections[2].heading.item:text())
    assert.are.equal(":g:h:i:", file.sections[2].heading.tags:text())

    -- Verify we get all of the links (catch bug about near end of paragraph
    -- with a period immediately after it
    assert.are.equal("id:2", file.links[1].path)
    assert.are.equal("id:3", file.links[2].path)
    assert.are.equal("id:4", file.links[3].path)
    assert.are.equal("id:1", file.links[4].path)
    assert.are.equal("id:3", file.links[5].path)
    assert.are.equal("id:2", file.links[6].path)
  end)

  it("should parse links from a variety of locations", function()
    ---@type string|nil, org-roam.core.parser.File|nil
    local err, file = async.wait(
      Parser.parse_file,
      join_path(ORG_FILES_DIR, "links.org")
    )
    assert(not err, err)
    assert(file)

    assert.are.equal(14, #file.links)

    assert.are.equal("id:1234", file.links[1].path)
    assert.are.equal("id:5678", file.links[2].path)
    assert.are.equal("https://example.com", file.links[3].path)
    assert.are.equal("link", file.links[4].path)
    assert.are.equal("link2", file.links[5].path)
    assert.are.equal("link3", file.links[6].path)
    assert.are.equal("link4", file.links[7].path)
    assert.are.equal("link5", file.links[8].path)
    assert.are.equal("link6", file.links[9].path)
    assert.are.equal("link7", file.links[10].path)
    assert.are.equal("link8", file.links[11].path)
    assert.are.equal("link9", file.links[12].path)
    assert.are.equal("link10", file.links[13].path)
    assert.are.equal("link11", file.links[14].path)
  end)
end)
