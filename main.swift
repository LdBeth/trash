/* trash.swift
 * Created by LdBeth

The MIT License

Copyright (c) 2021 LdBeth

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
 */

import Foundation
import ScriptingBridge

let versionNumberStr = "0.9.2"

let argv = CommandLine.arguments
let argc = CommandLine.argc
let myBasename = (argv[0] as NSString).lastPathComponent

let helpString = """
usage: \(myBasename) [-vilesyF] <file> [<file> ...]

  Move files/folders to the trash.

  Options to use with <file>:

  -v  Be verbose (show files as they are trashed, or if
      used with the -l option, show additional information
      about the trash contents)
  -i  Request confirmation before attempting to remove
      each file.
  -F  Ask Finder to move the files to the trash, instead of
      using the system API.

  Stand-alone options (to use without <file>):

  -l  List items currently in the trash (add the -v option
      to see additional information, add the -a option to
      show hidden files)
  -e  Empty the trash (asks for confirmation)
  -s  Securely empty the trash (asks for confirmation)
      (obsolete)
  -y  Skips the confirmation prompt for -e and -s.
      CAUTION: Deletes permanently instantly.

  Options supported by `rm` are silently accepted.

Version \(versionNumberStr)
Copyright (c) 2021 LdBeth
"""

func printUsage() {
    print(helpString)
}

func printDiskUsageOfFinderItems(finderItems: SBElementArray) {
    var totalPhysicalSize: Int64 = 0
    print("\nCalculating total disk usage of files in trash...")
    for item in finderItems {
        var size: Int64
        let url : URL = URL(string:(item as! FinderItem).URL!)!
        let isDir = FileManager.default.fileExists(atPath:url.path)
        if isDir {
            do {
                size = try directorySize(url)
            }
            catch {
                size = 0
            }
        } else {
            size = (item as! FinderItem).physicalSize ?? 0
        }
        totalPhysicalSize += size
    }
    let bcf = ByteCountFormatter()
    let size = bcf.string(fromByteCount: totalPhysicalSize)
    print("Total: \(size) (\(totalPhysicalSize) bytes)")
}

func listTrashContents(showAdditionalInfo: Bool) {
    let finder = getFinderApp()
    let itemsInTrash = finder.trash!.items()

    for item in itemsInTrash {
        print(URL(string:(item as! FinderItem).URL!)!.path)
    }

    if showAdditionalInfo {
        printDiskUsageOfFinderItems(
          finderItems: itemsInTrash)
    }
}

func emptyTrash(securely: Bool, skipPrompt: Bool) throws {
    let finder = getFinderApp()
    let trashItemsCount : Int = finder.trash!.items().count
    if trashItemsCount == 0 {
        print("The trash is already empty!")
        return
    }
    if !skipPrompt {
        let plural = trashItemsCount > 1
        print("There",
              plural ? "are" : "is",
              "currently",
              trashItemsCount,
              "item\(plural ? "s" : "")",
              securely ? " (and securely)" : "",
              "in the trash.")
        print("Are you sure you want to permanently delete",
              plural ? "these" : "this",
              "item\(plural ? "s" : "")?")
        print("(y = permanently empty the trash, l = list items in trash, n = don't empty)")

        loop: while true {
            switch promptForChar("ylN") {
            case "l":
                listTrashContents(
                  showAdditionalInfo: false
                )
            case "n":
                return
            default: // yes
                break loop
            }
        }
    }
    if securely {
        print("(secure empty trash will take a long while so please be patient...)");
    }
    let warnsBeforeEmptyingOriginalValue = finder.trash!.warnsBeforeEmptying
    finder.trash!.warnsBeforeEmptying = false
    finder.trash!.emptySecurity(securely)
    finder.trash!.warnsBeforeEmptying = warnsBeforeEmptyingOriginalValue
    return
}

