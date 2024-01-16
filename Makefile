.PHONY: help test vendor vendor/plenary.nvim clean

help: ## Display help information
	@printf 'usage: make [target] ...\n\ntargets:\n'
	@egrep '^(.+)\:\ .*##\ (.+)' $(MAKEFILE_LIST) | sed 's/:.*##/#/' | column -t -c 2 -s '#'

test: ## Run all tests
	@nvim \
		--headless \
		--noplugin \
		-u spec/minimal_init.lua \
		-c "lua require('plenary.test_harness').test_directory('spec', {minimal_init='spec/minimal_init.lua'})"

clean: ## Cleans out vendor directory
	@rm -rf vendor/*
