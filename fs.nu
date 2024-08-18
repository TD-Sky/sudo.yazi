#!/usr/bin/env nu

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
                './'
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
                './'
            } else {
                $p
                | path basename
                | legit_name
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
        let src = if $relative {
            $it.0 | relative-to-cwd
        } else {
            $it.0
        }

        ln -s -v $src $it.1
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

# Find a legit file name for renaming
def legit_name [] -> string {
    let name = $in
    mut new_name = $name
    for i in 1.. {
        if not ($new_name | path exists) {
            return $new_name
        }
        $new_name = $"($name)_($i)"
    }
}

def relative-to-cwd [] -> string {
    let path = $in

    let path_cmps = $path | path split
    let path_len = $path_cmps | length
    let cwd_cmps = pwd | path split

    let i = $path_cmps
        | zip $cwd_cmps
        | position {|it| $it.0 != $it.1 }

    if $i != null {
        '..'
        | repeat ($path_len - $i)
        | path join (
            $path_cmps
                | range $i..
                | path join
        )
    } else {
        let count = ($cwd_cmps | length) - $path_len

        if $count > 0 {
            '..' | repeat $count | path join
        } else if $count == 0 {
            '.'
        } else {
            $path_cmps | range $count.. | path join
        }
    }
}

def position [predicate: closure] -> int {
    let iter = $in

    for e in ($iter | enumerate) {
        if (do $predicate $e.item) {
            return $e.index
        }
    }
}

def repeat [n: int] -> list {
    let elt = $in

    0..<$n
    | reduce --fold [] {|_, list|
        $list | append $elt
    }
}
