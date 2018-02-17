.PHONY: test

bower=bower_components
haxe=haxe-hk
scuts_implicit=-cp $(bower)/scuts-implicit/src -D scuts_implicit
scuts_expect_simple=-cp $(bower)/scuts-expect-simple/src -D scuts_expect_simple
scuts_prelude=-cp $(bower)/scuts-prelude/src -D scuts_prelude

libs=$(scuts_implicit) $(scuts_expect_simple) $(scuts_prelude)

silent=

test:
	$(silent)$(haxe) \
	$(libs) \
	-cp src \
	-cp test \
	--run Test

test-js:
	$(silent)$(haxe) \
	$(libs) \
	-cp src \
	-cp test \
	-main Test \
	-js bin/main.js