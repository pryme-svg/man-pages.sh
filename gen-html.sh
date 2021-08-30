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
        section=$(basename "$f" | cut -f2 -d".")
#        header=$(sed -e "s|\$title|$title ($section)|g" "templates/header.html")
#        footer=$(cat templates/footer.html)

        basedir=$(echo "$f" | cut -d"/" -f1)

        case "$basedir" in
            "man-pages")
                src="The~Linux~man-pages~project"
                ;;
            "man-pages-posix")
                src="POSIX.1~standard"
                ;;
            "arch-linux-pages")
                src="Arch Linux~Core~Repository"
                ;;
        esac
#        sed -i "s|\$source|$src|g" "$1/$(basename "$f").html"


        whole=$(gen_page "$body" "title:$title($section)" "date:$(date -I) source:$src" "man_header.html" "man_footer.html" "man-page.css")
#        whole="$header$body\n$footer"
#        whole=$(sed -e "s|<title></title>|<title>$title</title>|g" -e "s^<article></article>^<article>$body</article>^g" "template.html")
        echo "$whole" > "$1/$(basename "$f").html"

        toc=$(grep -I -E "\<h1[^\>]*\>[^\<\>]*|\<a class=(\"|\')permalink(\"|\') href=(\"|\')#(?P<id>\S+)(\"|\')\>|(?P<title>.+?)|\<\/a\>[^\<\>]*|\<\/h1\>" "$1/$(basename "$f").html" | grep -Eo 'href="[^\"]+"' | grep -Eo '(#)[^/"]+')

        if [ "$(echo "$toc" | grep "\S" | wc -l)" -lt 1 ]; then
            sed -i "s|\$toc||g" "$1/$(basename "$f").html"
        else

            echo "$toc" > "$TMPDIR/.tmptoc"
            html_toc=""

            while read -r line;
            do
                html_toc="$html_toc<li><a href=\"$line\">$(echo "$line" | cut -f2 -d"#")</a></li>"
            done < "$TMPDIR/.tmptoc"

            sed -i "s|\$toc|<details>\n<summary>Table of contents<\/summary>\n<nav class=\"toc\">\n<ul class=\"toclist\">\n$html_toc\n<\/ul>\n<\/nav>\n<\/details>|g" "$1/$(basename "$f").html"

#            sed -i "s|\$toc|$html_toc|g" "$1/$(basename "$f").html"
        fi


#        sed -i "s|\$date|$(date -I)|g" "$1/$(basename "$f").html"



    done
}

# common_{header,footer} assumed
# style.css assumed (in template)
# gen_header <content> <header_vars (var:value var2:value2)> <footer_vars> <custom_header_file> <custom_footer_file> <custom_css_file>
gen_page() {

    if [ -z "$4" ]; then
        header="$HEADER"
    else
        header="$HEADER$(cat templates/$4)"
    fi
    if [ -z "$5" ]; then
        footer="$FOOTER"
    else
        footer="$(cat templates/$5)$FOOTER"
    fi


    if [ -n "$2" ]; then
        for var in $2; do
            name=$(echo "$var" | cut -d":" -f1 | tr '~' ' ')
            value=$(echo "$var" | cut -d":" -f2 | tr '~' ' ')
            # need to read from stdin if too long
#            header=$(echo "$header" | sed -f - << EOF
#            s|\$name|$value|g
#EOF
#            )
            header=$(echo "$header" | sed "s|\$$name|$value|g")
        done
    fi
    if [ -n "$3" ]; then
        for var in $3; do
            name=$(echo "$var" | cut -d":" -f1 | tr '~' ' ')
            value=$(echo "$var" | cut -d":" -f2 | tr '~' ' ')
#            footer=$(echo "$footer" | sed -f - << EOF
#            s|\$name|$value|g
#EOF
#            )
            footer=$(echo "$footer" | sed "s|\$$name|$value|g")
        done
    fi
    if [ -n "$6" ]; then
        css=""
        for sheet in $6; do
            css="$css<link rel=\"stylesheet\" href=\"$sheet\">"
        done
        header=$(echo "$header" | sed "s|\$css|$css|g")
    else
        header=$(echo "$header" | sed 's/$css//g')
    fi
    echo "$header\n$1\n$footer"
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
        gen_page "" "title:Man~Pages~section~$i section:$i" "" "listing_header.html" "listing_footer.html" "" > "$TMPDIR/.tmplisting"

        whole=$(sed -f - "$TMPDIR/.tmplisting" << EOF
        s|\$items|$items|g
EOF
)
#        whole=$(echo "$whole" | sed "s|\$title|Man Pages: section $i|g")

        echo "$whole" > "$1/section_$i.html"
    done
}

usage() {
    echo "Usage ./gen-html.sh (build dir) (dest dir)"
    exit 1
}

update_pages() {
    test -d "man-pages" || git clone git://git.kernel.org/pub/scm/docs/man-pages/man-pages.git
    test -d "man-pages-posix" || git clone git://git.kernel.org/pub/scm/docs/man-pages/man-pages-posix.git
    for repo in "man-pages" "man-pages-posix"; do
        (git -C "$repo" pull)
    done
}

main() {
    test -d "$1" || usage

    # header and footer
    h_file="templates/common_header.html"
    f_file="templates/common_footer.html"
    test -f "$f_file" && FOOTER=$(cat "$f_file") && export FOOTER
	test -f "$h_file" && HEADER=$(cat "$h_file") && export HEADER

    export TMPDIR="build_dir"
    [ ! -d "$TMPDIR" ] && mkdir "$TMPDIR"

    update_pages
    make_html $1
    gen_section_listing $1

    # copy auxillary files
    cp css/* "$1"
    cp pages/* "$1"

    # cleanup
    rm -r "$TMPDIR"
}

main "$@"
