#!/bin/sh

to_delete="man-pages" # use original from kernel.org not arch


usage() {
    echo "Usage: ./get-arch-pages.sh (destination folder)"
	echo "use arch-linux-pages"
    exit 1
}

test -d "$1" || usage

mirror="https://mirror.osbeck.com/archlinux"

wget -e robots=off -m -np -c "$mirror/core/os/x86_64/"
cd "$mirror/core/os/x86_64/"
rm *.sig # TODO: exclude sig files in find
for i in to_delete; do
	rm "$i*.pkg.tar.zst"
done

for i in $(find . -name "*\.pkg\.tar.*"); do
    propername=$(echo "$i" | sed 's/.pkg.tar.*//g')
    
    if ! tar -tf "$i" "usr/share/man" >/dev/null 2>&1; then
        rm "$i" # comment if you want to keep packages without man pages
        echo "$i has no man pages"
        continue
    fi

    mkdir "$propername"
    tar -I zstd -xf "$i" -C "$propername"
    gzipped_pages=$(find "$propername/usr/share/man" -type f)
    
    for page in $gzipped_pages; do
        gzip -df "$page"
        cp $(echo "$page" | sed 's/\.gz//g') $1/
    done
    rm -rf "$propername"
done
