# No longer maintained. A much better version can be found [here](https://github.com/pryme-svg/parabolas-manpages)

# man-pages.sh

Render html from man pages. This script is currently used  to generate [Parabolas Manpages](https://man.parabolas.xyz)

## Requirements

- mandoc
- POSIX-compliant shell
- coreutils

## Usage

```
./gen-html.sh (dest dir)
```

## Obtaining man pages

The script will automatically retrieve pages from [The Linux *man-pages* project](https://www.kernel.org/doc/man-pages/) and the Open Group's [POSIX man pages](https://git.kernel.org/pub/scm/docs/man-pages/man-pages-posix.git).

Currently, the `get-arch-pages.sh` script allows you to extract man pages from the Arch Linux core repository into `arch-linux-pages`.
