PLUGIN_NAME := secret-values
REMOTE      := https://github.com/yourusername/$(PLUGIN_NAME)

.PHONY: install
install:
    helm plugin install $(REMOTE)

.PHONY: link
link:
    helm plugin install .