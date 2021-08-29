#!/bin/sh

# Usage ./gen-html.sh (build dir) (dest dir)

buildirs_html () {
    find man?/ -type d \
    |while read d; do
        install -m 755 -d "$1/$d"
    done
}

make_html () {
    echo "Generating HTML using mandoc"
    pages=$(find man-pages/man?/ -type f)
    pages_posix=$(find man-pages-posix/man-pages-posix-2017/man??/ -type f)
    pages_arch=$(find arch-linux-pages/ -type f)
    all_pages="$pages
    $pages_posix
    $pages_arch"
    for f in $all_pages; do
        # replace references to man pages with actual link
        body=$(mandoc -T html -O fragment "$f" | sed -E -e 's|<b>(\w+)<\/b>\(([1-8]p?)\)|<a href="\1.\2.html">\1\(\2\)</a>|g' -e 's|<b>(.*?\.conf)<\/b>\(([1-8]p?)\)|<a href="\1.\2.html">\1\(\2\)</a>|g')
        title=$(basename "$f" | cut -f1 -d".")
        category=$(basename "$f" | cut -f2 -d".")
        header=$(sed -e "s|\$title|$title ($category)|g" "templates/header.html")
        footer=$(cat templates/footer.html)
        whole="$header$body\n$footer"
#        whole=$(sed -e "s|<title></title>|<title>$title</title>|g" -e "s^<article></article>^<article>$body</article>^g" "template.html")
        echo "$whole" > "$1/$(basename "$f").html"

        toc=$(grep -I -E "\<h1[^\>]*\>[^\<\>]*|\<a class=(\"|\')permalink(\"|\') href=(\"|\')#(?P<id>\S+)(\"|\')\>|(?P<title>.+?)|\<\/a\>[^\<\>]*|\<\/h1\>" "$1/$(basename "$f").html" | grep -Eo 'href="[^\"]+"' | grep -Eo '(#)[^/"]+')
        echo "$toc" > "$1/.tmptoc"
        html_toc=""

        while read -r line;
        do
            html_toc="$html_toc<li><a href=\"$line\">$(echo "$line" | cut -f2 -d"#")</a></li>"
        done < "$1/.tmptoc"

        sed -i "s|\$toc|$html_toc|g" "$1/$(basename "$f").html"

        sed -i "s|\$date|$(date -I)|g" "$1/$(basename "$f").html"

        basedir=$(echo "$f" | cut -d"/" -f1)

        case "$basedir" in
            "man-pages")
                src="The Linux man-pages project"
                ;;
            "man-pages-posix")
                src="POSIX.1 standard"
                ;;
            "arch-linux-pages")
                src="Arch Linux Core Repository"
                ;;
        esac
        sed -i "s|\$source|$src|g" "$1/$(basename "$f").html"

    done
}

gen_section_listing () {
    echo "Creating page listings"
    for i in "0p" "1" "1p" "2" "3" "3p" "4" "5" "6" "7" "8"; do
        items=""
        for j in $(find "$1" -name "*$i.html" -type f); do
            name=$(echo "$j" | cut -f1 -d".")
            item="<li><a href=\"$(basename $j)\">$name($i)</a></li>"
            items=$items$item
        done
        #echo "$i" # just for testing
#        whole=$(sed -e "s|\$title|Man Pages: section $i|g" templates/listing.html)
        whole=$(sed -f - templates/listing.html << EOF
        s|\$items|$items|g
EOF
)
        whole=$(echo "$whole" | sed "s|\$title|Man Pages: section $i|g")

        echo "$whole" > "$1/section_$i.html"
    done
}

usage() {
    echo "Usage ./gen-html.sh (build dir) (dest dir)"
    exit 1
}

update_pages() {
    test -d "man-pages" || git clone git://git.kernel.org/pub/scm/docs/man-pages/man-pages.git
    git -C "man-pages" pull 
    test -d "man-pages-posix" || echo "Please download the latest version of man-pages-posix from https://www.kernel.org/pub/linux/docs/man-pages/man-pages-posix/" && exit 1
}

main() {
    test -d "$1" || usage
#    update_pages
    make_html $1
    rm "$1/.tmptoc"
    gen_section_listing $1
    cp style.css "$1"
    cp listing.css "$1"
    cp templates/index.html "$1"
}

main "$@"
