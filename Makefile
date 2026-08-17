# CarLyrics — atajos de desarrollo.
# Todo esto requiere macOS con Xcode. Ver README.md.

SCHEME  := CarLyrics
PROJECT := CarLyrics.xcodeproj
DEST    := 'platform=iOS Simulator,name=iPhone 15,OS=latest'

.PHONY: help bootstrap generate open build test lint clean

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Instala dependencias y prepara Secrets.xcconfig
	@./scripts/bootstrap.sh

generate: ## Regenera CarLyrics.xcodeproj desde project.yml
	@command -v xcodegen >/dev/null || { echo "Falta xcodegen: brew install xcodegen"; exit 1; }
	xcodegen generate

open: generate ## Genera y abre el proyecto en Xcode
	open $(PROJECT)

build: generate ## Compila para el simulador
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DEST) \
		CODE_SIGNING_ALLOWED=NO

test: generate ## Corre los tests unitarios
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DEST) \
		CODE_SIGNING_ALLOWED=NO

lint: ## Corre SwiftLint si está instalado
	@command -v swiftlint >/dev/null && swiftlint || echo "SwiftLint no instalado, se omite"

clean: ## Borra artefactos de build
	rm -rf build DerivedData $(PROJECT)
