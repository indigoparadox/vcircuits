
# vim: ft=make noexpandtab

BINDIR := bin
OBJDIR := obj
PACKAGES := --vapidir src/vapi \
	--pkg libmosquitto \
	--pkg gtk+-3.0 \
	--pkg json-glib-1.0 \
	--pkg posix \
	--pkg libcurl \
	--pkg libsecret-1 \
	--pkg libxml-2.0

OBJECTS := \
	src/dashlets/zendesk.vala \
	src/dashlets/restio.vala \
	src/dashlets/mail.vala \
	src/dashlets/notebook.vala \
	src/dashlets/text.vala \
	src/dashsource/imap.vala \
	src/dashsource/mqtt.vala \
	src/dashsource/rest.vala \
	src/dashsource/rss.vala \
	src/dashboard.vala \
	src/dashlet.vala \
	src/dashsource.vala \
	src/password.vala \
	src/main.vala

DEFINES := -D G_LOG_DOMAIN=vcircuits

MD := mkdir -v -p

all: circuits

circuits: $(OBJECTS)
	valac -o $@ $^ $(DEFINES) $(PACKAGES)

.PHONY: clean

clean:
	rm -rf $(OBJDIR); \
	rm -f test_circuits; \
	rm -rf $(BINDIR); \
	rm -f circuits;

