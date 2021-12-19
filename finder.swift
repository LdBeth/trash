import Foundation
import AppKit
import ScriptingBridge

@objc public protocol FinderApplication: NSObjectProtocol {
    @objc optional var trash: FinderTrashObject { get }

}

@objc public protocol FinderItem: NSObjectProtocol {
    @objc optional var physicalSize: Int64 { get }
    @objc optional var URL: String { get }
}

extension SBObject: FinderItem {}

@objc public protocol FinderTrashObject: FinderItem {
    @objc var warnsBeforeEmptying: Bool { get set }
    func items() -> SBElementArray
    func emptySecurity(_: Bool)
}

extension SBApplication: FinderApplication {}

fileprivate var finder : FinderApplication?
func getFinderApp() -> FinderApplication {
    if finder == nil {
        finder = SBApplication.init(
          bundleIdentifier: "com.apple.Finder")
    }
    return finder!
}

fileprivate func getFinderPID() -> pid_t {
    for app in NSWorkspace.shared.runningApplications {
        if app.bundleIdentifier == "com.apple.finder" {
            return app.processIdentifier
        }
    }
    return -1
}

enum FinderError: Error {
    case failedToMkDesc, failedToSend, failedGetReply, notAllFilesTrashed
}

func getAbsolutePath(_ filePath: String) -> String {
    // TODO
    return filePath
}

func askFinderToMoveFilesToTrash(files: [String],
                                 bringFinderToFront: Bool) throws {
    let urlListDescr = NSAppleEventDescriptor(listDescriptor: ())
    var i = 1
    for filePath in files {
        let url = URL(fileURLWithPath: getAbsolutePath(filePath))
        guard let descr = NSAppleEventDescriptor(
                descriptorType: typeFileURL,
                data: url.absoluteString.data(using: String.Encoding.utf8)
              ) else {
            throw FinderError.failedToMkDesc
        }
        urlListDescr.insert(descr, at: i)
        i += 1
    }
    var finderPID = getFinderPID()
    let targetDesc = NSAppleEventDescriptor(
      descriptorType: typeKernelProcessID,
      bytes: &finderPID,
      length: MemoryLayout<pid_t>.size
    )
    let descriptor = NSAppleEventDescriptor.appleEvent(
      withEventClass: kCoreEventClass,
      eventID: 1684368495, // 'delo'
      targetDescriptor: targetDesc,
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
    descriptor.setDescriptor(
      urlListDescr,
      forKeyword: 757935405 // '----'
    )
    var replyEvent = AppleEvent()
    let sendErr = AESendMessage(
      descriptor.aeDesc, &replyEvent, AESendMode(kAEWaitReply),
      kAEDefaultTimeout)
    if sendErr != noErr {
        throw FinderError.failedToSend
    }

    var replyAEDesc = AEDesc()
    let getReplyErr = AEGetParamDesc(&replyEvent, keyDirectObject, typeWildCard, &replyAEDesc)
    if getReplyErr != noErr {
        // DEBUG: reply failed
        print("\(getReplyErr),\(replyAEDesc)")
        throw FinderError.failedGetReply
    }
    let replyDesc = NSAppleEventDescriptor(aeDescNoCopy: &replyAEDesc)
    if replyDesc.numberOfItems == 0
         || (1 < files.count && (replyDesc.descriptorType != typeAEList
                                   || replyDesc.numberOfItems != files.count))
    { throw FinderError.notAllFilesTrashed }
}
