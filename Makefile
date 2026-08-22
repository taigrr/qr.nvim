.PHONY: test format lint

format:
	stylua .

lint:
	luacheck lua/ plugin/ tests/run.lua

test:
	nvim --headless -u NONE -c "lua dofile('tests/run.lua')" -c qa

test-pure:
	@if command -v luajit >/dev/null 2>&1; then \
		luajit tests/run.lua; \
	elif command -v lua >/dev/null 2>&1; then \
		lua tests/run.lua; \
	else \
		echo "Neither luajit nor lua found"; \
		exit 1; \
	fi
