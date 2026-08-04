#!/usr/bin/env nu

use std/iter

def main [] {}

def 'main cp' [
    --force,
    ...paths: path,
] {
    let _ = $paths
    | zip {
        $paths
        | each {|p|
            if $force {
                $p | path basename
            } else {
                $p
                | path basename
                | legit_name
            }
        }
    }
    | each {|it|
        cp -rfv $it.0 $it.1
    }
}

def 'main mv' [
    --force,
    ...paths: path,
] {
    let _ = $paths
    | zip {
        $paths
        | each {|p|
            if $force {
                $p | path basename
            } else {
                $p | path basename | legit_name
            }
        }
    }
    | each {|it|
        mv -v $it.0 $it.1
    }
}

def 'main ln' [
    --relative,
    ...paths: path,
] {
    let _ = $paths
    | zip {
        $paths
        | each {|p| $p | path basename | legit_name }
    }
    | each {|it|
        if $relative {
            ln -sr -v $it.0 $it.1
        } else {
            ln -s -v $it.0 $it.1
        }
    }
}

def 'main hardlink' [...paths: path] {
    let _ = $paths
    | zip {
        $paths
        | each {|p| $p | path basename | legit_name }
    }
    | each {|it|
        ln -v $it.0 $it.1
    }
}

def 'main rm' [
    --permanent,
    ...paths: path,
] {
    let f = if $permanent {
        {|path| rm -r --permanent $path }
    } else {
        {|path| rm -r --trash $path }
    }

    for path in $paths {
        do $f $path
    }
}


def 'str split-once' []: string -> list {
    let s = $in

    let i = $s
    | split chars
    | iter find-index {|c| $c == '.' }

    if $i >= 0 {
        [
            ($s | str substring ..<$i),
            ($s | str substring ($i + 1)..),
        ]
    } else {
        null
    }
}

# Read a temp file with edited names and rename corresponding paths.
# Called via: sudo -k -- nu fs.nu bulk-rename --root <root> --tmp <tmp> <paths...>
def 'main bulk-rename' [
    --root: string,       # common root directory
    --tmp: string,        # temp file with one new name per line
    ...paths: path,       # original full paths
] {
    let old_names = if $root == "" {
        $paths
    } else {
        let prefix = $"($root)/"
        $paths | each {|p| $p | str replace $prefix '' }
    }

    let new_names = (open $tmp | lines)
    rm --force $tmp

    let count = ($paths | length)
    for i in 0..($count - 1) {
        if $i >= ($new_names | length) {
            break
        }
        let old_rel = $old_names | get $i
        let new_rel = $new_names | get $i
        if ($new_rel != null) and ($new_rel != "") and ($new_rel != $old_rel) {
            let new_path = if $root == "" {
                $new_rel
            } else {
                $"($root)/($new_rel)"
            }
            mv -v ($paths | get $i) $new_path
        }
    }
}

# Find a legit file name for renaming
def legit_name []: string -> string {
    let name = $in

    mut new_name = $name
    for i in 1.. {
        if not ($new_name | path exists) {
            return $new_name
        }

        $new_name = match ($name | str split-once) {
            [$stem, $ext] => $"($stem)_($i).($ext)",
            null => $"($name)_($i)",
        }
    }

    return null
}
