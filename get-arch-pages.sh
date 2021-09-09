#!/bin/sh

to_delete="man-pages" # duplicate


usage() {
    echo "Usage: ./get-arch-pages.sh (destination folder)"
	echo "use arch-linux-pages"
    exit 1
}

test -d "$1" || usage

wget -e robots=off -m -np -c "https://mirror.osbeck.com/archlinux/core/os/x86_64/"

basedir="mirror.osbeck.com/archlinux/core/os/x86_64"
tmpdir="man_extract_dir"

#rm *.sig # TODO: exclude sig files in find

for i in $to_delete; do
	rm $basedir/$i*.pkg.tar.zst
done

for i in $(find "$basedir" -name '*.pkg.tar.*' -type f \( ! -name '*.sig' \) -print); do
    propername=$(basename "$i" | sed 's/.pkg.tar.*//g')
    
    if ! tar -tf "$i" "usr/share/man" >/dev/null 2>&1; then
        rm "$i" # comment if you want to keep packages without man pages
        echo "$i has no man pages"
        continue
    fi

    mkdir "$tmpdir/$propername"
    tar -I zstd -xf "$i" -C "$tmpdir/$propername"
    gzipped_pages=$(find "$tmpdir/$propername/usr/share/man" -type f)
    
    for page in $gzipped_pages; do
        gzip -df "$page"
        cp "$(echo "$page" | sed 's/\.gz//g')" "$1/"
    done
    rm -rf "$tmpdir/$propername"
done

rm -rf "$tmpdir"
