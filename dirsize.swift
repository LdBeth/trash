func directorySize(_ url: URL) throws -> Int64 {
    let contents = try FileManager.default.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
    )

    var size: Int64 = 0

    for url in contents {
        let isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])

        if isDirectoryResourceValue.isDirectory == true {
            size += try directorySize(url)
        } else {
            let fileSizeResourceValue = try url.resourceValues(forKeys: [.fileSizeKey])
            size += Int64(fileSizeResourceValue.fileSize ?? 0)
        }
    }
    return size
}
