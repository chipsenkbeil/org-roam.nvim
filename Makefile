.PHONY: help test vendor vendor/plenary.nvim clean

help: ## Display help information
	@printf 'usage: make [target] ...\n\ntargets:\n'
	@egrep '^(.+)\:\ .*##\ (.+)' $(MAKEFILE_LIST) | sed 's/:.*##/#/' | column -t -c 2 -s '#'

test: vendor ## Run all tests
	@nvim \
		--headless \
		--noplugin \
		-u spec/init.lua \
		-c "lua require('plenary.test_harness').test_directory('spec', {minimal_init='spec/init.lua'})"

# Pulls in all of our dependencies for tests
vendor: vendor/plenary.nvim

# Pulls in the latest version of plenary.nvim, which we use to run our tests
vendor/plenary.nvim:
	@git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git vendor/plenary.nvim || \
		( cd vendor/plenary.nvim && git pull --rebase; )

clean: ## Cleans out vendor directory
	@rm -rf vendor/*
