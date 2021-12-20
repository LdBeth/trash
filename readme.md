# Trash

This is http://hasseg.org/trash by Ali Rantakari rewritten in Swift.

_This project is developed without using Xcode, only Command Line Tools
should be required to build the program. Why? Because Xcode sucks._

## The “put back” feature

By default, `trash` uses the low-level system API to move the specified
files/folders to the trash. If you want `trash` to ask Finder to perform the
trashing (e.g. to ensure that the _"put back"_ feature works), supply the `-F`
argument.

## `~/.Trash` isn't readable

You may need to enable "Full Disk Access" for your terminal from privacy
settings. If the trash directory isn't readable `trash` will fallback to query
the number of trashed items via Finder, while the listing items feature won't
work.

## The MIT License

Copyright (c) LdBeth

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
