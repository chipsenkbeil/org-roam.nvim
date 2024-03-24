describe("org-roam.core.utils.path", function()
    local utils_path = require("org-roam.core.utils.path")
    local uv = vim.loop

    describe("join_path", function()
        it("should return empty string if no arguments provided", function()
            assert.are.equal("", utils_path.join_path())
        end)

        it("should combine paths using system separator", function()
            local sep = string.lower(vim.trim(uv.os_uname().sysname)) == "windows"
                and "\\" or "/"

            assert.are.equal(
                "path" .. sep .. "to" .. sep .. "file",
                utils_path.join_path("path", "to", "file")
            )
        end)

        it("should replace ongoing path with absolute path provided", function()
            local sep = string.lower(vim.trim(uv.os_uname().sysname)) == "windows"
                and "\\" or "/"

            assert.are.equal(
                sep .. "to" .. sep .. "file",
                utils_path.join_path("path", sep .. "to", "file")
            )
        end)
    end)
end)
