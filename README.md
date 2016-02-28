# asciidoctor-preview - Atom Package

Preview AsciiDoc using [Asciidoctor](http://asciidoctor.org/ "Asciidoctor | An open source implementation of AsciiDoc in Ruby")

## Installation

```
$ apm install asciidoctor-preview
```

## Usage

### Install `AsciiDoctor`

Open a terminal and type: (without the leading `$`)
```
$ gem install asciidoctor
```

also install other extensions like [asciidoctor/asciidoctor-diagram](https://github.com/asciidoctor/asciidoctor-diagram "asciidoctor/asciidoctor-diagram") if needs.

### Set Up Command

Default command is

```
asciidoctor --safe-mode unsafe -a lang=ja -b html5 -d book -r asciidoctor-diagram --base-dir {{{baseDirPath}}} -o {{{tempHTMLPath}}} {{{filePath}}}
```

You can change parameters for `asciidoctor` but you need `{{{tempHTMLPath}}}` as output and `{{{filePath}}}` as input, `{{{baseDirPath}}}` as base directory.

Default values
- `--baseDirPath`
    - preview documents dirname.
- `-o`    
    - generated html file in temp dir.
- argument
    - preview documents    


### Set Up Path

This package needs set up commands path. `/usr/local/bin/` is default.

### Run

1. open a AsciiDoc file.
2. Select the `Asciidoctor Preview: Toggle` command from Command Pallette. You can also execute it by hitting `ctrl-alt-o` on OS X.
3. You can see the preview on your right pane.

You can use `Update on save` option from Settings If you want to run update preview each time a file is saved.

## Advanced usage

### How to use another processer

You can change commnad to use `asciidoc` instead of `asciidoctor` like this

```
asciidoc -b html5 -d book -a lang=ja -o {{{tempHTMLPath}}} {{{filePath}}}
```
