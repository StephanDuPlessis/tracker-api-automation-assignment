const fs = require('fs');
const path = require('path');

// __dirname is the folder this script lives in, so it works from any directory.
const srcDir = path.join(__dirname, 'src');

// Start from the base: name, auth setting, helper script. It has no requests yet.
const collection = readJson(path.join(srcDir, 'base.json'));

// A collection-level script can live in a plain .js file (execFile): load its lines into the script.
for (const event of collection.event || []) {
    if (event.script && event.script.execFile) {
        const code = fs.readFileSync(path.join(srcDir, event.script.execFile), 'utf8');
        event.script.exec = code.trimEnd().split(/\r?\n/);
        delete event.script.execFile;
    }
}

// Each numbered folder in src/ (1-auth, 2-post, ...) becomes one Postman folder.
// Inside it, _folder.json holds the folder name and every numbered .json file is one request.
const folderNames = fs.readdirSync(srcDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^\d+-/.test(entry.name))
    .map((entry) => entry.name)
    .sort();

collection.item = folderNames.map((folderName) => {
    const folderDir = path.join(srcDir, folderName);
    const folder = readJson(path.join(folderDir, '_folder.json'));

    const requestFiles = fs.readdirSync(folderDir)
        .filter((file) => /^\d+-.*\.json$/.test(file))
        .sort();

    folder.item = requestFiles.map((file) => {
        const request = readJson(path.join(folderDir, file));
        const body = request.request.body;

        // If the request points to a body file, load its text into the body.
        if (body && body.rawFile) {
            body.raw = fs.readFileSync(path.join(folderDir, body.rawFile), 'utf8').trim();
            delete body.rawFile;
        }
        return request;
    });
    return folder;
});

// Write the merged collection next to this script.
const outputPath = path.join(__dirname, 'positions.postman_collection.json');
fs.writeFileSync(outputPath, JSON.stringify(collection, null, 2) + '\n');

const requestCount = collection.item.reduce((total, folder) => total + folder.item.length, 0);
console.log(`Built ${outputPath}: ${folderNames.length} folder(s), ${requestCount} request(s)`);

// Reads a .json file and returns it as an object.
function readJson(file) {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
}
