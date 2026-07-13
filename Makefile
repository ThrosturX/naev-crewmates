.PHONY: check syntax manifest test

LUA_FILES := $(shell find ai events scripts -type f -name '*.lua' -print)

check: syntax manifest test

syntax:
	@for file in $(LUA_FILES); do luac -p "$$file" || exit 1; done
	@sh -n tests/install-qa-pilot.sh tests/installer.sh tests/fixture_save.sh

manifest:
	@xmllint --noout plugin.xml tests/fixtures/qa-save-transform.xsl
	@tests/fixture_save.sh

test:
	@tests/installer.sh
	@lua tests/modules.lua
	@lua tests/pilotname.lua
	@lua tests/shuttle_lifecycle.lua
	@lua tests/qa_fixture.lua
	@lua tests/runtime_contract.lua
	@lua tests/static_contracts.lua
	@if command -v luajit >/dev/null 2>&1; then luajit tests/modules.lua; fi
	@if command -v luajit >/dev/null 2>&1; then luajit tests/pilotname.lua; fi
	@if command -v luajit >/dev/null 2>&1; then luajit tests/shuttle_lifecycle.lua; fi
	@if command -v luajit >/dev/null 2>&1; then luajit tests/qa_fixture.lua; fi
	@if command -v luajit >/dev/null 2>&1; then luajit tests/runtime_contract.lua; fi
