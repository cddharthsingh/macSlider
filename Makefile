.PHONY: app run install test clean check-toolchain

# SwiftUI macros (@State, @Observable, ...) only ship with full Xcode, not the Command Line Tools.
check-toolchain:
	@case "$$(xcode-select -p)" in \
	  *CommandLineTools*) echo "error: the Command Line Tools cannot build SwiftUI apps."; \
	    echo "  run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; exit 1;; \
	esac

app: check-toolchain ## Build macSlider.app into ./build
	scripts/build-app.sh

run: app             ## Build and launch
	# Ad-hoc signatures change per build, so the Accessibility grant from the last build is stale.
	-tccutil reset Accessibility dev.macslider.app >/dev/null 2>&1
	open build/macSlider.app

install: app         ## Copy to /Applications
	rm -rf /Applications/macSlider.app
	cp -R build/macSlider.app /Applications/
	open /Applications/macSlider.app

test: check-toolchain ## Run the gesture engine tests
	swift test

clean:
	rm -rf .build build

help:
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/'