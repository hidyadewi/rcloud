#!/bin/sh
set +x

PACKAGE_DIRS="internal rcloud.packages"
BREAK=0

while [ "$1" != "" ]; do
    if [ "$1" = "--base" ]; then
        PACKAGE_DIRS="internal"
    elif [ "$1" = "--core" ]; then
        # the default
        PACKAGE_DIRS="internal rcloud.packages"
    elif [ "$1" = "--all" ]; then
        PACKAGE_DIRS="internal rcloud.packages packages"
    elif [ "$1" = "--break" ]; then
        BREAK=1
    fi
    shift
done

if [ ! -e rcloud.support/DESCRIPTION ]; then
    if [ -n "$ROOT" ]; then
	echo "NOTE: changing to '$ROOT' according to ROOT"
	cd "$ROOT"
    fi
fi

if [ ! -e rcloud.support/DESCRIPTION ]; then
    echo '' 2>&1
    echo ' ERROR: cannot find rcloud.support. Please make sure you are' 2>&1
    echo '        running this script from the RCloud root directory!' 2>&1
    echo '' 2>&1
    exit 1
fi

# build JS (if available)
for dir in htdocs/js  htdocs/lib; do
    if [ -d $dir/node_modules ]; then
	echo " - checking JS code in $dir"
	(cd $dir; make --always-make) || exit 1
    else
	echo "   no node.js modules, skipping"
    fi
done

# Create a local copy of mathjax library in htdocs
MATHJAX_INSTALL_DIR=mathjax
if [ ! -e "htdocs/$MATHJAX_INSTALL_DIR" ]; then
    mkdir -p "htdocs/$MATHJAX_INSTALL_DIR"
    echo 'Downloading MathJax'
    curl -L https://codeload.github.com/mathjax/MathJax/legacy.tar.gz/master | tar -xz -C "htdocs/$MATHJAX_INSTALL_DIR" --strip-components=1
fi

export RCS_SILENCE_LOADCHECK=TRUE

# build internal packages (not in git) & rcloud.packages
for dir in $PACKAGE_DIRS; do
    if [ -e $dir ]; then
        for pkg in `ls $dir/*/DESCRIPTION 2>/dev/null | sed -e 's:/DESCRIPTION::'`; do
            echo $pkg
	    if ! scripts/build_package.sh $pkg; then
                echo;echo;echo; echo package $pkg FAILED to build!;echo;echo
                [ $BREAK == 0 ] || exit 1
            fi
        done
    fi
done

scripts/build_package.sh rcloud.client || exit 1
scripts/build_package.sh rcloud.support || exit 1

if [ -e ".git" ]; then
# update branch/revision info
    REV=`( git rev-list --abbrev-commit -n 1 HEAD )`
    BRANCH=`( git status | sed -n 's:.*On branch ::p' | sed 's:/:-:g' )`

    if [ -n "$REV" ]; then
	echo "$BRANCH" > REVISION
	echo "$REV" >> REVISION
    fi
fi
