.POSIX:

DEST_PATH = "dst"
DOMAIN = "parabolas.xyz"
SITE_ROOT = "/var/www/man"

all :html

html:
	./gen-html.sh $(DEST_PATH)

update:
	rsync -auvrlP --delete-after $(DEST_PATH)/ root@$(DOMAIN):$(SITE_ROOT)

clean:
	rm -rf $(DEST_PATH)
