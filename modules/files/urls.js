.pragma library

function fileUrl(path) {
    try {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    } catch (e) {
        return "";
    }
}

function uriList(paths) {
    var urls = paths.map(fileUrl).filter(function (url) {
        return url !== "";
    });
    return urls.length === 0 ? "" : urls.join("\r\n") + "\r\n";
}
