#!/bin/sh

# Usage ./gen-html.sh (dest dir)

buildirs_html () {
    find man?/ -type d \
    |while read d; do
        install -m 755 -d "$1/$d"
    done
}

strip_extension() {
    while read -r name; do
        echo "${name%.*}"
    done
}

Info() {
	tput setaf 6
	tput bold
	printf "==> "
	tput setaf 15
	printf "$*\n"
	tput sgr0
}

make_html () {
    start=$(date +%s.%N)


    Info "Generating HTML using mandoc"
    pages=$(find man-pages/man?/ -type f)
    pages_posix=$(find man-pages-posix/man-pages-posix-2017/man??/ -type f)
    pages_arch=$(find arch-linux-pages/ -type f)
    all_pages="$pages
    $pages_posix
    $pages_arch"
    echo "$all_pages" > $TMPDIR/all_pages
    num_pages="$(echo "$all_pages" | wc -l)" # for visual purposes

    for f in $all_pages; do
        # replace references to man pages with actual link
        body=$(mandoc -T html -O fragment "$f" | sed -E -e 's|<b>(\w+)<\/b>\(([0-8]p?)\)|<a href="\1.\2.html">\1\(\2\)</a>|g' -e 's|<b>(.*?\.conf)<\/b>\(([0-8]p?)\)|<a href="\1.\2.html">\1\(\2\)</a>|g')
        title=$(basename "$f" | strip_extension)
        section=$(basename "$f" | rev | cut -f1 -d"." | rev)

        basedir=$(echo "$f" | cut -d"/" -f1)

        case "$basedir" in
            "man-pages")
                src="The~Linux~man-pages~project"
                ;;
            "man-pages-posix")
                src="POSIX.1~standard"
                ;;
            "arch-linux-pages")
                src="Arch~Linux~Core~Repository"
                ;;
        esac

        whole=$(gen_page "$body" "title:$title($section)" "date:$(date -I) source:$src" "man_header.html" "man_footer.html" "man-page.css")
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

        fi

    done
    end=$(date +%s)

    runtime=$( echo "$end - $start" | bc -l )
    echo "Processed $num_pages man pages in ${runtime}s"
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

gen_listing () {
    Info "Creating individual section listings"
    global_items=""
    sections="0p 1 1p 2 3 3p 4 5 6 7 8"
    echo "" > $TMPDIR/.allsections
    for i in $sections; do
        items=""
        echo "Section $i" >> $TMPDIR/.allsections
        for j in $(find "$1" -name "*$i.html" -type f); do
            name=$(echo "$j" | strip_extension | strip_extension)
            item="<li><a href=\"$(basename $j)\">$(basename $name)($i)</a></li>"
            items=$items$item
            echo "$item" >> $TMPDIR/.allsections
        done
        gen_page "" "title:Man~Pages~section~$i section:$i" "" "listing_header.html" "listing_footer.html" "" > "$TMPDIR/.tmplisting"

        whole=$(sed -f - "$TMPDIR/.tmplisting" << EOF
        s|\$items|$items|g
EOF
)

        echo "$whole" > "$1/section_$i.html"
    done

# all pages by section ---

    Info "Creating listing of all pages by section"

    i=1

    echo "<h1>Linux manual pages: by section</h1>" > $TMPDIR/.htmlsections
    toplinks=""
    for i in $sections; do
        toplinks="$toplinks<a href=\"#man$i\">$i</a> &nbsp"
    done
    echo "<p>Skip to Section: $toplinks</p>" >> $TMPDIR/.htmlsections

    for current_section in $sections; do
        echo "<h2 id=\"man$current_section\">Section $current_section</h2>\n" >> $TMPDIR/.htmlsections
        echo "<ul>" >> $TMPDIR/.htmlsections
        awk "/Section $current_section/{f=1;next} /Section [0-8]p?/{f=0} f" $TMPDIR/.allsections >> $TMPDIR/.htmlsections
        echo "</ul>" >> $TMPDIR/.htmlsections
    done

    gen_page "<main>\n$(cat $TMPDIR/.htmlsections)\n</main>" "title:Linux~manual~pages~by~section" "" "" "" "" > $1/by_section.html

# alphabetic pages

    Info "Creating listing of all pages alphabetically"

    all_pages=""
    starting_letters=""

    while read -r line; do
        starting_letters="$starting_letters\n$(basename $line | cut -c1-1)"
        all_pages="$all_pages\n$(basename $line)"
    done < $TMPDIR/all_pages

    echo "$all_pages" > $TMPDIR/pagenames
    starting_letters=$(echo "$starting_letters" | grep --color=never "\S" | tr [:upper:] [:lower:] | sort -u | uniq -u)
    echo $starting_letters
    page_links=""
    page_html=""
    for letter in $starting_letters; do
        alpha_listing=""
        page_links="$page_links\n<a href=\"#letter_$letter\">$letter</a>&nbsp; "
        pgs=$(grep -i -E "^$letter.*" $TMPDIR/pagenames)
        page_html="$page_html\n<h2 id=\"letter_$letter\">$letter</h2>"
        for page in $pgs; do
            name=$(echo "$page" | strip_extension)
            section=$(echo "$page" | rev | cut -d"." -f1 | rev)
            alpha_listing="$alpha_listing\n<li><a href=\"$page.html\">$name($section)</a></li>"
        done
        page_html="$page_html<ul>$alpha_listing</ul>"
    done
    page_links="Jump to letter: $page_links"
    heading="<h1>Linux manual pages: sorted alphabeticly</h1>"
    alpha_listing=$(gen_page "<main>$heading\n$page_links\n$page_html</main>" "title:alphabetic~list")
    echo "$alpha_listing" > $1/by_alpha.html

}

usage() {
    echo "Usage ./gen-html.sh (build dir) (dest dir)"
    exit 1
}

update_pages() {
    Info "Updating git repositories"
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

    gen_listing $1

    # copy auxillary files
    cp css/* "$1"

    for page in pages/*; do
        echo "Copying $page"
        case "$(basename "$page")" in
            # TODO: don't hardcode titles
            "index.html")
                title="Parabolas~Manpages"
                ;;
            "about.html")
                title="About"
                ;;
        esac
        whole=$(gen_page "$(cat $page)" "title:$title" "" "" "" "")
        echo "$whole" > "$1/$(basename "$page")"
    done

    # cleanup
    rm -r "$TMPDIR"
}

main "$@"
