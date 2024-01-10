describe("utils", function()
    local utils = require("org-roam.utils")

    describe("uuid_v4", function()
        it("should generate a random uuid", function()
            local uuid = utils.uuid_v4()
            local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

            -- print("Checking " .. vim.inspect(uuid))
            local i, j = string.find(uuid, pattern)

            -- Check start and end of a 36 character uuid string,
            -- which will fail if no match is found as i/j will be nil
            assert.equals(1, i)
            assert.equals(36, j)
        end)
    end)
end)

