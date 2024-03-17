describe("org-roam.core.utils.random", function()
    local random = require("org-roam.core.utils.random")

    describe("uuid_v4", function()
        it("should generate a random uuid", function()
            local uuid = random.uuid_v4()
            local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

            local i, j = string.find(uuid, pattern)

            -- Check start and end of a 36 character uuid string,
            -- which will fail if no match is found as i/j will be nil
            assert.are.equal(1, i)
            assert.are.equal(36, j)
        end)
    end)
end)