func GetKeyPress() -> Character {
    var key: Int = 0
    let c: cc_t = 0
    let cct = (c, c, c, c, c, c, c, c, c, c, c, c, c, c, c, c, c, c, c, c) // Set of 20 Special Characters
    var oldt: termios = termios(c_iflag: 0, c_oflag: 0, c_cflag: 0, c_lflag: 0, c_cc: cct, c_ispeed: 0, c_ospeed: 0)

    tcgetattr(STDIN_FILENO, &oldt) // 1473
    var newt = oldt
    newt.c_lflag = 1217  // Reset ICANON and Echo off
    tcsetattr(STDIN_FILENO, TCSANOW, &newt)
    key = Int(getchar())  // works like "getch()"
    tcsetattr(STDIN_FILENO, TCSANOW, &oldt)
    return Character(UnicodeScalar(key)!)
}

func promptForChar(_ acceptableChars: String) -> String {
    let lowercase = acceptableChars.lowercased()
    var out = ""
    acceptableChars.forEach { char in
        out += "/\(char)"
    }
    let prompt = "[\(out.dropFirst())]"
    while true {
        print(prompt, terminator:"")
        let input = GetKeyPress().lowercased()
        print("")
        if lowercase.contains(input) {
            return input
        }
    }
}

func checkForRoot() {
    if getuid() == 0 {
        print("You seem to be running as root. Any files trashed",
              "as root will be moved to root's trash folder instead",
              "of your trash folder. Are you sure you want to continue?",
              separator: "\n", terminator: "\n")
        let char = promptForChar("yN")
        if char != "y" {
            exit(EXIT_FAILURE)
        }
    }
}

if CommandLine.argc == 1 {
    printUsage()
    exit(0)
}

struct Arg {
    var verbose = false
    var interact = false
    var list = false
    var empty = false
    var emptySecurely = false
    var skipPrompt = false
    var useFinderToTrash = false
}

let optstring = "vlaesyF" + "dfirPRW"

func parseArg() -> Arg {
    var res = Arg()
    while case let option = getopt(argc, CommandLine.unsafeArgv, optstring), option != -1 {
        switch UnicodeScalar(CUnsignedChar(option)) {
        case "v":
            res.verbose = true
        case "i":
            res.interact = true
        case "l":
            res.list = true
        case "e":
            res.empty = true
        case "s":
            res.emptySecurely = true
        case "y":
            res.skipPrompt = true
        case "F":
            res.useFinderToTrash = true
        case "d","f","r","P","R","W":
            break
        default:
            printUsage()
            exit(EXIT_FAILURE)
        }
    }
    return res
}

let arg = parseArg()

if arg.list {
    listTrashContents(
      showAdditionalInfo: arg.verbose
    )
    exit(EXIT_SUCCESS)
} else if arg.empty || arg.emptySecurely {
    do {
        try emptyTrash(securely: arg.emptySecurely,
                       skipPrompt: arg.skipPrompt)
        exit(EXIT_SUCCESS)
    } catch {
        print("failed to empty trash", to: &stdErr)
        exit(EXIT_FAILURE)
    }
}

checkForRoot()

var exitValue : Int32 = EXIT_SUCCESS

var pathsForFinder : [URL] = []

let fm = FileManager.default

for i in Int(optind)..<Int(argc) {
    let path = (argv[i] as NSString).expandingTildeInPath
    if !fm.fileExists(atPath: path) {
        print("trash: \(argv[i]): path does not exist", to: &stdErr);
        exitValue = EXIT_FAILURE
        continue
    }

    if arg.interact {
        print("remove \(path)? ", terminator:"")
        let key = GetKeyPress().lowercased()
        print(key)
        if key != "y" { continue }
    }

    let url = URL(fileURLWithPath: path)

    if arg.useFinderToTrash {
        pathsForFinder.append(url)
        continue
    }

    do {
        try fm.trashItem(at: url, resultingItemURL: nil)
    } catch {
        print("trash: \(argv[i]): cannot move to trash.", to: &stdErr)
        exitValue = EXIT_FAILURE
    }
}


if pathsForFinder.count > 0 {
    do {
        try askFinderToMoveFilesToTrash(
          files: pathsForFinder,
          bringFinderToFront: !arg.useFinderToTrash
        )
        // verb printpaths
    } catch FinderError.notAllFilesTrashed {
        print("trash: some files were not moved to trash (authentication cancelled?)", to: &stdErr)
        exitValue = EXIT_FAILURE
    } catch {
        print("trash: error: \(error).", to: &stdErr)
        exitValue = EXIT_FAILURE
    }
}


exit(exitValue)
