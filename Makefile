.PHONY: test format lint

format:
	stylua .

lint:
	luacheck lua/

test:
	nvim --headless -u NONE -c "lua dofile('tests/run.lua')" -c qa

test-pure:
	luajit tests/run.lua
