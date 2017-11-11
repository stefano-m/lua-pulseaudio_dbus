project = pulseaudio_dbus
vpath %_spec.lua tests
vpath %.lua src/$(project)

.PHONY: all
all: *.lua test docs

*.lua:
	luacheck .

.PHONY: test
test: *.lua
	busted .

.PHONY: coverage
coverage: test
	busted --coverage .

.PHONY: docs
docs: README.md *.lua
	ldoc .

.PHONY: upload
upload: all
	luarocks upload rockspec/$(project)-$(LUA_PULSEAUDIO_DBUS_VERSION).rockspec

.PHONY: clean
clean:
	rm -rf luacov.*.out
