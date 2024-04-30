describe("org-roam.core.utils.path", function()
    local path = require("org-roam.core.utils.path")
    local uv = vim.loop

    describe("join", function()
        it("should return empty string if no arguments provided", function()
            assert.are.equal("", path.join())
        end)

        it("should combine paths using system separator", function()
            local sep = string.lower(vim.trim(uv.os_uname().sysname)) == "windows"
                and "\\" or "/"

            assert.are.equal(
                "path" .. sep .. "to" .. sep .. "file",
                path.join("path", "to", "file")
            )
        end)

        it("should replace ongoing path with absolute path provided", function()
            local sep = string.lower(vim.trim(uv.os_uname().sysname)) == "windows"
                and "\\" or "/"

            assert.are.equal(
                sep .. "to" .. sep .. "file",
                path.join("path", sep .. "to", "file")
            )
        end)

        it("should support replacing absolute paths with prefixes on Windows", function()
            local sep = path.separator

            -- Force our separator to be Windows
            ---@diagnostic disable-next-line:duplicate-set-field
            path.separator = function() return "\\" end

            local actual = path.join(
                "C:\\\\Users\\senkwich\\orgfiles\\roam\\",
                "C:\\\\Users\\senkwich\\orgfiles\\roam\\20240429235641-test.org"
            )

            -- Restore old separator function
            path.separator = sep

            -- On Mac/Linux, we don't escape \ into /
            if path.separator() == "\\" then
                assert.are.equal(
                    "C:/Users/senkwich/orgfiles/roam/20240429235641-test.org",
                    actual
                )
            else
                assert.are.equal(
                    "C:\\\\Users\\senkwich\\orgfiles\\roam\\20240429235641-test.org",
                    actual
                )
            end
        end)

        it("should convert \\ to / when joining paths on Windows", function()
            local test_path = path.join("C:\\some\\path")
            if path.separator() == "\\" then
                assert.are.equal("C:/some/path", test_path)
            elseif path.separator() == "/" then
                assert.are.equal("C:\\some\\path", test_path)
            end
        end)
    end)
end)
