
# vim: ft=make noexpandtab

BINDIR := bin
OBJDIR := obj
PACKAGES := --vapidir src --pkg libmosquitto --pkg gtk+-3.0 --pkg json-glib-1.0

OBJECTS := \
	src/main.vala

MD := mkdir -v -p

all: circuits

circuits: $(OBJECTS)
	valac -o $@ $< $(PACKAGES)

.PHONY: clean

clean:
	rm -rf $(OBJDIR); \
	rm -f test_circuits; \
	rm -rf $(BINDIR); \
	rm -f circuits;

