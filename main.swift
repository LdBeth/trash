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

let versionNumberStr = "0.9.2"

let argv = CommandLine.arguments
let argc = CommandLine.argc
let myBasename = (argv[0] as NSString).lastPathComponent

let helpString = """
usage: \(myBasename) [-vlesyF] <file> [<file> ...]

  Move files/folders to the trash.

  Options to use with <file>:

  -v  Be verbose (show files as they are trashed, or if
      used with the -l option, show additional information
      about the trash contents)
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

func pathToTrash() -> URL {
    do {
        let res = try FileManager.default.url(
          for: .trashDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: false
        )
        return res
    } catch {
        print("trash directory not exists!", to: &stdErr)
        exit(EXIT_FAILURE)
    }
}

func listTrashContents(showAdditionalInfo: Bool, showHidden: Bool) {
    let trash = pathToTrash()
    let fm = FileManager.default
    guard fm.isReadableFile(atPath: trash.path) else {
        print("\(trash.path) not readable")
        return
    }
    guard let items = try? fm.contentsOfDirectory(
         at: trash,
         includingPropertiesForKeys: [],
         options: (showHidden ? [] :
                     [.skipsHiddenFiles])
          ) else {
        print("failed to get contents of trash directory", to: &stdErr)
        exit(EXIT_FAILURE)
    }
    for item in items {
        print(item.path)
    }

    if showAdditionalInfo {
        print("\nCalculating total disk usage of files in trash...")
        if let bytes = try? directorySize(trash) {
            let bcf = ByteCountFormatter()
            let size = bcf.string(fromByteCount: bytes)
            print("Total: \(size) (\(bytes) bytes)")
        } else {
            print("disk usage not available.")
        }
    }

}

func emptyTrash(skipPrompt: Bool) throws {
    var error: NSDictionary?
    let queryCount = "tell application \"Finder\" to count (get trash)"
    let trashItemsCount = NSAppleScript(source: queryCount)!.executeAndReturnError(&error).int32Value
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
              "in the trash.")
        print("Are you sure you want to permanently delete",
              plural ? "these" : "this",
              "item\(plural ? "s" : "")?")
        print("(y = permanently empty the trash, l = list items in trash, n = don't empty)")

        loop: while true {
            switch promptForChar("ylN") {
            case "l":
                listTrashContents(
                  showAdditionalInfo: false,
                  showHidden: true
                )
            case "n":
                return
            default: // yes
                break loop
            }
        }
    }
    let tellFinderempty = "tell application \"Finder\" to empty"
    NSAppleScript(source: tellFinderempty)!.executeAndReturnError(&error)
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
    var list = false
    var showall = false
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
        case "l":
            res.list = true
        case "a":
            res.showall = true
        case "e":
            res.empty = true
        case "s":
            res.emptySecurely = true
        case "y":
            res.skipPrompt = true
        case "F":
            res.useFinderToTrash = true
        case "d","f","i","r","P","R","W":
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
      showAdditionalInfo: arg.verbose,
      showHidden: arg.showall
    )
    exit(EXIT_SUCCESS)
} else if arg.empty || arg.emptySecurely {
    do {
        try emptyTrash(skipPrompt: arg.skipPrompt)
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
