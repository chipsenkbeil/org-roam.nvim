describe("org-roam.setup.modifications", function()
    local utils = require("spec.utils")

    before_each(function()
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should override orgmode's open_at_point to use roam's database first", function()
        error("todo")
    end)
end)
