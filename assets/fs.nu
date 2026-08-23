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

# Write old names to a mapping file and print its path.
# The caller starts the interactive editor with inherited terminal streams.
def 'main bulk-rename-prepare' [
    --root: string,     # common root directory
    ...paths: path,     # original full paths
]: nothing -> string {
    let old_names = match $root {
        "" | null => { $paths }
        _ => {
            $paths
            | each {|p|
                $p
                | str replace $root ''
                | str trim --left --char '/'
            }
        }
    }

    let buf = mktemp --tmpdir --suffix '.txt' sudo-yazi-bulk-rename.XXXXXX
    $old_names | str join (char newline) | save -f $buf

    return $buf
}

# Read edited names from mapping file and sudo-mv old paths to new paths.
def 'main bulk-rename-do' [
    --root: string,     # common root directory
    --mapping: string,  # mapping file contains edited names (one per line)
    ...paths: path,     # original full paths
] {
    let new_names = open $mapping | lines
    rm --force $mapping

    let old_names = match $root {
        "" | null => { $paths }
        _ => {
            $paths
            | each {|p|
                $p
                | str replace $root ''
                | str trim --left --char '/'
            }
        }
    }

    let count = $paths | length
    for i in 0..($count - 1) {
        if $i >= ($new_names | length) {
            break
        }

        let old_rel = $old_names | get $i
        let new_rel = $new_names | get $i
        if ($new_rel != null) and ($new_rel != "") and ($new_rel != $old_rel) {
            let new_path = match $root {
                "" | null => { $new_rel }
                _ => { [$root, $new_rel] | path join }
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
