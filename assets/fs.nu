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

# Write old names to result file and open editor on it.
# Called via: nu fs.nu bulk-rename-edit --root <root> --editor-cmd <cmd> --result-file <file> <paths...>
def 'main bulk-rename-edit' [
    --root: string,          # common root directory
    --editor-cmd: string,    # editor command with %s placeholder
    --result-file: string,   # file to write old names into and edit
    ...paths: path,          # original full paths
] {
    let old_names = if $root == "" {
        $paths
    } else {
        let prefix = $"($root)/"
        $paths | each {|p| $p | str replace $prefix '' }
    }

    $old_names | str join (char newline) | save -f $result_file

    let words = ($editor_cmd | str replace '%s' $result_file | split row ' ')
    if ($words | length) > 0 {
        run-external ...$words
    }
}

# Read edited names from result file and sudo-mv old paths to new paths.
# Called via: sudo -k -- nu fs.nu bulk-rename-do --root <root> --result-file <file> <paths...>
def 'main bulk-rename-do' [
    --root: string,        # common root directory
    --result-file: string, # file with edited names (one per line)
    ...paths: path,        # original full paths
] {
    let new_names = (open $result_file | lines)
    rm --force $result_file

    let old_names = if $root == "" {
        $paths
    } else {
        let prefix = $"($root)/"
        $paths | each {|p| $p | str replace $prefix '' }
    }

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
